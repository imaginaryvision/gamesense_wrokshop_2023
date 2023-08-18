local client_register_esp_flag, client_set_event_callback, entity_get_players, entity_get_prop, plist_get, plist_set, ui_get, ui_new_checkbox, ui_new_multiselect, ui_new_slider, ui_set_callback, ui_set_visible = client.register_esp_flag, client.set_event_callback, entity.get_players, entity.get_prop, plist.get, plist.set, ui.get, ui.new_checkbox, ui.new_multiselect, ui.new_slider, ui.set_callback, ui.set_visible

local bit = require("bit")

local checkbox = ui_new_checkbox("RAGE", "Other", "Force safe point conditions")
local multiselect = ui_new_multiselect("RAGE", "Other", "\nbox", "Duck", "X > HP", "In air")
local slider = ui_new_slider("RAGE", "Other", "X > HP", 1, 100, 70, true, "HP", 1)

local function table_contains(tbl, val)
	for i = 1, #tbl do
		if tbl[i] == val then
			return true
		end
	end
	return false
end

local function on_multiselect_change(self)
	local tbl = ui_get(self)
	local XHP = table_contains(tbl, "X > HP")

	ui_set_visible(slider, XHP)
end

local function on_checkbox_change(self)
	local v = ui_get(self)
	ui_set_visible(multiselect, v)
	ui_set_visible(slider, v)

	on_multiselect_change(multiselect)
end

client_set_event_callback("paint", function()
	local checkbox = ui_get(checkbox)

	if not checkbox then
		return
	end

	local conditions = ui_get(multiselect)

	if #conditions == 0 then
		return
	end
		
	local duck = table_contains(conditions, "Duck")
	local xhp = table_contains(conditions, "X > HP")
	local air = table_contains(conditions, "In air")

	local plists = entity_get_players(true)
	for i = 1, #plists do
		local enemy = plists[i]
		local flDuckAmount = entity_get_prop(enemy, "m_flDuckAmount") >= 0.7
		local iHealth = entity_get_prop(enemy, "m_iHealth") <= ui_get(slider)
		local fFlags = (bit.band(entity_get_prop(enemy, "m_fFlags"), 1) == 0)

		if (duck and flDuckAmount) or (xhp and iHealth) or (air and fFlags) then
			plist_set(enemy, "Override safe point", "On")
		else
			plist_set(enemy, "Override safe point", "-")
		end
	end
end)

client_register_esp_flag("SP", 204, 204, 0, function(i)
	return (ui_get(checkbox) and plist_get(i, "Override safe point") == "On")
end)

on_checkbox_change(checkbox)
ui_set_callback(checkbox, on_checkbox_change)

on_multiselect_change(multiselect)
ui_set_callback(multiselect, on_multiselect_change)