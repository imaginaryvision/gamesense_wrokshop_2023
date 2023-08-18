require "gamesense/panorama_valve_utils"

local js = panorama.open()
local active_operation = js.GameTypesAPI.GetActiveSeasionIndexValue()

if active_operation ~= nil and active_operation > 0 then
	local function color_log_escape(r, g, b, ...)
		local text = table.concat({...})

		client.color_log(r, g, b, (text:match("^[^\a]*")), "\0")

		for part in text:gmatch("\a[^\a]*") do
			local r = tonumber("0x" .. part:sub(2, 3))
			local g = tonumber("0x" .. part:sub(4, 5))
			local b = tonumber("0x" .. part:sub(6, 7))

			client.color_log(r, g, b, part:sub(8, -1), "\0")
		end
		client.color_log(r, g, b, "\n\0")
	end

	local OperationUtil, MissionsAPI, InventoryAPI = js.OperationUtil, js.MissionsAPI, js.InventoryAPI
	local localize = js["$"].Localize

	local localize_mission_panel = panorama.loadstring([[
		return [(text, missionid) => {
			let panel = $.CreatePanel("Panel", $.GetContextPanel(), "")
			MissionsAPI.ApplyQuestDialogVarsToPanelJS(missionid, panel)

			let str = $.Localize(text, panel)
			panel.DeleteAsync(0.0)

			return str
		}]
	]], "CSGOMainMenu")()[0]

	ui.new_button("MISC", "Miscellaneous", "Dump Operation Missions", function()
		OperationUtil.ValidateOperationInfo(active_operation)

		client.log("Operation ", localize("op" .. active_operation+1 .. "_name"), " Missions:")

		local missions_count = MissionsAPI.GetSeasonalOperationMissionCardsCount(active_operation)
		for i=1, missions_count do
			local jso = json.parse(tostring(MissionsAPI.GetSeasonalOperationMissionCardDetails(active_operation, i-1)))
			local is_unlocked = i-1 < InventoryAPI.GetMissionBacklog()

			color_log_escape(230, 230, 230, "\aB6E717Week ", i, ": ", localize(jso.name), " \aB6B6B6(", jso.operational_points, " points possible)")

			if #jso.quests == 0 then
				client.color_log(201, 201, 201, "  Missions not known yet")
			else
				for i=1, #jso.quests do
					local missionid = jso.quests[i]
					local itemid = InventoryAPI.GetQuestItemIDFromQuestID(missionid)

					local localized = localize_mission_panel(MissionsAPI.GetQuestDefinitionField(missionid, "loc_description"), missionid):gsub("<b>", ""):gsub("</b>", ""):gsub("%.$", "")
					local point_count = MissionsAPI.GetQuestPoints(missionid, "count")
					local point_goal = MissionsAPI.GetQuestPoints(missionid, "goal")
					local point_remaining = MissionsAPI.GetQuestPoints(missionid, "remaining")
					local operational_points = MissionsAPI.GetQuestDefinitionField(missionid, "operational_points")

					local awards_text = point_goal > 1 and "required: " .. point_goal .. ", " or ""

					if point_goal > 1 and point_remaining > 0 and point_remaining ~= point_goal then
						awards_text = awards_text .. "progress: " .. point_goal-point_remaining .. ", "
					end

					color_log_escape(160, 160, 160, "  \aDEDEDE", InventoryAPI.GetItemName(itemid), "\aC8C8C8: ", localized, " \aADADAD(", awards_text, "awards ", operational_points*point_count, " points) ", is_unlocked and (point_remaining == 0 and "\a9BC20C√" or "\aFF2929X") or "")
				end
			end
		end
		client.color_log(210, 210, 210, " ")
	end)
end