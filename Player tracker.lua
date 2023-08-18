local ffi = require 'ffi'
local steamworks = require 'gamesense/steamworks'
local http = require 'gamesense/http'
local clipboard = require 'gamesense/clipboard'
local pretty_json = require 'gamesense/pretty_json'
local ISteamFriends = steamworks.ISteamFriends
local ISteamMatchmakingServers = steamworks.ISteamMatchmakingServers
local js = panorama.open()

local plist = ui.reference("PLAYERS", "Players", "Player list")

local masterSwitch = ui.new_checkbox("LUA", "B", "Player tracker")

local topButtons = {
	autoRefresh = ui.new_checkbox("LUA", "B", "Automatically refresh tracker"),
	markTargets = ui.new_checkbox("LUA", "B", "Mark targets with esp flag"),
	saveRecentlySeen = ui.new_checkbox("LUA", "B", "Save recently played with"),
	manageData = ui.new_checkbox("LUA", "B", "Manage data"),
	dataExport = ui.new_button("LUA", "B", "Export targets", function()end),
	dataImport = ui.new_button("LUA", "B", "Import targets", function()end),
	deleteData = ui.new_button("LUA", "B", "Delete all targets", function()end),
	mainLabel = ui.new_label("LUA", "B", "Player tracker"),
	listBox = ui.new_listbox("LUA", "B", "tracker content", {}),
}

local labelList = {
	ui.new_label("LUA", "B", "Steam info"),
	ui.new_label("LUA", "B", "Status"),
	ui.new_label("LUA", "B", "Game score"),
	ui.new_label("LUA", "B", "Maps in queue"),
	ui.new_label("LUA", "B", "Server"),
}

local joiner = ui.new_button("LUA", "B", "Join server", function() end)
local watchJoiner = ui.new_button("LUA", "B", "Watch game", function() end)
local coper = ui.new_button("LUA", "B", "Copy IP to clipboard", function() end)

local gRequest
local serverListRequest
local serverFullCount = 300
local queryRunning
local lastRefresh = 0
local lastRefreshUnix
local enemyDataCache = {}
local connectedPrev
local stalkList = database.read("stalkinfodataset123!@#") or {}

