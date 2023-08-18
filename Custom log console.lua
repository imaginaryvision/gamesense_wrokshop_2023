--» init gs libraries
local ffi, js = require("ffi"), panorama.open()

local c = {
    data = {write=database.write, read=database.read},
    render = {
        rectangle = renderer.rectangle,
        gradient = renderer.gradient,
        text = renderer.text,
        measure = renderer.measure_text,
        load_rgba = renderer.load_rgba,
        texture = renderer.texture
    }
}

-- create the pattern for ui
local x, o = "\x14\x14\x14\xFF", "\x00\x00\x00\x00"
local pattern = table.concat{
    x, x, o, x,
    o, x, o, x,
    o, x, x, x,
    o, x, o, x
}
local texture = c["render"].load_rgba(pattern, 4, 4)

--ffi
    local new_intptr = ffi.typeof("int[1]")
    local surface_getcursorpos = vtable_bind("vguimatsurface.dll", "VGUI_Surface031", 100, "unsigned int(__thiscall*)(void*, int*, int*)")
    local get_clipboard_textc = vtable_bind("vgui2.dll", "VGUI_System010", 7, "int(__thiscall*)(void*)")
    local get_clipboard_text = vtable_bind("vgui2.dll", "VGUI_System010", 11, "void(__thiscall*)(void*, int, const char*, int)")
--end

--» local variables
local OverlayAPI = js.SteamOverlayAPI
local w, h = client.screen_size()
local ref = {
    color = ui.reference("misc", "settings", "menu color"),
    layout = ui.reference("misc", "settings", "lock menu layout"),
    dpi = ui.reference("misc", "settings", "dpi scale")
}
local data = {
    logs = c["data"].read("custom_console/logs") or {},
    param = c["data"].read("custom_console/parameters") or {x=w/2-125, y=h/2-50, w=250, h=100}
}
local local_data = {
    gs_color = {r=187, g=220, b=13, a=255},
    mouse = {x=0, y=0, x_=0, y_=0}, drag={},
    open=true, open_send = false,
    fade = 1, dpi = 1, scroll = {x=data.param.x+data.param.w, y=data.param.y, h=data.param.h, drag=false, y_=0, drag_y=0},
    clr = {r=0, g=0, b=0, a=255}, pre = {"game", "sense"},
    hovered = {window=false, message=-1, scroll=false, send=false, corner=false}
}
local_data.gs_color.r, local_data.gs_color.g, local_data.gs_color.b, local_data.gs_color.a = ui.get(ref.color)
local_data.clr = local_data.gs_color
local settings = {
    show = ui.new_checkbox("lua", "b", "• Custom console settings"),
    hotkey = ui.new_hotkey("lua", "b", "console_hotkey", true, 0x2D),
    style = ui.new_combobox("lua", "b", "\n", "Gamesense", "Pasted"),
    open_menu = ui.new_checkbox("lua", "b", "• Open with ui"),
    render_line = ui.new_checkbox("lua", "b", "• Render line"),
    clr_override = ui.new_checkbox("lua", "b", "• Override color"),
    clr = ui.new_color_picker("lua", "b", "clr_ovr", local_data.gs_color.r, local_data.gs_color.g, local_data.gs_color.b, local_data.gs_color.a),
    dont_copy = ui.new_checkbox("lua", "b", "• Ignore prefix"),
    render_rounds = ui.new_multiselect("lua", "b", "• Indicate rounds", "Render", "Print on round start"),
    clear_logs = ui.new_checkbox("lua", "b", "• Clear logs on shutdown"),
    _ = ui.new_label("lua", "b", "• Prefix"),
    prefix = ui.new_textbox("lua", "b", "cnsl_prefix"),
    __ = ui.new_label("lua", "b", "• Prefix (color)"),
    prefix_clr = ui.new_textbox("lua", "b", "cnsl_clr_prefix")
}
if c["data"].read("custom_console/clear") then
    ui.set(settings.clear_logs, c["data"].read("custom_console/clear"))
end

