local ui_get, ui_set = ui.get, ui.set
local disable_fakelag_on_round_end = ui.new_checkbox("aa", "fake lag", "Disable fake lag on round end")
local fakelag_enabled_reference = ui.reference("aa", "fake lag", "enabled")

local function handle_round_start(e)
	if ui_get(disable_fakelag_on_round_end) then -- Enable fakelag
		ui_set(fakelag_enabled_reference, true)
	end
end 

local function handle_round_end(e)
	if ui_get(disable_fakelag_on_round_end) then -- Disable fakelag
		ui_set(fakelag_enabled_reference, false)
	end
end

client.set_event_callback("round_start", handle_round_start)
client.set_event_callback("round_end", handle_round_end)