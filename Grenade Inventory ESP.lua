-- local variables for API functions. any changes to the line below will be lost on re-generation
local client_set_event_callback, entity_get_bounding_box, entity_get_players, entity_get_prop, table_insert, ui_get, ui_new_checkbox, ui_new_color_picker, unpack, entity_get_origin, entity_get_local_player, ui_new_slider, math_floor = client.set_event_callback, entity.get_bounding_box, entity.get_players, entity.get_prop, table.insert, ui.get, ui.new_checkbox, ui.new_color_picker, unpack, entity.get_origin, entity.get_local_player, ui.new_slider, math.floor

local images = require "gamesense/images"
local csgo_weapons = require "gamesense/csgo_weapons"

local enable = ui_new_checkbox("LUA", "A", "Grenade Inventory")
local color = ui_new_color_picker("LUA", "A", "Grenade Inventory color", 255, 255, 255, 255)
local scale = ui_new_slider("LUA", "A", "Grenade Icon Scale", 6, 10, 8, true, "x", 0.1)

local function get_all_nades(idx)
    local array = {}
    for i=0, 64 do
        local weapon = entity_get_prop(idx, "m_hMyWeapons", i)
        if weapon ~= nil then
            local weapon_info = csgo_weapons(weapon)
            if weapon_info ~= nil and weapon_info.type == "grenade" then
                table_insert(array, weapon_info.idx)
            end
        end
    end
    return array
end

client_set_event_callback("paint", function()
    if not ui_get(enable) then
        return
    end


    local r, g, b, a = ui_get(color)
    local enemies = entity_get_players(true)

    for _, enemy in ipairs(enemies) do
        local grenades = get_all_nades(enemy)

        if #grenades > 0 then
            local _, _, x2, y2, alpha_multiplier = entity_get_bounding_box(enemy)

            if y2 ~= nil and alpha_multiplier > 0 then

                local currX = 0

                for _, m_nade in ipairs(grenades) do

                    local weapon_icon = images.get_weapon_icon(m_nade)
                    local icon_width, icon_height = weapon_icon:measure()

                    icon_width = math_floor(icon_width * ui_get(scale)/10)
                    icon_height = math_floor(icon_height * ui_get(scale)/10)

                    local icongap = (24 - icon_width)/2

                    weapon_icon:draw(x2-3+currX+icongap, y2 - icon_height - 3, icon_width+5, icon_height+5, 0, 0, 0, 225)
                    weapon_icon:draw(x2+currX+icongap, y2 - icon_height, icon_width, icon_height, r, g, b, a)

                    currX = currX + 24
                end
            end
        end
    end
end)