-- clear old data
    if c["data"].read("console/save/enabled") or c["data"].read("console/pos/x") then
        c["data"].write("console/save/enabled", nil); c["data"].write("console/save/always", nil); c["data"].write("console/save/prefix", nil); c["data"].write("console/prefix_c", nil); c["data"].write("console/save/dont_copy", nil); c["data"].write("console/save/clr_c", nil); c["data"].write("console/save/print_rounds", nil)
        c["data"].write("console/save/clr_r", nil); c["data"].write("console/save/clr_g", nil); c["data"].write("console/save/clr_b", nil); c["data"].write("console/save/clr_a", nil)
        c["data"].write("console/width", nil); c["data"].write("console/height", nil)
        c["data"].write("console/prev_logs__", logs)
        c["data"].write("console/pos/x", nil); c["data"].write("console/pos/y", nil)
        print("Cleared old data and applied some to the new database [console]")
    end
    if c["data"].read("custom_console/") then
        c["data"].write("custom_console/pos", nil); c["data"].read("custom_console/size", nil); c["data"].read("custom_console/", nil); c["data"].read("custom_console/data", nil)
    end
--end

--» local functions
local funcs, api = {}, {}

funcs.draw_ui = function(x, y, w, h, a)
    local k = {10, 60, 40, 40, 40, 60, 10}
    for i=0, 6, 1 do
        c["render"].rectangle(x+i, y+i, w-(i*2), h-(i*2), k[i+1], k[i+1], k[i+1], 255*a)
    end
    c["render"].texture(texture, x+6, y+6, w-12, h-12, 255, 255, 255, 255*a, "r")
    if ui.get(settings.render_line) then
        c["render"].gradient(x+7, y+7, w/2, 2, 5, 221, 255, 255*a, 186, 12, 230, 255*a, true)
        c["render"].gradient(x+7+w/2, y+7, w/2-14, 2, 186, 12, 230, 255*a, 219, 226, 60, 255*a, true)
        c["render"].rectangle(x+7, y+8, w-14, 1, 0, 0, 0, 190*a)
    end
end

funcs.draw_container = function(x, y, w, h, a, name, name2)
    local k = {10, 45, 25}
    local text_size = c["render"].measure("db", name)
    if name2 then
        text_size = c["render"].measure("db", name .. name2)
    end
    for i=1, 3 do
        c["render"].rectangle(x+i, y+i, w-(i*2), h-(i*2), k[i], k[i], k[i], 255*a)
    end
    c["render"].rectangle(x+14, y+1, text_size+4, 2, 30, 30, 30, 255*a)
end

funcs.get_clipboard = function()
    local tlen = get_clipboard_textc()
    if tlen > 0 then
        local buff, size = ffi.new("char[?]", tlen), tlen * ffi.sizeof("char[?]", tlen)
        get_clipboard_text(0, buff, size)
        local val = ffi.string(buff, tlen-1)
        return val
    end
    return nil
end

funcs.get_mouse_positon = function()
    local x_ptr, y_ptr = new_intptr(), new_intptr()
	surface_getcursorpos(x_ptr, y_ptr)
	local x, y = tonumber(x_ptr[0]), tonumber(y_ptr[0])

	return x, y
end

funcs.intersect = function(inp, x, y, w, h)
    return inp[1] >= x and inp[1] <= x+w and inp[2] >= y and inp[2] <= y+h
end

funcs.clamp = function(b, c, d)
    local e=b; e=e<c and c or e;e=e>d and d or e
	return e
end

