local localPlayer = entity.get_local_player();  
local playerX, playerY, playerZ, ceiling;

if (localPlayer ~= nil) then
	playerX, playerY, playerZ = entity.get_origin(localPlayer);
	ceiling = playerZ + (100000 * client.trace_line(localPlayer, playerX, playerY, playerZ, playerX, playerY, playerZ + 100000));
end

local x, y = renderer.world_to_screen(playerX, playerY, playerZ)
local maxDistance = 250;
local locationCreation = { false, 0, 0, 0 };
local locations = {};
local guiReferences = {};
local currentWeapon;

if (localPlayer ~= nil) then
	currentWeapon = entity.get_classname(entity.get_player_weapon(localPlayer));
end

local onion_location;
local inside = false;
local perLocationSettings = {};
local insideName = "";
guiReferences["dt"] = ui.reference("RAGE", "Other", "Double Tap");
guiReferences["hitchance"] = ui.reference("RAGE", "Aimbot", "Minimum Hit Chance");
guiReferences["mindamage"] = ui.reference("RAGE", "Aimbot", "Minimum Damage");
guiReferences["limbsafe"] = ui.reference("RAGE", "Aimbot", "Force Safe Point on Limbs");
guiReferences["prefersafe"] = ui.reference("RAGE", "Aimbot", "Prefer Safe Point");
local weapons = { {"CDEagle", "R8 or Deagle"}, {"CWeaponSSG08", "SSG 08"}, {"CWeaponAWP", "AWP"}, {"CWeaponG3SG1", "G3SG1"}, {"CWeaponSCAR20", "SCAR-20"} }
local weaponUI = {};

ui.new_label("LUA", "B", "-+-+-+-+ [ Onion's Position LUA ] +-+-+-+-")

local dtEnabled = false;
local names = {};
if (ui.get(guiReferences["dt"])) then
	dtEnabled = true;
end
local hasShot = false;

local onion_enabled = ui.new_checkbox("LUA", "B", "Enabled")
local onion_antirecharge_enabled = ui.new_checkbox("LUA", "B", "Disable Recharge in Region")
local onion_debug_lines = ui.new_checkbox("LUA", "B", "Debug Lines")
local onion_draw_distance = ui.new_slider("LUA", "B", "Draw Distance", 5, 5000, 250)
local onion_draw_color_custom = ui.new_checkbox("LUA", "B", "Custom Colors")
local onion_colors = { ui.new_checkbox("LUA", "B", "Draw Color"), ui.new_color_picker("LUA", "B", "Draw Color", 3, 136, 252, 100), ui.new_checkbox("LUA", "B", "Hover Color"), ui.new_color_picker("LUA", "B", "Hover Color", 252, 198, 3, 100) }
local onion_text_posname = ui.new_textbox("LUA", "B", "Position Name");

local function pointInside(x1, x2, y1, y2, x3, y3)
	local sizeTable = { tonumber(x1), tonumber(x2), tonumber(x3), tonumber(y1), tonumber(y2), tonumber(y3) };

	for i = 1, #sizeTable do
		if (sizeTable[i] > 0) then
			sizeTable[i] = sizeTable[i] + 100000
		end

		sizeTable[i] = math.abs(sizeTable[i]);
	end

	if (sizeTable[1] > sizeTable[2]) then
		if (sizeTable[3] > sizeTable[1] or sizeTable[3] < sizeTable[2]) then
			return false;
		end
	else
		if (sizeTable[3] < sizeTable[1] or sizeTable[3] > sizeTable[2]) then
			return false;
		end
	end

	if (sizeTable[4] > sizeTable[5]) then
		if (sizeTable[6] > sizeTable[4] or sizeTable[6] < sizeTable[5]) then
			return false;
		end
	else
		if (sizeTable[6] < sizeTable[4] or sizeTable[6] > sizeTable[5]) then
			return false;
		end
	end

	return true;
end

local function splitStr(inputstr, sep)
	if sep == nil then
			sep = "%s"
	end
	local t={}
	if (inputstr ~= nil) then
		for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
				table.insert(t, str)
		end
	end
	return t
end

