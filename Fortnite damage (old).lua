local surface = require "gamesense/surface"

--menu init
local menu = {
    enabled = ui.new_checkbox("VISUALS", "Effects", "Fortnite damage"),
    body_color = ui.new_color_picker("VISUALS", "Effects", "Fortnite damage body", 255, 255, 255, 255),
    head_label = ui.new_label("VISUALS", "Effects", "Headshot color"),
    head_color = ui.new_color_picker("VISUALS", "Effects", "Fortnite damage headshot", 255, 255, 0, 255),
    mode = ui.new_multiselect("VISUALS", "Effects", "Fortnite damage mode", "Player", "Teammates", "Enemies"),
    timeout = ui.new_slider("VISUALS", "Effects", "Fortnite damage time", 2, 100, 50, true, "s", 0.1)
}


--variables
local rh, gh, bh, ah = ui.get(menu.head_color)
local rb, gb, bb, ab = ui.get(menu.body_color)
local timeout = ui.get(menu.timeout) * 0.1
local text_size = 48 --change this value if you want to change the text size.

--font creation
local head_font = surface.create_font("Burbank Big Cd Bk", text_size, 0x000, 0x010)
local body_font = surface.create_font("Burbank Big Cd Bk", (text_size / 2), 0x000, 0x010)

--damage, location and time table
local hits = {}

--util funcs
local hurt_checks = {
    ["Player"] = function(entidx)
        return entity.get_local_player() == entidx
    end,
    ["Teammates"] = function(entidx)
        return not entity.is_enemy(entidx)
    end,
    ["Enemies"] = function(entidx)
        return entity.is_enemy(entidx)
    end
}

local function table_vis(references, state, ignore)
    for n, v in pairs(references) do
        if v ~= ignore then
            ui.set_visible(v, state)
        end
    end
end

--https://easings.net/#easeInQuart
local function easeInQuart(x)
    return math.min(1, math.max(0, x * x * x * x))
end

--callbacks
local function on_player_hurt(evt)
    local attacker_idx = client.userid_to_entindex(evt.attacker)
    for i, v in ipairs(ui.get(menu.mode)) do
        if hurt_checks[v](attacker_idx) then
            local victim_idx = client.userid_to_entindex(evt.userid)
            local x, y, z = entity.hitbox_position(victim_idx, 0)

            if x ~= nil then
                if hits[victim_idx] then
                    hits[victim_idx] = {
                        hits[victim_idx][1] + evt.dmg_health,
                        globals.realtime(),
                        x,
                        y,
                        z,
                        evt.hitgroup == 1
                    }
                else
                    hits[victim_idx] = {
                        evt.dmg_health,
                        globals.realtime(),
                        x,
                        y,
                        z,
                        evt.hitgroup == 1
                    }
                end
            end

            --return to stop doing unnecessary checks
            return
        end
    end
end

local function draw()
    local drawtime = globals.realtime()
    for k, hit in pairs(hits) do
        if hit then
            local sx, sy = renderer.world_to_screen(hit[3], hit[4], hit[5])
            if sx ~= nil then
                local r, g, b, a, font = rb, gb, bb, ab, body_font

                if hit[6] then
                    r, g, b, a, font = rh, gh, bh, ah, head_font
                end

                local a_mod = a * (1 - easeInQuart((hit[2] - drawtime) / timeout))

                if a_mod <= 0 then
                    hits[k] = nil
                else
                    surface.draw_text(sx+15, sy, r, g, b, a_mod, font, tostring(hit[1]))
                end
            end
        end
    end
end

--ui callbacks
local function enable_handler()
    local state = ui.get(menu.enabled)
    local update_callback = state and client.set_event_callback or client.unset_event_callback
    update_callback("player_hurt", on_player_hurt)
    update_callback("paint", draw)

    table_vis(menu, state, menu.enabled)

    hits = {}
end

ui.set_callback(menu.enabled, enable_handler)
enable_handler()

ui.set_callback(menu.head_color, function()
    rh, gh, bh, ah = ui.get(menu.head_color)
end)

ui.set_callback(menu.body_color, function()
    rb, gb, bb, ab = ui.get(menu.body_color)
end)

ui.set_callback(menu.timeout, function()
    timeout = ui.get(menu.timeout) * 0.1
end)
