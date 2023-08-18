--[[

	1337_xXx_M@573R H4CK3R CLUB_xXx_1337:
	- elitearmageddon for his "100% original idea" and helping find player ping soundpaths
	- engineer for his "constructive feedback" to elitearmageddon and telling me to use quick maths
	- sapphyrus for his image library and finding ping icon paths/recommending me to make my own SVGs
	
]]--

-- Image library for reading/drawing SVGs
local images = require "gamesense/images"

-- Gamesense API functions
local gs = {
	client = {
		cb = client.set_event_callback,
		unsetCb = client.unset_event_callback,
		useridToEnt = client.userid_to_entindex,
		exec = client.exec
	},
	ui = {
		cb = ui.set_callback,
		get = ui.get,
		checkbox = ui.new_checkbox,
		label = ui.new_label,
		colorPicker = ui.new_color_picker,
		slider = ui.new_slider,
		setVisible = ui.set_visible
	},
	entity = {
		isEnemy = entity.is_enemy,
		getName = entity.get_player_name,
	},
	draw = {
		w2s = renderer.world_to_screen,
		text = renderer.text,
		textSize = renderer.measure_text,
		circleOutline = renderer.circle_outline,
		rectangle = renderer.rectangle
	},
	curtime = globals.curtime
}

-- Ping Marker Data & UI elements
local pm = {
	menu = {
		enabled = gs.ui.checkbox("VISUALS", "Other ESP", "Enemy Ping Marker"),
		label0 = gs.ui.label("LUA", "B", "Ping Marker Settings:"),
		showName = gs.ui.checkbox("LUA", "B", "Show Name"),
		playSound = gs.ui.checkbox("LUA", "B", "Ping Sound"),
		pingDelay = gs.ui.slider("LUA", "B", "Ping Duration", 1, 30, 10, true, "s"),
		label1 = gs.ui.label("LUA", "B", "Normal Ping Color"),
		color1 = gs.ui.colorPicker("LUA", "B", "Normal Ping Color", 93, 167, 254, 200),
		label2 = gs.ui.label("LUA", "B", "Urgent Ping Color"),
		color2 = gs.ui.colorPicker("LUA", "B", "Urgent Ping Color", 255, 30, 30, 200),
		spacer = gs.ui.label("LUA", "B", " ")
	},
	sounds = {
		[false] = "player/playerping",
		[true] = "ui/panorama/ping_alert_01"
	},
	images = {
		[false] = {
			images.get_panorama_image("icons/ui/info.svg"),
			images.load("<?xml version=\"1.0\" ?><svg width=\"32px\" height=\"32px\"><circle cx=\"16\" cy=\"16\" r=\"15\" fill=\"#fff\" /></svg>")
		},
		[true] = {
			images.get_panorama_image("icons/ui/alert.svg"),
			images.load("<?xml version=\"1.0\" ?><svg width=\"32px\" height=\"32px\"><polygon points=\"16,3 31,29 1,29\" style=\"fill:#fff\" /></svg>")
		}
	},
	pings = {}
}

-- Helper function: Iterates through menu elements and sets their visible state
local function showMenu(visible)
	-- Iterate through our menu items
	for k,v in pairs(pm.menu) do
		-- Check if this is not the main "enabled" checkbox
		if k ~= "enabled" then
			-- Toggle item's visible state
			gs.ui.setVisible(pm.menu[k], visible)
		end
	end
end

-- Callback: round_start
local function round_start()
	-- Assigns new table pointer to pings
	pm.pings = {}
end

-- Callback: player_ping
local function player_ping(event)
	-- Get entity index from event's userid
	local entity = gs.client.useridToEnt(event.userid)
	
	-- Check if we failed to obtain an entity index
	if entity == 0 then return end
	
	-- Check if the pinger entity is not an enemy
	if not gs.entity.isEnemy(entity) then return end
	
	-- Get player name from entity index
	local name = gs.entity.getName(entity)
	
	-- Get current time
	local now = gs.curtime()
	
	-- Iterate through the ping data
	for i,v in ipairs(pm.pings) do
		-- Check if the ping was fired within the last 2 seconds
		if now - v[6] <= 2 then
			-- Check if the player name matches our current pinger
			if v[5] == name then
				-- Remove spammed ping from ping data
				table.remove(pm.pings, i)
			end
		end
	end
	
	-- Append event data to the pings data table
	table.insert(pm.pings, {event.x, event.y, event.z, event.urgent, name, now})
	
	-- Check if we need to play the ping sound
	if gs.ui.get(pm.menu.playSound) then
		-- Play the ping sound based on urgency
		gs.client.exec("play ", pm.sounds[event.urgent])
	end
end

-- Callback: paint
local function paint()
	-- Get the ping delay and current time
	local delay = gs.ui.get(pm.menu.pingDelay)
	local now = gs.curtime()

	-- Iterate through the ping data
	for i,v in pairs(pm.pings) do
		-- Get ping expiry
		local pingExpiry = v[6] + delay
	
		-- Check if the ping has expired
		if pingExpiry < now then
			-- Remove expired ping from the data table
			table.remove(pm.pings, i)
		else
			-- Attempt to get on-screen coordinates from ping's world data
			local x, y = gs.draw.w2s(v[1], v[2], v[3])
			
			-- Check if we have successfully negotiated on-screen coordinates
			if x ~= nil and y ~= nil then
				-- Get the effect offset based on urgency
				local effect = ((pingExpiry - now) * 32) % 16
				
				-- Get the rgb colors for the effects(ignoring alpha)
				local r, g, b, a = gs.ui.get(pm.menu.color1)
			
				-- Check if the ping is urgent
				if v[4] then
					-- Change color to urgent
					if effect < 8 then r, g, b, a = gs.ui.get(pm.menu.color2) end
				else
					-- Draws the bursting out effect using a thicco mode outline
					gs.draw.circleOutline(x, y, r, g, b, 155-(2*effect), 24-effect, 0, 1.0, 4)
				end
				
				-- Ping outline
				pm.images[v[4]][2]:draw(x - 16, y - 16, 32, 32, 0, 0, 0, 225)
					
				-- Ping foreground
				pm.images[v[4]][1]:draw(x - 15, y - 15, 30, 30, r, g, b, math.min(a, 200))
				
				-- Check if we need to draw the pinger's name
				if gs.ui.get(pm.menu.showName) then
					-- Calculate name dimensions
					local w, h = gs.draw.textSize("cb", v[5])
					
					-- Clamp max width to 360px
					if w > 360 then w = 360 end
					
					-- Draw background rectangle
					gs.draw.rectangle(math.ceil(x - 4 - w / 2), y + 22, w + 7, 18, 0, 0, 0, 100)
					
					-- Draw pinger's name offset down by text height
					gs.draw.text(x, y + 30, 255, 255, 255, 255, "cb", 360, v[5]) 
				end
			end
		end
	end
end

-- Menu callback: Enemy Ping Marker
gs.ui.cb(pm.menu.enabled, function(item)
	-- Get visibility state and its relative callback handler
	local visible = gs.ui.get(item)
	local cbh = visible and "cb" or "unsetCb"
	
	-- Show/hide menu items
	showMenu(visible)
	
	-- Add/remove callbacks
	gs.client[cbh]("round_start", round_start)
	gs.client[cbh]("player_ping", player_ping)
	gs.client[cbh]("paint", paint)
end)

-- Init all menu items as invisible
showMenu(false)