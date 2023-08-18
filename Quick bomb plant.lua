local quick_plant = ui.new_checkbox("MISC", "Miscellaneous", "Auto plant")
local quick_plant_hotkey = ui.new_hotkey("MISC", "Miscellaneous", "Auto plant hotkey", true)
local can_plant_prev

client.set_event_callback("setup_command", function(cmd)
	if not ui.get(quick_plant) then return end

	local local_player = entity.get_local_player()
	if (cmd.in_use == 1 or cmd.in_attack == 1 or ui.get(quick_plant_hotkey)) and entity.get_classname(entity.get_player_weapon(local_player)) == "CC4" then
		local can_plant = entity.get_prop(local_player, "m_bInBombZone") == 1 and bit.band(entity.get_prop(local_player, "m_fFlags"), 1) == 1

		if can_plant == false or can_plant_prev == false then
			cmd.in_use, cmd.in_attack = 0, 0
		elseif can_plant then
			cmd.in_attack = 1
		end

		can_plant_prev = can_plant
	else
		can_plant_prev = nil
	end
end)