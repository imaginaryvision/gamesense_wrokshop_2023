local vector = require "vector"
local entity = require "gamesense/entity"

local antiaim_funcs = require 'gamesense/antiaim_funcs'
local csgo_weapons = require "gamesense/csgo_weapons"

local enable_checkbox = ui.new_checkbox("RAGE", "Other", "Force baim on lethal")
local settings = ui.new_multiselect("RAGE", "Other", "\n", "Extrapolate local player", "Double tap", "I'm an advanced user")

local visualise_calculations = ui.new_checkbox("RAGE", "Other", "Visualise calculations")
local trace_add_dist = ui.new_slider("RAGE", "Other", "Trace add distance", 5, 50, 20, true, "u")

local plist_players = ui.reference("PLAYERS", "Players", "Player list")
local plist_players_reset = ui.reference("PLAYERS", "Players", "Reset all")
local plist_ignore_player = ui.new_checkbox("PLAYERS", "Adjustments", "Ignore force baim calculations")

local double_tap, double_tap_hotkey = ui.reference("Rage", "Other", "Double tap")

local esp_callback_set = false

local hitbox_indices = {
	2, 3, 4, 5, 7, 8
}

local ignored_players = {}

local last_target = nil

local function contains(table, val)
	for i=1,#table do
		if table[i] == val then
			return true, i
		end
	end
	return false, -1
end

local function extrapolate_pos (player, position, ticks)
	local velocity = vector(player:get_prop("m_vecVelocity"))

	return position + velocity * ticks * globals.tickinterval()
end

--cleaning up old records
local function restore_all_plist (enemies)
	for _, enemy in ipairs(enemies) do
		plist.set(enemy:get_entindex(), "Override prefer body aim", "-")
	end
end

local function get_eye_pos (player)
	local eye_pos =  vector(player:get_prop("m_vecOrigin"))
	eye_pos.z = eye_pos.z + player:get_prop("m_vecViewOffset[2]")

	return eye_pos
end


local function calculate_trace_positions (src, dest)
	local right, _ = src:to(dest):vectors()
	local base_position = src:clone() + right
	base_position.z = src.z

	local trace_add = ui.get(trace_add_dist)

	-- left and right of the local player
	local positions = { base_position, base_position + right * trace_add, base_position - right * trace_add}

	return positions
end

local function get_highest_baim_damage (local_player, enemy, should_extrapolate, draw)
	local local_eye_pos = should_extrapolate and extrapolate_pos(local_player, get_eye_pos(local_player), 5)
		or get_eye_pos(local_player)
	local enemy_eye_pos = get_eye_pos(enemy)

	local positions = calculate_trace_positions(local_eye_pos, enemy_eye_pos)

	local highest_damage = 0

	for _, trace_pos in ipairs(positions) do
		local highest_it_dmg = 0
		for i = 1, #hitbox_indices do
			local enemy_hitbox_pos = vector(enemy:hitbox_position(hitbox_indices[i]))
			local _, damage = local_player:trace_bullet(trace_pos.x, trace_pos.y, trace_pos.z, 
			enemy_hitbox_pos.x, enemy_hitbox_pos.y, enemy_hitbox_pos.z, false)
			
			if damage > highest_damage then
				highest_damage = damage
			end

			-- only for debugging purposes
			if damage > highest_it_dmg then
				highest_it_dmg = damage
			end
		end

		-- only for debugging purposes, if you're interested in seeing the logic behind this script, call the function with the draw argument set to true 
		if draw then
			local t_eye_w2s = vector(renderer.world_to_screen(enemy_eye_pos:unpack()))
			local trace_w2s = vector(renderer.world_to_screen(trace_pos:unpack()))
			local l_eye_w2s = vector(renderer.world_to_screen(local_eye_pos:unpack()))
	
			if t_eye_w2s:length() ~= 0 and trace_w2s:length() ~= 0 and l_eye_w2s:length() ~= 0 then
				renderer.text(trace_w2s.x, trace_w2s.y, 255, 0, 0, 255, "d+", 0, string.format("%s", highest_it_dmg))
				renderer.line(t_eye_w2s.x, t_eye_w2s.y, trace_w2s.x, trace_w2s.y, 255, 255, 255, 255)
				renderer.line(trace_w2s.x, trace_w2s.y, l_eye_w2s.x, l_eye_w2s.y, 255, 255, 255, 255)
			end
		end
	end

	return highest_damage