local mapTable = splitStr(globals.mapname(), "/");
local map = mapTable[#mapTable];

local function loadSettings(str)
	if (weaponUI ~= nil and str ~= nil) then
		local lines = splitStr(str, "\n")

		for i = 1, #lines do
			if (weaponUI[i] ~= nil and weaponUI[i][1] ~= nil) then
				local one, two, three, four;
				local settings = splitStr(lines[i], "|")
				if (string.find(settings[1], "true")) then one = true; else one = false; end
				if (string.find(settings[4], "true")) then two = true; else two = false; end
				if (string.find(settings[5], "true")) then three = true; else three = false; end
				if (string.find(settings[6], "true")) then four = true; else four = false; end

				ui.set(weaponUI[i][1], one);
				ui.set(weaponUI[i][2], tonumber(settings[2]));
				ui.set(weaponUI[i][3], tonumber(settings[3]));
				ui.set(weaponUI[i][4], two);
				ui.set(weaponUI[i][5], three);
				ui.set(weaponUI[i][6], four);
			end
		end
	end
end

local function loadInformation()
	if (localPlayer ~= nil) then
		locations = {};
		names = {};
		
		local positions = readfile("onionPositions_" .. map .. ".db")
		
		perLocationSettings = {};
		local settingsRead = readfile("onionSettings.db")
		local settingLines = splitStr(settingsRead, "\n")

		for i = 1, #settingLines do
			if (string.find(settingLines[i], "map: ")) then
				table.insert(perLocationSettings, { settingLines[i + 1] .. "\n" .. settingLines[i + 2] .. "\n" .. settingLines[i + 3] .. "\n" .. settingLines[i + 4] .. "\n" .. settingLines[i + 5], string.gsub(settingLines[i], "map: ", "")})
			end
		end

		if (#perLocationSettings ~= 0) then
			for i = 1, #perLocationSettings do
				if (string.find(perLocationSettings[i][2], insideName)) then
					loadSettings(perLocationSettings[i][1]);
				end
			end
		end

		if (positions ~= nil and positions ~= "") then
			local lines = splitStr(positions, "\n")

			for i = 1, #lines do
				local splitLine = splitStr(lines[i], "|");

				if (#splitLine == 6) then
					table.insert(locations, {splitLine[1], splitLine[2], {splitLine[3], splitLine[4]}, {splitLine[5], splitLine[6]}});
					table.insert(names, splitLine[1]);
				else
					table.insert(locations, {'Name', splitLine[1], {splitLine[2], splitLine[3]}, {splitLine[4], splitLine[5]}});
					table.insert(names, 'Name');
				end
			end
		end
	end
end

local function deleteLocation()
	name = ui.get(onion_location);
	local locations = readfile("onionPositions_" .. map .. ".db")
	local endText;

	if (locations ~= nil and locations ~= "") then
		local lines = splitStr(locations, "\n")

		for i = 1, #lines do
			if (not string.find(lines[i], name)) then
				if (endText ~= nil) then
					endText = endText + "\n" + lines[i];
				else
					endText = lines[i]
				end
			end
		end

		writefile("onionPositions_" .. map .. ".db", endText)
	end
end

local function createLocation()
	if (ui.get(onion_enabled) and localPlayer ~= nil) then
		if (locationCreation[1]) then
			locationCreation[1] = false;
			
			local name = "Name"

			if (ui.get(onion_text_posname) ~= nil and ui.get(onion_text_posname) ~= "") then
				name = ui.get(onion_text_posname);
			end

			local text = readfile("onionPositions_" .. map .. ".db");
			if (text ~= "" and text ~= nil) then
				writefile("onionPositions_" .. map .. ".db", text .. "\n" .. name .. "|" .. locationCreation[4] .. "|" .. locationCreation[2] .. "|" .. locationCreation[3] .. "|" .. playerX .. "|" .. playerY);
			else
				writefile("onionPositions_" .. map .. ".db", name .. "|" .. locationCreation[4] .. "|" .. locationCreation[2] .. "|" .. locationCreation[3] .. "|" .. playerX .. "|" .. playerY)
			end

			loadInformation()
			locationCreation[2], locationCreation[3], locationCreation[4] = 0, 0, 0;
		else
			locationCreation[1] = true;
			locationCreation[2], locationCreation[3], locationCreation[4] = playerX, playerY, playerZ;
		end
	end
end

local function logLocation()
	if (ui.get(onion_enabled) and localPlayer ~= nil) then
		client.color_log(66, 164, 245, "playerX: " .. playerX .. " playerY: " .. playerY .. " playerZ: " .. playerZ .. " Player Ceiling: " .. ceiling .. "\n");

		for i = 0, 1 do
			local yAxis = client.trace_line(localPlayer, playerX, playerY, playerZ, playerX, playerY - 100 + (200 * i), playerZ)
			local xAxis = client.trace_line(localPlayer, playerX, playerY, playerZ, playerX - 100 + (200 * i), playerY, playerZ)
			local xX, xY = renderer.world_to_screen(playerX + ((-100 + (200 * i)) * xAxis), playerY, playerZ)
			local yX, yY = renderer.world_to_screen(playerX, playerY + ((-100 + (200 * i)) * yAxis), playerZ)

			if (yAxis ~= 1) then
				client.color_log(0, 255, 0, "Hit on the Y Axis, yAxis: " .. yAxis .. ", Original playerY: " .. playerY - 100 + (200 * i) .. ", playerY Hit: " .. playerY + ((-100 + (200 * i)) * yAxis) .. ", i: " .. i .. "\n");
			else
				client.color_log(255, 0, 0, "No hit on the Y Axis, i: " .. i .. "\n");
			end

			if (xAxis ~= 1) then
				client.color_log(0, 255, 0, "Hit on the X Axis, xAxis: " .. xAxis .. ", Original playerX: " .. playerX - 100 + (200 * i) .. ", playerX Hit: " .. playerX + ((-100 + (200 * i)) * xAxis) .. ", i: " .. i .. "\n");
			else
				client.color_log(255, 0, 0, "No hit on the X Axis, i: " .. i .. "\n");
			end
		end
	end
end

local function saveSettings()
	if (ui.get(onion_enabled) and inside) then
		local save;

		for i = 1, #weapons do
			local one, two, three, four;
			if (ui.get(weaponUI[i][1])) then one = "true"; else one = "false"; end
			if (ui.get(weaponUI[i][4])) then two = "true"; else two = "false"; end
			if (ui.get(weaponUI[i][5])) then three = "true"; else three = "false"; end
			if (ui.get(weaponUI[i][6])) then four = "true"; else four = "false"; end

			if (save == nil) then
				save = one .. "|" .. ui.get(weaponUI[i][2]) .. "|" .. ui.get(weaponUI[i][3]) .. "|" .. two .. "|" .. three .. "|" .. four;
			else
				save = save .. "\n" .. one .. "|" .. ui.get(weaponUI[i][2]) .. "|" .. ui.get(weaponUI[i][3]) .. "|" .. two .. "|" .. three .. "|" .. four;
			end
		end

		local text = readfile("onionSettings.db")
		local lines = splitStr(text, "\n")
		local endtext;
		local contains = false;
		local containIndex = 0;

		for i = 1, #lines do
			if (string.find(lines[i], insideName)) then
				contains = true;
				containIndex = i;
			end
		end

		if (contains) then
			for i = 1, 6 do
				table.remove(lines, containIndex);
			end
		end

		for i = 1, #lines do
			if (endtext == nil or endtext == "") then
				endtext = lines[i];
			else
				endtext = endtext .. "\n" .. lines[i];
			end
		end
		
		client.color_log(255, 255, 255, insideName)
		if (endtext ~= nil) then
			writefile("onionSettings.db", endtext)
		end
		client.color_log(255, 255, 255, "Mainframe 1/2")
		local currentText = readfile("onionSettings.db");
		if (currentText ~= nil and currentText ~= "") then
			client.color_log(255, 255, 255, "Mainframe 1")
			writefile("onionSettings.db", currentText .. "\nmap: " .. insideName .. "\n" .. save)
		else
			client.color_log(255, 255, 255, "Mainframe 2")
			writefile("onionSettings.db", "map: " .. insideName .. "\n" .. save)
		end
	else
		client.color_log(255, 255, 255, "Please step inside a location to save settings.")
	end
end

loadInformation();
if (names ~= nil and #names ~= 0) then
	onion_location = ui.new_combobox("LUA", "B", "Location", names)
end
local onion_button_log = ui.new_button("LUA", "B", "Log Location", logLocation)
local onion_button_createpos = ui.new_button("LUA", "B", "Create Position", createLocation)
if (names ~= nil and #names ~= 0) then
	local onion_button_deletepos = ui.new_button("LUA", "B", "Delete Position", deleteLocation)
end
local onion_button_updatepos = ui.new_button("LUA", "B", "Update Settings", loadInformation)
local weaponLabel = ui.new_label("LUA", "B", "-+-+-+-+ [ Aim -  ] +-+-+-+-")

if (currentWeapon ~= nil) then
	ui.set(weaponLabel, "LUA", "B", "-+-+-+-+ [ Aim - " .. currentWeapon .. " ] +-+-+-+-")
end
local onion_button_savesettings = ui.new_button("LUA", "B", "Save Settings", saveSettings)
for i = 1, #weapons do
	table.insert(weaponUI, {ui.new_checkbox("LUA", "B", "Double Tap"), ui.new_slider("LUA", "B", "Minimum hit chance", 0, 100, 10), ui.new_slider("LUA", "B", "Minimum Damage", 0, 126, 10), ui.new_checkbox("LUA", "B", "Force Safe-Point on Limbs"), ui.new_checkbox("LUA", "B", "Prefer Safe-Point"), ui.new_checkbox("LUA", "B", "Override Aimbot")})
end

ui.new_label("LUA", "B", "-+-+-+-+ [ Onion's Position LUA ] +-+-+-+-")
local isInside = false;
local insideIndex;

client.set_event_callback("paint", function()
	localPlayer = entity.get_local_player();
	local mapTable = splitStr(globals.mapname(), "/");
	map = mapTable[#mapTable];

	for i = 1, #onion_colors do
		ui.set_visible(onion_colors[i], ui.get(onion_draw_color_custom))
	end

	if (ui.get(onion_enabled) and localPlayer ~= nil and entity.is_alive(localPlayer)) then
		currentWeapon = entity.get_classname(entity.get_player_weapon(localPlayer))
		playerX, playerY, playerZ = entity.get_origin(localPlayer)
		x, y = renderer.world_to_screen(playerX, playerY, playerZ)
		ceiling = playerZ + (100000 * client.trace_line(localPlayer, playerX, playerY, playerZ, playerX, playerY, playerZ + 100000));


		ui.set(weaponLabel, "-+-+-+-+ [ Aim - " .. currentWeapon .. " ] +-+-+-+-")

		for i = 1, #weapons do
			if (currentWeapon ~= weapons[i][1]) then
				for f = 1, #weaponUI[i] do
					ui.set_visible(weaponUI[i][f], false)
				end
			else
				for f = 1, #weaponUI[i] do
					ui.set_visible(weaponUI[i][f], true)
				end
			end
		end

		if (locationCreation[1]) then
			p, pp = renderer.world_to_screen(locationCreation[2], locationCreation[3], locationCreation[4])
			c, cc = renderer.world_to_screen(playerX, locationCreation[3], locationCreation[4])
			d, dd = renderer.world_to_screen(locationCreation[2], playerY, locationCreation[4])
			k, kk = renderer.world_to_screen(playerX, playerY, locationCreation[4])
			renderer.line(p, pp, c, cc, 255, 255, 255, 255);
			renderer.line(p, pp, d, dd, 255, 255, 255, 255);
			renderer.line(k, kk, c, cc, 255, 255, 255, 255);
			renderer.line(k, kk, d, dd, 255, 255, 255, 255);
		end
		
		if (ui.get(onion_debug_lines)) then
			for i = 0, 1 do
				local yAxis = client.trace_line(localPlayer, playerX, playerY, playerZ, playerX, playerY - 100 + (200 * i), playerZ)
				local xAxis = client.trace_line(localPlayer, playerX, playerY, playerZ, playerX - 100 + (200 * i), playerY, playerZ)
				local xX, xY = renderer.world_to_screen(playerX + ((-100 + (200 * i)) * xAxis), playerY, playerZ)
				local yX, yY = renderer.world_to_screen(playerX, playerY + ((-100 + (200 * i)) * yAxis), playerZ)
				renderer.line(x, y, yX, yY, 255, 255, 255, 255)
				renderer.line(x, y, xX, xY, 255, 255, 255, 255)
			end

			local testX, testY = renderer.world_to_screen(playerX, playerY, ceiling)
			renderer.line(x, y, testX, testY, 255, 255, 255, 255)
		end

		inside = false;

		for i = 1, #locations do
			if (pointInside(locations[i][3][1], locations[i][4][1], locations[i][3][2], locations[i][4][2], playerX, playerY)) then				 
				inside = true;
				if (insideName ~= locations[i][1]) then
					insideName = locations[i][1]
					loadInformation();
				end

				for i = 1, #weapons do
					if (currentWeapon == weapons[i][1]) then
						if (ui.get(weaponUI[i][6])) then
							if (not ui.get(onion_antirecharge_enabled)) then
								ui.set(guiReferences["dt"], ui.get(weaponUI[i][1]));
							end

							ui.set(guiReferences["hitchance"], ui.get(weaponUI[i][2]));
							ui.set(guiReferences["mindamage"], ui.get(weaponUI[i][3]));
							ui.set(guiReferences["limbsafe"], ui.get(weaponUI[i][4]));
							ui.set(guiReferences["prefersafe"], ui.get(weaponUI[i][5]));
						end
					end
				end
				
				if (not isInside) then
					isInside = true;
					insideIndex = i;
				end

				if (dtEnabled and currentWeapon ~= "CWeaponAWP" and currentWeapon ~= "CWeaponSSG08") then
					if (ui.get(onion_antirecharge_enabled)) then
						if (hasShot) then
							ui.set(guiReferences["dt"], false);
						else
							ui.set(guiReferences["dt"], true);
						end
					end
				end
					
				trX, trY = renderer.world_to_screen(locations[i][3][1], locations[i][3][2], locations[i][2])
				tlX, tlY = renderer.world_to_screen(locations[i][3][1], locations[i][4][2], locations[i][2])
				blX, blY = renderer.world_to_screen(locations[i][4][1], locations[i][3][2], locations[i][2])
				brX, brY = renderer.world_to_screen(locations[i][4][1], locations[i][4][2], locations[i][2])

				if (ui.get(onion_colors[3]) and ui.get(onion_draw_color_custom)) then
					renderer.triangle(tlX, tlY, brX, brY, blX, blY, ui.get(onion_colors[4]))
					renderer.triangle(tlX, tlY, trX, trY, blX, blY, ui.get(onion_colors[4]))
				else
					renderer.triangle(tlX, tlY, brX, brY, blX, blY, 255, 255, 255, 150)
					renderer.triangle(tlX, tlY, trX, trY, blX, blY, 255, 255, 255, 150)
				end
			else
				if (not isInside or i == insideIndex) then
					if (dtEnabled and currentWeapon ~= "CWeaponAWP" and currentWeapon ~= "CWeaponSSG08") then
						if (ui.get(onion_antirecharge_enabled)) then
							ui.set(guiReferences["dt"], true);
							hasShot = false;
							isInside = false;
							insideIndex = nil;
						end
					end
				end

				if (math.sqrt((playerX - locations[i][4][1])^2 + (playerY - locations[i][4][2])^2) <= ui.get(onion_draw_distance) or math.sqrt((playerX - locations[i][3][1])^2 + (playerY - locations[i][3][2])^2) <= ui.get(onion_draw_distance)) then
					trX, trY = renderer.world_to_screen(locations[i][3][1], locations[i][3][2], locations[i][2])
					tlX, tlY = renderer.world_to_screen(locations[i][3][1], locations[i][4][2], locations[i][2])
					blX, blY = renderer.world_to_screen(locations[i][4][1], locations[i][3][2], locations[i][2])
					brX, brY = renderer.world_to_screen(locations[i][4][1], locations[i][4][2], locations[i][2])

					if (ui.get(onion_colors[1]) and ui.get(onion_draw_color_custom)) then
						renderer.triangle(tlX, tlY, brX, brY, blX, blY, ui.get(onion_colors[2]))
						renderer.triangle(tlX, tlY, trX, trY, blX, blY, ui.get(onion_colors[2]))
					else
						renderer.triangle(tlX, tlY, brX, brY, blX, blY, 255, 255, 255, 150)
						renderer.triangle(tlX, tlY, trX, trY, blX, blY, 255, 255, 255, 150)
					end
				end
			end
		end
	else
		for i = 1, #weaponUI do
			for f = 1, #weaponUI[i] do
				ui.set_visible(weaponUI[i][f], false);
			end
		end
	end
end)

client.set_event_callback("weapon_fire", function( info )
	if (client.userid_to_entindex(info.userid) == localPlayer) then
		hasShot = true;
	end
end);