funcs.contains = function(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end

api.print = function(print_type, r, g, b, can_copy, ...)
    local ptype = print_type or "log"
    if type(ptype) ~= "string" or ptype ~= "log" and ptype ~= "message" and ptype ~= "player" then client.error_log("Invalid argument[1] in api.print()") return end
    if type(r) ~= "number" then client.error_log("Invalid argument[2] in api.print()") return end
    if type(g) ~= "number" then client.error_log("Invalid argument[3] in api.print()") return end
    if type(b) ~= "number" then client.error_log("Invalid argument[4] in api.print()") return end
    if type(can_copy) ~= "boolean" then client.error_log("Invalid argument[5] in api.print()") return end
    local arg = {...}
    local game_rules = entity.get_game_rules()
	local get_round = nil
	if game_rules ~= nil then get_round = entity.get_prop(game_rules, "m_totalRoundsPlayed")+1 end
	local is_warmup = entity.get_prop(game_rules, "m_bWarmupPeriod") or 0
	if is_warmup == 1 then get_round = "W" end

    data.logs[#data.logs+1] = {type=ptype, r=r, g=g, b=b, round=get_round or "nil", can_copy=can_copy, text=unpack(arg)}
    c["data"].write("custom_console/logs", data.logs)
    return #data.logs
end

api.clear = function(index)
    if type(index) ~= "string" and type(index) ~= "number" then client.error_log("Invalid argument in api.clear()") return end
    if type(index) == "number" then
        if data.logs[index] then
            data.logs[index] = nil
            return
        end
    elseif type(index) == "string" then
        for v, k in pairs(data.logs) do
            local found = {k.text:find(index)}
            if found[1] then
                data.logs[v] = nil
                return
            end
        end
    end
    client.error_log("Couldn't find specified index (api.clear)")
end

api.edit = function(index, print_type, r, g, b, can_copy, ...)
    local ptype = print_type
    if type(index) ~= "number" then client.error_log("Invalid argument[1] in api.edit()") return end
    if type(ptype) ~= "string" or ptype ~= "log" and ptype ~= "message" and ptype ~= "player" then client.error_log("Invalid argument[2] in api.edit()") return end
    local red, green, blue, ctype, cancopy, text
    local arg = {...}

    for v, k in pairs(data.logs) do
        if index == v then
            ctype = ptype or k.type
            red, green, blue = r or k.r, g or k.g, b or k.b
            cancopy = cancopy or k.can_copy
            text = unpack(arg) or k.text
        end
    end
    if data.logs[index] then
        local log = data.logs[index]
        log.type, log.r, log.g, log.b, log.can_copy, log.text = ctype, red, green, blue, cancopy, text
        return
    end
    client.error_log("Couldn't find specified index (api.edit)")
end

api.return_logs = function()
    local tbl = {}
    for v, k in pairs(data.logs) do
        tbl[#tbl] = k
    end
    return tbl
end

api.get_parameters = function()
    return data.param["x"], data.param["y"], data.param["w"], data.param["h"]
end

api.is_open = function()
    return local_data.open, local_data.fade
end

-- input handling
    local input = { [1]={globals.realtime(), false, false, false}, [2]={globals.realtime(), false, false, false} }
    local function handle_input()
        for v, k in pairs(input) do
            k[3] = client.key_state(v)
            if k[3] then
                if globals.realtime() > k[1] then
                    k[2] = true else k[2] = false
                end
                k[1] = globals.realtime()+0.05
            else
                if globals.realtime() < k[1] then
                    k[4] = true else k[4] = false
                end
            end
        end
    end
    client.set_event_callback("paint_ui", handle_input)
--end

--» callbacks
local render = {}

-- movement, dpi and color handling
    function render:handle()
        local l = local_data
        local gsc, mouse, dpi, drag, scroll, hovered = l.gs_color, l.mouse, l.dpi, l.drag, l.scroll, l.hovered
        local get_dpi = ui.get(ref.dpi); get_dpi = get_dpi:gsub("%%", "%")
        local hold = input[1][3]
        gsc.r, gsc.g, gsc.b, gsc.a = ui.get(ref.color)
        l.clr = gsc
        if ui.get(settings.clr_override) then
            l.clr.r, l.clr.g, l.clr.b, l.clr.a = ui.get(settings.clr)
        end
        l.dpi = tonumber(get_dpi)/100
        local x, y, w, h = data.param.x, data.param.y, data.param.w*dpi, data.param.h*dpi
        mouse.x, mouse.y = funcs.get_mouse_positon()
        hovered.window, hovered.corner, hovered.scroll = funcs.intersect({mouse.x, mouse.y}, x, y, w, h), funcs.intersect({mouse.x, mouse.y}, x+w-10, y+h-10, 10, 10), funcs.intersect({mouse.x, mouse.y}, scroll.x, scroll.y, 6, scroll.h)
        l.open = ui.get(settings.hotkey) or ui.get(settings.open_menu) and ui.is_menu_open()
        l.pre[1] = ui.get(settings.prefix) == "" and "game" or ui.get(settings.prefix)
        l.pre[2] = ui.get(settings.prefix_clr) == "" and "sense" or ui.get(settings.prefix_clr)
        if not hold then mouse.x_, mouse.y_ = mouse.x, mouse.y end

        if l.open then
            if ui.is_menu_open() then
                if drag.bool and not hold then drag.bool = false end

                if drag.bool and hold then
                    data.param.x, data.param.y = mouse.x-drag.x, mouse.y-drag.y
                    c["data"].write("custom_console/parameters", data.param)
                end

                if hovered.window and hovered.message == -1 and hold then
                    drag.bool = true
                    drag.x, drag.y = mouse.x-data.param.x, mouse.y-data.param.y
                end

                if hold then
                    if drag.rbool then
                        data.param.w, data.param.h = math.max(350, mouse.x - drag.rx), math.max(120, mouse.y - drag.ry)
                        drag.bool = false
                        c["data"].write("custom_console/parameters", data.param)
                    end
    
                    if hovered.corner then
                        drag.rbool = true
                        drag.rx, drag.ry = mouse.x-data.param.w, mouse.y-data.param.h
                    end
                else
                    drag.rbool = false
                end
            end

            if scroll.drag and not input[1][3] then scroll.drag = false end

            if scroll.drag and input[1][3] then
                scroll.y_ = math.min(0, math.max(-(c["render"].measure("d", "A"))*#data.logs, mouse.y-scroll.drag_y))
                drag.bool = false; drag.rbool = false
            end

            if hovered.scroll then
                scroll.drag_y = mouse.y-scroll.y_
                scroll.drag = true
            end
        end
    end
--end

function render:text(x, y, tbl, a)
    local l = local_data
    local max = 0
    local full_prefix = "[" .. table.concat(l.pre) .. "] "
    local text_to_copy = ""
    if funcs.contains(ui.get(settings.render_rounds), "Render") and tbl.round ~= "nil" then
        full_prefix = string.format("[%s] [%s] ", tbl.round, table.concat(l.pre))
    end
    tbl.text = tostring(tbl.text)
    local do_ = {
        ["log"] = function()
            local gap = c["render"].measure("d", full_prefix)
            local tlen = c["render"].measure("d", tbl.text)
            local alpha = tbl.alpha or 1
            max = ((tlen+gap+32)-data.param.w)/4
            max = math.max(0, (tbl.text:len()-max))
            c["render"].text(x, y, l.clr.r, l.clr.g, l.clr.b, (255*a)*alpha, "d", 0, full_prefix)
            c["render"].text(x+gap, y, tbl.r, tbl.g, tbl.b, (255*a)*alpha, "d", 0, tbl.text:sub(1, max))
            if ui.get(settings.dont_copy) then
                text_to_copy = tbl.text else text_to_copy = "[" .. table.concat(l.pre) .. "] " .. tbl.text
            end
        end,
        ["message"] = function()
            local tlen = c["render"].measure("d", tbl.text)
            local alpha = tbl.alpha or 1
            max = ((tlen+32)-data.param.w)/4
            max = math.max(0, (tbl.text:len()-max))
            c["render"].text(x, y, tbl.r, tbl.g, tbl.b, (255*a)*alpha, "d", 0, tbl.text:sub(1, max))
            if ui.get(settings.dont_copy) then
                text_to_copy = tbl.text else text_to_copy = "[" .. table.concat(l.pre) .. "] " .. tbl.text
            end
        end,
        ["player"] = function()
            local found, found_ = {tbl.text:find("{")}, {tbl.text:find("}")}
            if found and found_ then
                full_prefix = tbl.text:sub(found[1]+1, found_[1]-1) .. "» "
            else
                found_[1] = -1
                full_prefix = "unknown » "
            end
            local gap = c["render"].measure("d", full_prefix)
            local tlen = c["render"].measure("d", tbl.text)
            local alpha = tbl.alpha or 1
            max = ((tlen+gap+32)-data.param.w)/4
            max = math.max(0, (tbl.text:len()-max))
            c["render"].text(x, y, l.clr.r, l.clr.g, l.clr.b, (255*a)*alpha, "d", 0, full_prefix)
            c["render"].text(x+gap, y, tbl.r, tbl.g, tbl.b, (255*a)*alpha, "d", 0, tbl.text:sub(found_[1]+2, max))
            if ui.get(settings.dont_copy) then
                text_to_copy = tbl.text else text_to_copy = full_prefix .. ": " .. tbl.text
            end
        end
    }
    do_[tbl.type]()
    return text_to_copy
end

function render.window()
    render:handle()
    local l = local_data
    local clr, mouse, dpi, drag, scroll, hovered, fade = l.clr, l.mouse, l.dpi, l.drag, l.scroll, l.hovered, l.fade
    local x, y, w, h = data.param.x, data.param.y, data.param.w*dpi, data.param.h*dpi
    local text_dpi = {c["render"].measure("d", "A")}
    local b = {x=x+24, y=y+10, w=w-43, h=h-30}
    local off = ui.get(settings.render_line) and 4 or 0
    local text_y = b.y+b.h-scroll.y_-15+off
    local speed = globals.frametime() * 10
    if not l.open_send then hovered.message = -1 end
    local get = {
        style = ui.get(settings.style)
    }
    l.scroll.x = b.x+b.w-5

    if #data.logs > 150 then table.remove(data.logs, 1) end
    
    if fade > 0.00 then
        if get.style == "Gamesense" then
            funcs.draw_ui(x, y, w, h+off, fade)
            funcs.draw_container(x+16, y+16+off, w-32, h-32, fade, l.pre[1], l.pre[2])
            for v, k in pairs(data.logs) do
                local toff = (text_dpi[2]+2)*(#data.logs-v)
                local is_hovered = false
                if text_y-toff >= b.y+off+10 and text_y-toff <= b.y+off+b.h-12 then
                    if k.can_copy then
                        is_hovered = funcs.intersect({mouse.x, mouse.y}, b.x, text_y-toff, b.w-8, 12)
                    end
                    local tfade = fade
                    if is_hovered then
                        if input[1][3] or input[2][3] then tfade = 0.5 else tfade = 0.65 end
                        if not l.open_send then hovered.message = v end
                    else
                        if hovered.message == v then tfade = 0.5 end
                    end
                    local copy = render:text(b.x, text_y-toff, k, tfade)
                    if is_hovered then
                        if input[1][4] then
                            OverlayAPI.CopyTextToClipboard(copy)
                        end
                        if input[2][2] then
                            l.open_send = not l.open_send
                        end
                    end
                    data.logs[v].to_copy = copy
                end
            end
            if l.open_send then
                local send = {x=b.x-110, y = text_y-((text_dpi[2]+2)*(#data.logs-hovered.message))}
                hovered.send = funcs.intersect({mouse.x, mouse.y}, send.x, send.y, 80, 40)
                local hover_glob, hover_team = funcs.intersect({mouse.x, mouse.y}, send.x, send.y, 80, 18), funcs.intersect({mouse.x, mouse.y}, send.x, send.y+20, 80, 18)
                if not hovered.send then
                    if input[1][2] then l.open_send = false end
                end
                c["render"].rectangle(send.x-1, send.y-1, 82, 42, 0, 0, 0, 255*fade)
                c["render"].rectangle(send.x, send.y, 80, 40, 25, 25, 25, 255*fade)
                if hover_glob then
                    c["render"].rectangle(send.x, send.y, 80, 20, 15, 15, 15, 255*fade)
                    if input[1][4] then
                        client.exec("say ", data.logs[hovered.message].to_copy or data.logs[hovered.message].text)
                        l.open_send = false
                    end
                end
                c["render"].text(send.x+8, send.y+4, 220, 220, 220, 255*fade, "", 0, "Global chat")
                if hover_team then
                    c["render"].rectangle(send.x, send.y+20, 80, 20, 15, 15, 15, 255*fade)
                    if input[1][4] then
                        client.exec("say_team ", data.logs[hovered.message].to_copy or data.logs[hovered.message].text)
                        l.open_send = false
                    end
                end
                c["render"].text(send.x+8, send.y+24, 220, 220, 220, 255*fade, "", 0, "Team chat")
            end
            c["render"].rectangle(x+20, y+18+off, w-40, 1, 45, 45, 45, 255*fade)
            c["render"].rectangle(x+20, y+19+off, w-40, 7, 25, 25, 25, 255*fade)
            c["render"].gradient(x+20, y+25+off, w-40, 15, 25, 25, 25, 255*fade, 25, 25, 25, 20*fade, false)
            c["render"].gradient(x+20, y+h-34+off, w-40, 15, 25, 25, 25, 20*fade, 25, 25, 25, 255*fade, false)
            c["render"].text(x+32, y+10+off, 220, 220, 220, 255*fade, "db", 0, l.pre[1])
            c["render"].text(x+32+c["render"].measure("db", l.pre[1]), y+10+off, local_data.clr.r, local_data.clr.g, local_data.clr.b, 255*fade, "db", 0, l.pre[2])

            l.scroll.y = math.max(b.y+12, math.min(b.y+b.h-scroll.h, b.y+scroll.y_+1+(2*#data.logs)))
            l.scroll.h = math.max(12, (b.h-2)-(2*#data.logs))
            if scroll.h < b.h-15 then
                c["render"].rectangle(b.x+b.w-6, b.y+8+off, 6, b.h-6, 45, 45, 45, 255*fade)
                c["render"].rectangle(scroll.x, scroll.y+off, 4*dpi, scroll.h, 60, 60, 60, 255*fade)
            end
        elseif get.style == "Pasted" then
            c["render"].rectangle(x, y, w, h, 25, 25, 25, 255*fade)
            c["render"].rectangle(x+12, y+20+off, w-26, h-32, 15, 15, 15, 255*fade)
            b.x = b.x-4
            if ui.get(settings.render_line) then
                c["render"].rectangle(x+1, y+1, w-2, 2, l.clr.r, l.clr.g, l.clr.b, 255*fade)
                c["render"].rectangle(x+1, y+2, w-2, 1, 0, 0, 0, 190*fade)
            end
            for v, k in pairs(data.logs) do
                local toff = (text_dpi[2]+2)*(#data.logs-v)-8
                local is_hovered = false
                if text_y-toff >= b.y+off+10 and text_y-toff <= b.y+off+b.h-6 then
                    if k.can_copy then
                        is_hovered = funcs.intersect({mouse.x, mouse.y}, b.x, text_y-toff, b.w-8, 12)
                    end
                    local tfade = fade
                    if is_hovered then
                        if input[1][3] or input[2][3] then tfade = 0.5 else tfade = 0.65 end
                        if not l.open_send then hovered.message = v end
                    else
                        if hovered.message == v then tfade = 0.5 end
                    end
                    local copy = render:text(b.x, text_y-toff, k, tfade)
                    if is_hovered then
                        if input[1][4] then
                            OverlayAPI.CopyTextToClipboard(copy)
                        end
                        if input[2][2] then
                            l.open_send = not l.open_send
                        end
                    end
                end
            end
            if l.open_send then
                local send = {x=b.x-110, y = text_y-((text_dpi[2]+2)*(#data.logs-hovered.message))}
                hovered.send = funcs.intersect({mouse.x, mouse.y}, send.x, send.y, 80, 40)
                local hover_glob, hover_team = funcs.intersect({mouse.x, mouse.y}, send.x, send.y, 80, 18), funcs.intersect({mouse.x, mouse.y}, send.x, send.y+20, 80, 18)
                if not hovered.send then
                    if input[1][2] then l.open_send = false end
                end
                c["render"].rectangle(send.x-1, send.y-1, 82, 42, 0, 0, 0, 255*fade)
                c["render"].rectangle(send.x, send.y, 80, 40, 25, 25, 25, 255*fade)
                if hover_glob then
                    c["render"].rectangle(send.x, send.y, 80, 20, 15, 15, 15, 255*fade)
                    if input[1][4] then
                        client.exec("say ", data.logs[hovered.message].text)
                        l.open_send = false
                    end
                end
                c["render"].text(send.x+8, send.y+4, 220, 220, 220, 255*fade, "", 0, "Global chat")
                if hover_team then
                    c["render"].rectangle(send.x, send.y+20, 80, 20, 15, 15, 15, 255*fade)
                    if input[1][4] then
                        client.exec("say_team ", data.logs[hovered.message].text)
                        l.open_send = false
                    end
                end
                c["render"].text(send.x+8, send.y+24, 220, 220, 220, 255*fade, "", 0, "Team chat")
            end
            c["render"].rectangle(x+14, y+20+off, w-40, 7, 15, 15, 15, 255*fade)
            c["render"].gradient(x+14, y+25+off, w-40, 15, 15, 15, 15, 255*fade, 15, 15, 15, 20*fade, false)
            c["render"].gradient(x+14, y+h-30+off, w-40, 15, 15, 15, 15, 20*fade, 15, 15, 15, 255*fade, false)
            c["render"].text(x+12, y+2+off, 220, 220, 220, 255*fade, "db", 0, l.pre[1])
            c["render"].text(x+12+c["render"].measure("db", l.pre[1]), y+2+off, local_data.clr.r, local_data.clr.g, local_data.clr.b, 255*fade, "db", 0, l.pre[2])

            l.scroll.x = b.x+b.w+4
            l.scroll.y = math.max(b.y+12, math.min(b.y+b.h-scroll.h, b.y+scroll.y_+(2*#data.logs)))
            l.scroll.h = math.max(12, (b.h)-(2*#data.logs))
            c["render"].rectangle(b.x+b.w+3, b.y+10+off, 6, b.h-2, 45, 45, 45, 255*fade)
            if scroll.h < b.h-5 then
                c["render"].rectangle(scroll.x, scroll.y+off, 4*dpi, scroll.h, 60, 60, 60, 255*fade)
            end
        end
    else
        l.open_send = false
    end
    l.fade = funcs.clamp(l.fade + (l.open and speed/2 or -speed), 0, 1)
end

client.set_event_callback("paint_ui", render.window)
client.set_event_callback("output", function(e) api.print("log", e.r, e.g, e.b, true, e.text) end)
client.set_event_callback("console_input", function(e)
    if e:sub(1, 9):lower() == "clear_lua" then
        print("Cleared custom console")
        data.logs = {}
        c["data"].write("custom_console/logs", nil)
        return true
    end
end)
client.set_event_callback("round_start", function()
    if funcs.contains(ui.get(settings.render_rounds), "Print on round start") then
        api.print("message", local_data.clr.r, local_data.clr.g, local_data.clr.b, false, "» Round started!")
    end
end)

--» ui handling
local function ui_hide(self)
    local e = ui.get(self)
    for v, k in pairs(settings) do
        if v ~= "show" and v ~= "hotkey" then
            ui.set_visible(settings[v], e)
        end
    end
end
local function clearl()
    if ui.get(settings.clear_logs) then
        c["data"].write("custom_console/logs", nil)
    end
    c["data"].write("custom_console/clear", ui.get(settings.clear_logs))
end
ui.set_callback(settings.show, ui_hide)
ui_hide(settings.show)
client.set_event_callback("shutdown", clearl)

--» return custom console api
package.preload["gamesense/custom_console"] = function()
	return api
end
