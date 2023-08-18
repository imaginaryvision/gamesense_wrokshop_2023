local vector = require("vector")
menu = {
	enabled = ui.new_checkbox("LUA", "A", "Enable Sonar"),
	volume = ui.new_slider("LUA", "A", "Sonar Volume", 0, 10, 10, true, "", 0.1),
	minDistance = ui.new_slider("LUA", "A", "Sonar Min Distance", 0, 1000, 0, true, "f"),
	maxDistance = ui.new_slider("LUA", "A", "Sonar Max Distance", 0, 1000, 250, true, "f"),
	teams = ui.new_checkbox("LUA", "A", "Sonar On Teammates")
}
slot2 = 0

function slot3()
	slot0 = nil
	slot6 = uv1.teams

	for slot6, slot7 in ipairs(entity.get_players(not ui.get(slot6))) do
		slot9 = vector(entity.get_prop(entity.get_local_player(), "m_vecOrigin")):dist(vector(entity.get_prop(slot7, "m_vecOrigin")))

		if slot0 == nil or slot9 < slot0 then
			slot0 = slot9
		end
	end

	if slot0 ~= nil then
		return slot0 * 0.0254 * 3.281
	end
end

function slot4(slot0)
	if globals.realtime() > slot2 + slot0 then
		client.exec("playvol  ", "/buttons/blip1.wav ", ui.get(menu.volume) * 0.1)

		slot2 = globals.realtime()
	end
end

client.set_event_callback("run_command", function ()
	if entity.is_alive(entity.get_local_player()) and ui.get(menu.enabled) then
		slot3 = ui.get(menu.maxDistance)

		if uv1() ~= nil and (slot1 <= slot3 or slot3 == 0) and ui.get(menu.minDistance) <= slot1 then
			slot4(slot1 / slot3 * 5)
		end
	end
end)