end

-- so that it only works for a bunch of weapons where it would make sense to apply this feature
local function valid_dt_weapon (weapon)
	return weapon and weapon.cycletime and weapon.cycletime >= 0.2 and weapon.cycletime <= 0.3
end

local function should_enable_force_baim (weapon, threat_health, highest_baim_damage)
	-- if we can hit a lethal shot on the player's body
	if highest_baim_damage >= threat_health then
		return true
	end

	local dt_active = ui.get(double_tap) and ui.get(double_tap_hotkey) and antiaim_funcs.get_tickbase_shifting() > 2

	if dt_active and contains(ui.get(settings), "Double tap") then
		return valid_dt_weapon(weapon) and (highest_baim_damage * 2 >= threat_health)
	end

	return false
end

local function run_main_functionality (draw)
	local threat = entity.new(client.current_threat())

	if threat == nil then
		return
	end

	-- plist ignore :3
	if contains(ignored_players, threat:get_entindex()) then
		return
	end

	local local_player = entity.get_local_player()
	local threat_idx = threat:get_entindex()

	local should_extrapolate = contains(ui.get(settings), "Extrapolate local player")
	local highest_baim_damage = get_highest_baim_damage(local_player, threat, should_extrapolate, draw)

	-- skipping this, as we only need it in setup_command when not drawing the debug stuff
	if draw then
		return
	end

	local threat_health = threat:get_prop("m_iHealth")

	local weapon_ent = local_player:get_player_weapon()
	local weapon_data = csgo_weapons(weapon_ent:get_entindex())

	local should_enable = should_enable_force_baim(weapon_data, threat_health, highest_baim_damage)

	if last_target ~= nil and last_target:get_entindex() ~= threat_idx then
		plist.set(last_target:get_entindex(), "Override prefer body aim", "-")
	end

	last_target = threat

	plist.set(threat_idx, "Override prefer body aim", 
		should_enable and "Force" or "-") 
end


local function on_setup_command (c)
	run_main_functionality(false)
end

local function on_paint ()
	run_main_functionality(true)
end

local function handle_esp_callback (idx)
	return ui.get(enable_checkbox) and plist.get(idx, "Override prefer body aim") == "Force" and not contains(ignored_players, idx)
end


local function handle_advanced_settings_visibility ()
	local should_show = contains(ui.get(settings), "I'm an advanced user") and ui.get(enable_checkbox)
	local debug_handler = (should_show and ui.get(visualise_calculations)) and client.set_event_callback or client.unset_event_callback

	ui.set_visible(visualise_calculations, should_show)
	ui.set_visible(trace_add_dist, should_show)

	debug_handler("paint", on_paint)
end

local function handle_main_visibility ()
	local enabled = ui.get(enable_checkbox)
	local handler_func = enabled and client.set_event_callback or client.unset_event_callback

	handler_func("setup_command", on_setup_command)
	handler_func("round_prestart", function ()
		restore_all_plist(entity.get_players(true))
	end)
	
	if not esp_callback_set then
		client.register_esp_flag("FORCE", 255, 255, 255, handle_esp_callback)
		esp_callback_set = true
	end

	ui.set_visible(settings, enabled)
	handle_advanced_settings_visibility()
end

ui.set_callback(enable_checkbox, handle_main_visibility)
ui.set_callback(settings, handle_advanced_settings_visibility)
ui.set_callback(visualise_calculations, handle_advanced_settings_visibility)

handle_main_visibility()


-- thank you, esoterik, for this incredibly developer-friendly way of adding new elements to the plist!
-- I greatly appreciated the time I spent figuring it out!
-- lua api update 2035 :tm:
ui.set_callback(plist_ignore_player, function(e)
	local enabled = ui.get(e)
	local current_player = ui.get(plist_players)
	local is_currently_ignored, tbl_index = contains(ignored_players, ui.get(plist_players))

	if enabled and not is_currently_ignored then
		table.insert(ignored_players, current_player)
		plist.set(current_player, "Override prefer body aim", "-")
		client.update_player_list()
	elseif not enabled and is_currently_ignored then
		table.remove(ignored_players, tbl_index)
	end
end)

ui.set_callback(plist_players, function(e)
	ui.set(plist_ignore_player, contains(ignored_players, ui.get(e)))
end)

ui.set_callback(plist_players_reset, function()
	ignored_players = {}
	ui.set(plist_ignore_player, false)
end)