local function setup_filters(filters)
	local filters_keyvalue_pair = ffi.new("MatchMakingKeyValuePair_t[?]", #filters)
	local filters_keyvalue_ptr = ffi.new("MatchMakingKeyValuePair_t*", filters_keyvalue_pair)
	local filters_keyvalue_ptr_arr = ffi.new("MatchMakingKeyValuePair_t*[1]", filters_keyvalue_ptr)
	local filters_keyvalue_ptr_ptr = ffi.new("MatchMakingKeyValuePair_t**", filters_keyvalue_ptr_arr)

	for i, filter in ipairs(filters) do
		filters_keyvalue_pair[i-1].m_szKey = filter[1]
		filters_keyvalue_pair[i-1].m_szValue = tostring(filter[2])
	end

	return filters_keyvalue_ptr_ptr
end

local function populateEnemyData() -- caches data every round, use userid to access, later used for "recently played with"
	local amount = 0
	for player=1, globals.maxplayers() do
		if entity.get_classname(player) == "CCSPlayer" then
			amount = amount + 1
		end
	end

	table.clear(enemyDataCache)
	local count = 0
	for i = 0, 9999 do -- collect all user ids / entity indexes and populate the table with it
		local entityIndex = client.userid_to_entindex(i)
		if entityIndex > 0 and entityIndex ~= entity.get_local_player() then
			enemyDataCache[i] = {
				name = entity.get_player_name(entityIndex),
				idx = entityIndex,
				steamid = entity.get_steam64(entityIndex)
			}
			count = count + 1
			if count == amount then break end
		end
	end
end

local function split(s, delimiter) -- splits a string based on delimeter, ty stack exchange
	local result = {}
	for match in (s..delimiter):gmatch("(.-)"..delimiter) do
		table.insert(result, match)
	end
	return result
end

local function getTimeDelta(unix) -- gets time delta from unix timestamp in human readable text
	if type(unix) == "string" then return 0 end
	if type(unix) == "number" and unix < 0 then return 0 end
	local finalTime
	local curtime = client.unix_time()
	local minutes = math.floor((curtime-unix)/60) -- the main value everything is calculated off

	local days = math.floor(minutes/1440)
	local hours = days == 0 and math.floor(minutes/60) or math.floor((minutes-(days*1440))/60)
	local remainder = minutes - (hours*60) - (days*1440)

	finalTime = days > 0 and ("%d%s"):format(days, "d ") or ""
	finalTime = hours > 0 and ("%s%d%s"):format(finalTime, hours, "h ") or finalTime .. ""
	finalTime = remainder > 0 and ("%s%d%s"):format(finalTime, remainder, "m") or finalTime .. ""
	finalTime = finalTime:len() == 0 and "just now" or finalTime
	return finalTime
end

local function sortStalkList() -- why is this a function
	table.sort(stalkList,
	function(a, b)
		if a.lastseen == b.lastseen then
			return a.steamid > b.steamid
		else
			return a.lastseen > b.lastseen
		end
	end)
end

local function updateListbox() -- shield ur eyes, im serious
	if not queryRunning then
		local temp = {}
		sortStalkList()
		for i, v in ipairs(stalkList) do
			local s = ("%s● %s%s"):format(
				v.expiry and "\aFFF696FF" or (v.active and "\a76FAE2FF" or ((v.richData and next(v.richData)) and "\a7687FFFF" or "\a758492FF")),
				"\aFFFFFFC8",
				v.note
			)
			table.insert(temp, s)
		end
		ui.update(topButtons.listBox, temp) -- fill the listbox with data
	end
	
	--
	if not ui.get(topButtons.listBox) then return end
	if #stalkList == 0 then return end
	local index = ui.get(topButtons.listBox) + 1

	local data = stalkList[index] or {}
	local richPresence = data.richData or {}
	local hasRichPresence = next(richPresence)

	ui.set(labelList[1], ("Steam: %s | %s"):format(data.nickname, data.steamid))

	if data.active then
		ui.set(labelList[2], ("Status: playing on %s..."):format(data.status[2]:sub(1,20)))
		ui.set(labelList[5], ("Server info: %s | %s | %s | %s"):format(data.status[3], data.status[5], data.status[4], data.status[1]))
		ui.set(labelList[3], ("Match score: %s"):format(richPresence["game:score"] or ""))
	elseif hasRichPresence then
		ui.set(labelList[2], ("Status: %s / %s"):format(richPresence.status, richPresence["game:state"] or "?"))
		if richPresence["game:mapgroupname"] then
			ui.set(labelList[4], ("Selected maps: %s"):format(richPresence["game:mapgroupname"]:gsub("mg_de_", "")))
		end
		ui.set(labelList[3], ("Match score: %s"):format(richPresence["game:score"] or ""))
	else
		if not data.lastseen then
			ui.set(labelList[2], ("Status: last seen never"))
		else
			ui.set(labelList[2], ("Status: last seen %s"):format(data.lastseen <= 0 and "never" or getTimeDelta(stalkList[index].lastseen)))
		end
		ui.set(labelList[5], ("Server info: offline"))
	end

	if lastRefreshUnix and not queryRunning and (client.unix_time() - lastRefreshUnix > 60) then
		ui.set(topButtons.mainLabel, ("Player tracker (last refresh: %s ago)"):format(getTimeDelta(lastRefreshUnix)))
	end
	if data.expiry then -- oh lord
		ui.set_visible(labelList[1], true)
		ui.set_visible(labelList[2], false)
		ui.set_visible(labelList[3], false)
		ui.set_visible(labelList[4], false)
		ui.set_visible(labelList[5], false)
		ui.set_visible(joiner, false)
		ui.set_visible(coper, false)
		ui.set_visible(watchJoiner, false)
	else
		ui.set_visible(labelList[1], true)
		ui.set_visible(labelList[2], true)
		ui.set_visible(labelList[3], hasRichPresence and (richPresence["game:score"] or false) or false) -- ugly code
		ui.set_visible(labelList[4], hasRichPresence and (richPresence["game:state"] == "lobby" and richPresence["game:mapgroupname"]) or false)
		ui.set_visible(labelList[5], data.active)
		ui.set_visible(joiner, data.active)
		ui.set_visible(coper, data.active)
		ui.set_visible(watchJoiner, hasRichPresence and (tonumber(richPresence["watch"]) == 1) or false)
	end
end

local function addTarget(input, note, temporary) -- adds target into the stalk list, feed string, string, bool
	local steamidObject = steamworks.SteamID(input)
	if not steamidObject then
		print("[TRACKER] Invalid steamid: ", tostring(input))
		return
	end
	local steamid64 = steamidObject:render_steam64()

	-- sanity checks here hmmmm
	for i, v in ipairs(stalkList) do
		if v.steamid == steamid64 then
			print("[TRACKER] Target with this steamid already exists!")
			return
		end
	end
	
	http.get("https://steamcommunity.com/profiles/" .. steamid64, {params = {xml = 1}}, function(s, r)
		local nickname = "Refresh list to fetch"

		if r.status == 200 then
			local match = r.body:match("<steamID><%!%[CDATA%[(.+)%]%]></steamID>")
			if match then
				nickname = match
			end
		end

		table.insert(stalkList, {
			steamid = steamid64,
			nickname = temporary and note or nickname,
			lastseen = temporary and -1 or 0,
			status = "Unknown",
			note = note,
			expiry = temporary and client.unix_time() or nil,
		})
		print(("[TRACKER] Adding %s to %slist: %s"):format(note, temporary and "temporary " or "", input))
		updateListbox()
		database.write("stalkinfodataset123!@#", stalkList)
		database.flush()
	end)
end

local function removeTarget(index)
	if not stalkList[index] then
		print("[TRACKER] Attampting to remove non-existent user")
		return
	end
	local log = stalkList[index].steamid

	table.remove(stalkList, index)

	print(("[TRACKER] Removed %s from the list"):format(log))
end

local function getRichData(steamid64) -- rich data
	local data = {}
	local id = steamworks.SteamID(steamid64)

	local max = ISteamFriends.GetFriendRichPresenceKeyCount(id)
	if max == 0 then return {} end
	for i = 0, max do
		local key = ISteamFriends.GetFriendRichPresenceKeyByIndex(id, i)
		local value = ISteamFriends.GetFriendRichPresence(id, key)
		data[key] = value
	end
	return data
end

client.set_event_callback("console_input", function(text) -- for adding players from console 
	local add = text:match("^track (.+)")
	if add then
		local addtbl = split(add, ",")
		if #(string.match(addtbl[1], "[0-9]+") or {}) == 17 then 
			addTarget(addtbl[1], addtbl[2])
			updateListbox()
			return true
		end
	end
end)

local function refreshStalkList() -- main refresh function 
	if #stalkList == 0 then 
		print("[TRACKER] Tracking list is empty")
		return
	end 
	if queryRunning then
		print("[TRACKER] Query is already running")
		return
	end
	queryRunning = true
	ui.set(topButtons.mainLabel, "Player tracker - refreshing")

	local serverCounter = 0

	for i, v in ipairs(stalkList) do -- reset all to not active -- forgot why I did it but im sure without it its gonna break
		v.active = false
	end

	local matchmaking_key_values = setup_filters({
		{"gametagsand", "hvh"}
	})

	local responses = steamworks.ISteamMatchmakingServerListResponse.new(
		{
			ServerResponded = function(pThis, hRequest, iServer)
				if iServer then 
					local serverDetail = ISteamMatchmakingServers.GetServerDetails(hRequest, iServer)
					serverCounter = math.min(serverCounter + 1, serverFullCount or 9999)
					local updateString = ("Player tracker - fetching servers (%d%%)"):format(serverCounter/serverFullCount*100)
					ui.set(topButtons.mainLabel, updateString)

					if serverDetail.m_nPlayers > 0 then 
						local ip = serverDetail.m_NetAdr.m_unIP
						local port = serverDetail.m_NetAdr.m_usConnectionPort
						local svMap = ffi.string(serverDetail.m_szMap)
						
						local whatthefuck = steamworks.ISteamMatchmakingPlayersResponse.new(
							{
								AddPlayerToList = function(pThis, pchName, nScore, flTimePlayed)
									
									local name = ffi.string(pchName)
									for i, v in ipairs(stalkList) do
										if v.expiry then goto skip end
										if name == v.nickname and svMap == v.richData["game:map"] then
											local ip = ("%s:%s"):format(steamworks.ipv4_tostring(serverDetail.m_NetAdr.m_unIP), serverDetail.m_NetAdr.m_usConnectionPort)
											local svName = (("%s"):format(ffi.string(serverDetail.m_szServerName))):sub(1,50)
											
											local svPing = serverDetail.m_nPing .. "ms"
											local svPopulation = ("(%d/%d)"):format(serverDetail.m_nPlayers, serverDetail.m_nMaxPlayers)
											 
											v.lastseen = client.unix_time()
											v.status = {ip, svName, svMap, svPing, svPopulation}
											v.active = true
										end
										::skip::
									end
								end,
								PlayersRefreshComplete = function()
								end,
							}
						)
						local playersInfo = ISteamMatchmakingServers.PlayerDetails(ip, port, whatthefuck)
					end
					gRequest = hRequest -- no idea
				end
			end,
			ServerFailedToRespond = function() end,
			RefreshComplete = function()
				ui.set(topButtons.mainLabel, "Player tracker")
				serverFullCount = serverCounter
				queryRunning = false
				lastRefreshUnix = client.unix_time()
				ISteamMatchmakingServers.ReleaseRequest(serverListRequest)
				if ui.get(masterSwitch) then
					updateListbox()
				end
			end,
		}
	)
	serverListRequest = ISteamMatchmakingServers.RequestInternetServerList(730, matchmaking_key_values, 1, responses)
end

local function updateNames() -- fetch steam names and refresh rich data
	if #stalkList == 0 then 
		print("[TRACKER] Tracking list is empty")
		return
	end 
	ui.set(topButtons.mainLabel, "Player tracker - fetching steam names")
	local pendingRequests = 0

	-- recently played with timer 
	for j = #stalkList, 1, -1 do
		local data = stalkList[j]
		if data.expiry then
			if client.unix_time() - data.expiry > 600 then
				removeTarget(j)
				print("[TRACkER] removing expired temp player: ", data.note, " with timestamp: ", data.expiry)
			end
		end
	end

	for i, v in ipairs(stalkList) do
		if v.expiry then goto skip end
		local id = v.steamid
		ISteamFriends.RequestFriendRichPresence(id)
		ISteamFriends.RequestUserInformation(id, true)
		pendingRequests = pendingRequests + 1

		http.get("https://steamcommunity.com/profiles/" .. id, {params = {xml = 1}}, function(s, r)
			if r.status == 200 then
				local info = ("Player tracker - fetching steam names (%d%%)"):format(100-(pendingRequests/#stalkList*100))
				ui.set(topButtons.mainLabel, info)
				pendingRequests = pendingRequests - 1
				local match = r.body:match("<steamID><%!%[CDATA%[(.+)%]%]></steamID>")
				if match then
					v.nickname = match
				end 
				v.richData = getRichData(id)
				if next(getRichData(id)) then
					v.lastseen = client.unix_time()
				end
				if pendingRequests == 0 then
					refreshStalkList()
				end
			end
		end)
		::skip::
	end
end

client.set_event_callback("paint_ui", function() -- auto refresh every 60 seconds
	if ui.get(topButtons.autoRefresh) then 
		local realtime = globals.realtime()
		if realtime - 60 > lastRefresh then
			updateNames()
			lastRefresh = realtime
		end
	end

	if ui.get(topButtons.saveRecentlySeen) then
		local connected = globals.mapname() ~= nil

		if not connected and connectedPrev then
			client.delay_call(2, function()
				for _, v in pairs(enemyDataCache) do
					if v.steamid > 0 then
						addTarget(steamworks.SteamID(v.steamid), v.name, true)
					end
				end
				table.clear(enemyDataCache)
			end)
		end

		connectedPrev = connected
	end
end)

client.register_esp_flag("PT", 255, 255, 255, function(player) -- player tracker esp flag
	if not ui.get(topButtons.markTargets) then return end
	local steamid = steamworks.SteamID(entity.get_steam64(player))
	for i, v in ipairs(stalkList) do
		if v.steamid == steamid then
			return true
		end
	end
	return false
end)

client.set_event_callback("shutdown", function() -- eh
	database.write("stalkinfodataset123!@#", stalkList)
	database.flush()
	ISteamMatchmakingServers.CancelQuery(gRequest) -- this does not work
	ISteamMatchmakingServers.ReleaseRequest(serverListRequest)
end)

client.set_event_callback("round_prestart", populateEnemyData) -- recently played with 
client.set_event_callback("player_team", function(e)
	if not ui.get(topButtons.saveRecentlySeen) then return end
	if not e.disconnect then
		populateEnemyData()
		return
	end
	local data = enemyDataCache[e.userid] or {}
	if not data.steamid or data.steamid == 0 then return end

	local steamid64 = steamworks.SteamID(data.steamid)

	for i, v in ipairs(stalkList) do
		if v.steamid == steamid64 and v.expiry then -- if target exists AND is a temporary player we update expiry time
			v.expiry = client.unix_time()
			print("[TRACER] target already logged, expiry time updated")
			return
		end
	end

	addTarget(steamid64, data.name, true)
	updateListbox()
end)

----------------------- all the ui shit below god this is so ugly somebody shoot me why does phil always

local function openOverlay() -- thanks nulled
	if not ui.get(topButtons.listBox) then return end 
	local index = ui.get(topButtons.listBox) + 1
	js.SteamOverlayAPI.ShowUserProfilePage(tostring(stalkList[index].steamid))
end

local bottomButtons = { -- tables
	refresher = ui.new_button("LUA", "B", "Refresh list", updateNames),
	opener = ui.new_button("LUA", "B", "Open steam profile", openOverlay),
	editer = ui.new_button("LUA", "B", "Edit player", function() end),
	editerField = ui.new_textbox("LUA", "B", "Edit player"),
	confirmer = ui.new_button("LUA", "B", "(CONFIRM)", function() end),
	canceller = ui.new_button("LUA", "B", "(CANCEL)", function() end),
	remover = ui.new_button("LUA", "B", "Remove player from list", function() end),
	adder = ui.new_button("LUA", "B", "Add player permanently", function() end),
	plistSaver = ui.new_button("PLAYERS", "Adjustments", "Add player to tracking list", function() end),
	-- plistLabel = ui.new_label("PLAYERS", "Adjustments", "Nickname"),
	-- plistTextField = ui.new_textbox("PLAYERS", "Adjustments", "Track list note"),
}

local function uiUpdate()
	if not ui.get(topButtons.listBox) then return end
	local index = ui.get(topButtons.listBox) + 1
	local data = stalkList[index] or {}
	if ui.get(masterSwitch) then
		ui.set_visible(bottomButtons.refresher, not data.expiry)
		ui.set_visible(bottomButtons.opener, not data.expiry)
		ui.set_visible(bottomButtons.editer, not data.expiry)
		ui.set_visible(bottomButtons.adder, data.expiry)
	end
	
	updateListbox()
end
ui.set_callback(topButtons.listBox, uiUpdate)

local function setUiVisibility(val) -- handling visibility after "edit" button click (very ugly shield ur eyesight)
	ui.set_visible(bottomButtons.editer, not val)
	ui.set_visible(bottomButtons.editerField, val)
	ui.set_visible(bottomButtons.confirmer, val)
	ui.set_visible(bottomButtons.canceller, val)
	ui.set_visible(bottomButtons.remover, val)
end

local function setManageDataVisibility()
	local bool = ui.get(topButtons.manageData)
	ui.set_visible(topButtons.dataExport, bool)
	ui.set_visible(topButtons.dataImport, bool)
	ui.set_visible(topButtons.deleteData, bool)
end

ui.set_callback(bottomButtons.plistSaver, function()
	local selectedEntity = ui.get(plist)
	local note = "From player list" -- change to their actual name later
	local amazing = steamworks.SteamID(entity.get_steam64(selectedEntity))
	addTarget(amazing, note)
	updateListbox()
end)

ui.set_callback(bottomButtons.editer, function()
	if not ui.get(topButtons.listBox) then return end
	setUiVisibility(true)
end)

ui.set_callback(coper, function()
	if not ui.get(topButtons.listBox) then return end
	local index = ui.get(topButtons.listBox) + 1
	local ip = tostring(stalkList[index].status[1])
	if ip and ip ~= "" then
		clipboard.set(ip)
		print("[TRACKER] Copied ip into clipboard: ", ip)
	end
end)

ui.set_callback(bottomButtons.confirmer, function()
	local index = ui.get(topButtons.listBox) + 1
	for i, v in ipairs(stalkList) do
		if i == index then
			v.note = #(ui.get(bottomButtons.editerField)) == 0 and "Unknown" or tostring(ui.get(bottomButtons.editerField))
			print("[TRACKER] Successfully changed nickname for " .. v.steamid)
			updateListbox()
			ui.set(bottomButtons.editerField, "")
		end
	end
	setUiVisibility(false)
end)

ui.set_callback(bottomButtons.canceller, function()
	setUiVisibility(false)
	ui.set(bottomButtons.editerField, "")
end)

ui.set_callback(bottomButtons.remover, function()
	if not ui.get(topButtons.listBox) then return end
	local index = ui.get(topButtons.listBox) + 1 
	ui.set(topButtons.listBox, 0)
	removeTarget(index)
	updateListbox()
	setUiVisibility(false)
	ui.set(bottomButtons.editerField, "")
end)

ui.set_callback(bottomButtons.adder, function()
	if not ui.get(topButtons.listBox) then return end
	local index = ui.get(topButtons.listBox) + 1 
	stalkList[index].expiry = nil
	stalkList[index].lastseen = 0
	print(("[TRACKER] successfully added %s as permanent target"):format(stalkList[index].note))
	uiUpdate()
end)

ui.set_callback(joiner, function()
	if not ui.get(topButtons.listBox) then return end 
	local index = ui.get(topButtons.listBox) + 1
	local ip = stalkList[index].status[1]
	local ipcheck = ip:match("(%d+%.%d+%.%d+%.%d+:%d+)")
	js.GameInterfaceAPI.ConsoleCommand("connect " .. ipcheck)
end)

ui.set_callback(watchJoiner, function()
	if not ui.get(topButtons.listBox) then return end 
	local index = ui.get(topButtons.listBox) + 1
	local steamid64 = stalkList[index].steamid
	js.FriendsListAPI.ActionWatchFriendSession(steamid64)
end)

ui.set_callback(topButtons.dataExport, function()
	local toExport = {}
	for i, v in ipairs(stalkList) do
		if not v.expiry then
			table.insert(toExport, {v.steamid, v.note})
		end
	end
	clipboard.set(pretty_json.stringify(toExport))
	print(("[TRACKER] successfully exported %d %s into clipboard"):format(#stalkList, #stalkList == 1 and "player" or "players"))
end)

ui.set_callback(topButtons.dataImport, function()
	local str = clipboard.get()
	if not str then print("Error importing: clipboard is empty") end
	local success, tbl = pcall(json.parse, str)

	if success and str:sub(1, 1) ~= "[" and str:sub(1, 1) ~= "{" then
		success, tbl = false, "Expected object or array"
	end

	if not success then
		local err = string.format("Invalid JSON: %s", tbl)
		print("Failed to import: " .. err)
		return
	end

	for i, v in ipairs(tbl) do
		addTarget(v[1], v[2], false)
	end
	print(("[TRACKER] successfully imported %d %s"):format(#tbl, #tbl == 1 and "player" or "players"))
end)

-- ui visibility
local function menuVis()
	local element = ui.get(masterSwitch)
	
	for i, v in pairs(topButtons) do
		ui.set_visible(v, element)
	end
	for i, v in pairs(labelList) do
		ui.set_visible(v, element)
	end
	for i, v in pairs(bottomButtons) do
		ui.set_visible(v, element)
	end
	ui.set_visible(joiner, element)
	ui.set_visible(coper, element)
	ui.set_visible(watchJoiner, element)

	if element then
		setUiVisibility(false)
		uiUpdate()
		setManageDataVisibility()
	end
	if #stalkList == 0 then -- 3/20/2022, 5:49:06 AM Phil: go fix?
		for i, v in pairs(topButtons) do
			ui.set_visible(v, element)
		end
		for i, v in pairs(labelList) do
			ui.set_visible(v, false)
		end
		for i, v in pairs(bottomButtons) do
			ui.set_visible(v, false)
		end
		ui.set_visible(joiner, false)
		ui.set_visible(coper, false)
		ui.set_visible(watchJoiner, false)
		ui.set_visible(topButtons.listBox, element)
		ui.set_visible(bottomButtons.plistSaver, element)
		if element then
			setManageDataVisibility()
		end
	end
end

ui.set_callback(topButtons.deleteData, function()
	stalkList = {}
	updateListbox()
	menuVis()
	print("[TRACKER] successfully removed all players")
end)

ui.set_callback(masterSwitch, menuVis)
ui.set_callback(topButtons.manageData, setManageDataVisibility)

local function fixUI()
	updateListbox()
	uiUpdate()
	menuVis()
	setManageDataVisibility()
end
fixUI()
client.set_event_callback("post_config_load", fixUI)


-- peace
-- love
-- unity
-- respect
-- stalk