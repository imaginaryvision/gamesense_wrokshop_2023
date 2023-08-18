local ffi = require "ffi"
local sprites = { 
    ["Blue glow"] = "sprites/blueglow1.vmt",
	["Bubble"] = "sprites/bubble.vmt",
	["Glow"] = "sprites/glow01.vmt",
    ["Physbeam"] = "sprites/physbeam.vmt",
	["Purple glow"] = "sprites/purpleglow1.vmt",
    ["Purple laser"] = "sprites/purplelaser1.vmt",
	["White"] = "sprites/white.vmt",
}

local master_switch = ui.new_checkbox("lua", "a", "Bullet beam tracers")
local beam_thickness = ui.new_slider("lua", "a", "\n beam_thickness", 1, 100, 40, true, "sz", 1)
local beam_duration = ui.new_slider("lua", "a", "Bullet beams time", 1, 20, 4, true, "s", 1)
local beam_sprite = ui.new_combobox("lua", "a", "\n beam_sprite", (function()
    local list = {}

    for name, value in pairs(sprites) do
        list[#list+1] = name
    end

    return list
end)())

ui.set(beam_sprite, "Purple laser")

local beam_local = ui.new_checkbox("lua", "a", "Local player tracers")
local beam_local_clr = ui.new_color_picker("lua", "a", "\n beam_local_clr", 37, 96, 142, 145)

local beam_local_hit = ui.new_checkbox("lua", "a", "Local player tracers hit")
local beam_local_hit_clr = ui.new_color_picker("lua", "a", "\n beam_local_hit_clr", 249, 0, 59, 145)

local beam_enemy = ui.new_checkbox("lua", "a", "Enemy tracers")
local beam_enemy_clr = ui.new_color_picker("lua", "a", "\n beam_enemy_clr", 155, 54, 187, 255)

ffi.cdef([[
    typedef struct { 
        float x; 
        float y; 
        float z;
    } bbvec3_t;

    struct bbeam_t
    {
        int m_nType;
        void* m_pStartEnt;
        int m_nStartAttachment;
        void* m_pEndEnt;
        int m_nEndAttachment;
        bbvec3_t m_vecStart;
        bbvec3_t m_vecEnd;
        int m_nModelIndex;
        const char* m_pszModelName;
        int m_nHaloIndex;
        const char* m_pszHaloName;
        float m_flHaloScale;
        float m_flLife;
        float m_flWidth;
        float m_flEndWidth;
        float m_flFadeLength;
        float m_flAmplitude;
        float m_flBrightness;
        float m_flSpeed;
        int m_nStartFrame;
        float m_flFrameRate;
        float m_flRed;
        float m_flGreen;
        float m_flBlue;
        bool m_bRenderable;
        int m_nSegments;
        int m_nFlags;
        bbvec3_t m_vecCenter;
        float m_flStartRadius;
        float m_flEndRadius;
    };
]])

local bullet_beam_sign = client.find_signature("client.dll", "\xB9\xCC\xCC\xCC\xCC\xA1\xCC\xCC\xCC\xCC\xFF\x10\xA1\xCC\xCC\xCC\xCC\xB9")
local beams = ffi.cast("void**", ffi.cast("char*", bullet_beam_sign) + 1)[0]
local beams_ptr = ffi.cast("void***", beams)

local draw_beams = ffi.cast("void (__thiscall*)(void*, void*)", beams_ptr[0][6])
local create_beam_points = ffi.cast("void*(__thiscall*)(void*, struct bbeam_t&)", beams_ptr[0][12])

local function create_vec3(vec)
    local ffi_vector = ffi.new("bbvec3_t")

    ffi_vector.x, ffi_vector.y, ffi_vector.z = vec[1], vec[2], vec[3]

    return ffi_vector
end

local function render_beam(_start, _end, clr)
    local beam_info = ffi.new("struct bbeam_t")
    local beam_width = ui.get(beam_thickness) * 0.1

    _start[3] = _start[3]-1

    beam_info.m_vecStart = create_vec3(_start)
    beam_info.m_vecEnd = create_vec3(_end)
    beam_info.m_nSegments = 2
    beam_info.m_nType = 0x00
    beam_info.m_bRenderable = true
    beam_info.m_nFlags = bit.bor(0x00000100 + 0x00000008 + 0x00000200 + 0x00008000)
    beam_info.m_pszModelName = sprites[ui.get(beam_sprite)]
    beam_info.m_nModelIndex = -1
    beam_info.m_flHaloScale = 0.0
    beam_info.m_nStartAttachment = 0
    beam_info.m_nEndAttachment = 0
    beam_info.m_flLife = ui.get(beam_duration)
    beam_info.m_flWidth = beam_width
    beam_info.m_flEndWidth = beam_width
    beam_info.m_flFadeLength = 0
    beam_info.m_flAmplitude = 5.0
    beam_info.m_flSpeed = 0
    beam_info.m_flFrameRate = 0.0
    beam_info.m_nHaloIndex = 0
    beam_info.m_nStartFrame = 0
    beam_info.m_flBrightness = clr[4]
    beam_info.m_flRed = clr[1]
    beam_info.m_flGreen = clr[2]
    beam_info.m_flBlue = clr[3]

    local beam = create_beam_points(beams_ptr, beam_info)

    if beam ~= nil then 
		draw_beams(beams, beam)
    end
end

local function add_to_queue(idx, record)
    local me = entity.get_local_player()

    local is_self = me == idx
    local is_enemy = ui.get(beam_enemy) and entity.is_enemy(idx)

    if not is_self and not is_enemy then
        return
    end

    local r, g, b, a = ui.get(record.is_enemy and beam_enemy_clr or beam_local_clr)

    if not ui.get(beam_local) and is_self and not record.projected then
        return
    end

    if ui.get(beam_local_hit) and not record.is_enemy and record.projected then
        r, g, b, a = ui.get(beam_local_hit_clr)
    end

    render_beam(record.origin, record.list[#record.list], {r, g, b, a})
end

local aimbot_fired = false
local old_next_attack = -1
local old_weapon_index = -1

local self_angles = {}
local bt_data = {}

local hitgroups = {
    [1] = {0, 1},
    [2] = {4, 5, 6},
    [3] = {2, 3},
    [4] = {13, 15, 16},
    [5] = {14, 17, 18},
    [6] = {7, 9, 11},
    [7] = {8, 10, 12}
}

local function add_command()
    if ui.get(master_switch) and (ui.get(beam_local) or ui.get(beam_local_hit)) then
        self_angles[#self_angles+1] = {
            m_bPassed = false,
            m_flLife = globals.realtime()+0.5,
            m_vecStart = {client.eye_position()}
        }
    end
end

client.set_event_callback("aim_fire", function(c)
    aimbot_fired = true
    add_command()
end)

client.set_event_callback("setup_command", function()
    local me = entity.get_local_player()
    local wpn = entity.get_player_weapon(me)

    if me == nil or wpn == nil then
        return
    end

    local next_attack = entity.get_prop(wpn, "m_flNextPrimaryAttack")
    local weapon_index = bit.band(entity.get_prop(wpn, "m_iItemDefinitionIndex") or 0, 0xFFFF)
    add_command()
end)

client.set_event_callback("round_start", function()
    bt_data = {}
    self_angles = {}
end)

client.set_event_callback("weapon_fire", function(c)
    local tick = globals.tickcount()

    local me = entity.get_local_player()
    local user = client.userid_to_entindex(c.userid)

    if bt_data[user] == nil then
        bt_data[user] = {}
    end

    if bt_data[user][tick] == nil then
        bt_data[user][tick] = {}
    end

    local new_data = bt_data[user][tick]
    local eye = {}
    if me == user then
        eye = {client.eye_position()}
    else
        eye = {entity.hitbox_position(user, 0)}
    end
    local is_enemy = user ~= me and entity.is_enemy(user)

    if user == me then
        local found = false

        for i = 1, #self_angles do
            local data = self_angles[i]

            if data ~= nil and not data.m_bPassed then
                self_angles[i].m_bPassed = true
                eye, found = data.m_vecStart, true
                --break
            end
        end

        if not found then
            eye = nil
        end
    end

    bt_data[user][tick][#new_data+1] = {
        list = {},
        origin = eye,
        is_enemy = is_enemy,
        dead_time = globals.realtime()+0.5,
        projected = false
    }
end)

client.set_event_callback("bullet_impact", function(c)
    local me = entity.get_local_player()
    local user = client.userid_to_entindex(c.userid)
    local tick = globals.tickcount()
    local records = bt_data[user][tick]

    table.insert(bt_data[user][tick][#records].list, {c.x, c.y, c.z})
end)

client.set_event_callback("player_hurt", function(c)
    local tick = globals.tickcount()
    local me = entity.get_local_player()
    local user = client.userid_to_entindex(c.attacker)

    local closest = math.huge
    local hitboxes = hitgroups[c.hitgroup]
    local record = bt_data[user][tick][#bt_data[user][tick]]

    for i = 1, #record.list do
        local current = record.list[i]

        if hitboxes ~= nil then
            for j = 1, #hitboxes do
                local x, y, z = entity.hitbox_position(user, hitboxes[j])

                if x ~= nil then
                    local distance = math.sqrt((current[1] - x)^2 + (current[2] - y)^2 + (current[3] - z)^2)
    
                    if distance < closest then
                        closest = distance
                        record.projected = true
                    end
                end
            end
        end
    end
end)

client.set_event_callback("paint", function()
    local realtime = globals.realtime()
    local me = entity.get_local_player()

    for eid, ent in pairs(bt_data) do
        for _, tick in pairs(ent) do
            if #tick <= 0 or tick == { } then
                bt_data[eid][_] = nil
            end

            for id, shot in pairs(tick) do
                local record = bt_data[eid][_][id]

                if shot.dead_time < realtime or record.origin == nil or #record.list <= 0 then
                    bt_data[eid][_][id] = nil
                else
                    add_to_queue(eid, record)
                    bt_data[eid][_][id] = nil
                end
            end

        end
    end

    for i = 1, #self_angles do
        if self_angles[i] == nil or self_angles[i].m_bPassed or self_angles[i].m_flLife < realtime then
            table.remove(self_angles, i)
        end
    end
end)