local panoramaApi = panorama.open()

local mapNameToId = {
	["Mirage"] = "mg_de_mirage",
	["Inferno"] = "mg_de_inferno",
	["Overpass"] = "mg_de_overpass",
	["Vertigo"] = "mg_de_vertigo",
	["Nuke"] = "mg_de_nuke",
	["Train"] = "mg_de_train",
	["Dust 2"] = "mg_de_dust2",
	["Anubis"] = "mg_de_anubis",
	["Cache"] = "mg_de_cache",
	["Mutiny"] = "mg_de_mutiny",
	["Swamp"] = "mg_de_swamp",
	["Mirage (Scrimmage)"] = "mg_de_mirage_scrimmagemap",
	["Agency"] = "mg_cs_agency",
	["Office"] = "mg_cs_office",
	["Cbble"] = "mg_de_cbble",
	["Short Nuke"] = "mg_de_shortnuke",
	["Short Dust"] = "mg_de_shortdust",
	["Rialto"] = "mg_gd_rialto",
	["Lake"] = "mg_de_lake",
}

local availableMaps = {
	"Mirage",
	"Inferno",
	"Overpass",
	"Vertigo",
	"Nuke",
	"Train",
	"Dust 2",
	"Anubis",
	"Cache",
	"Mutiny",
	"Swamp",
	"Agency",
	"Office",
	"Cbble",
	"Short Nuke",
	"Short Dust",
	"Rialto",
	"Lake",
}

local blacklistedMaps = ui.new_multiselect("Config", "Presets", "Blacklisted maps", availableMaps)
local autoRespond = ui.new_checkbox("Config", "Presets", "Auto-message when queue is cancelled")
local autoRespondedAt = 0

ui.new_button("Config", "Presets", "Stop matchmaking", function()
	if panoramaApi.LobbyAPI.IsSessionActive() then
		panoramaApi.LobbyAPI.StopMatchmaking()
	end
end)

client.set_event_callback("paint_ui", function()
	if panoramaApi.LobbyAPI.BIsHost() then
		return
	end

	if panoramaApi.LobbyAPI.IsSessionActive() == false then
		return
	end

	if panoramaApi.LobbyAPI.GetMatchmakingStatusString() ~= "#SFUI_QMM_State_find_searching" then
		return
	end

	local sessionSettings = panoramaApi.LobbyAPI.GetSessionSettings()

	if sessionSettings.game.mapgroupname == nil then
		return
	end

	local caughtBlacklistedMaps = {}

	for _, map in pairs(ui.get(blacklistedMaps)) do
		if string.find(sessionSettings.game.mapgroupname, mapNameToId[map]) then
			table.insert(caughtBlacklistedMaps, map)
		end
	end

	if #caughtBlacklistedMaps == 0 then
		return
	end

	panoramaApi.LobbyAPI.StopMatchmaking()

	if ui.get(autoRespond) and client.unix_time() - autoRespondedAt > 2 then
		autoRespondedAt = client.unix_time()

		panoramaApi.PartyListAPI.SessionCommand(
			'Game::Chat',
			string.format(
				'run all xuid %s chat %s',
				panoramaApi.MyPersonaAPI.GetXuid(),
				string.format(
					"[AUTO-MESSAGE] The queue was cancelled automatically due to a blacklisted map being selected."
				):gsub(' ', ' ')
			)
		)

		panoramaApi.PartyListAPI.SessionCommand(
			'Game::Chat',
			string.format(
				'run all xuid %s chat %s',
				panoramaApi.MyPersonaAPI.GetXuid(),
				string.format(
					"[AUTO-MESSAGE] Please remove: %s.",
					table.concat(caughtBlacklistedMaps, ", ")
				):gsub(' ', ' ')
			)
		)
	end
end)