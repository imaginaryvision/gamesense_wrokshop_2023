-- Informant for Counter-Strike: Global Offensive, by nicole

-- Libraries
local csgo_weapons = require "gamesense/csgo_weapons"

-- Game definitions
local COMP_COLOR =
{
	[ -1 ] = "Grey",
	[ 0 ] = "Yellow",
	[ 1 ] = "Purple",
	[ 2 ] = "Green",
	[ 3 ] = "Blue",
	[ 4 ] = "Orange"
}

local TIME_PER_MESSAGE = 0.8

-- Menu
local g_pInformantOptions = ui.new_multiselect("VISUALS", "Other ESP", "Informant", { "Persona", "Competitive color", "Damage dealt", "Weapon", "Current health", "Last known location" });
local g_aLogs = {}
local g_aDamageCache = {}

-- @sapphyrus
function cleanup_last_place_name(name)
	return ((name .. " "):gsub("%u[%l ]", function(c) return " " .. c end):gsub("^%s+", ""):gsub("%s+$", ""))
end

function is_warmup()
	return entity.get_prop(entity.get_game_rules(), "m_bWarmupPeriod") == 1
end

function get_color(ent)
	return entity.get_prop(entity.get_player_resource(), "m_iCompTeammateColor", ent)
end

function get_enemies_from_resource()
	local nMyTeam = entity.get_prop(entity.get_local_player(), "m_iTeamNum")
	local nPlayerResource = entity.get_player_resource()
	local aEnemies = {}

	for i = 0, globals.maxplayers() do
		if entity.get_prop(nPlayerResource, "m_bAlive", i) == 1 and entity.get_prop(nPlayerResource, "m_iTeam", i) ~= nMyTeam then
			table.insert(aEnemies, i)
		end
	end

	return aEnemies
end

function get_health(ent)
	return entity.get_prop(ent, "m_iHealth")
end

function get_weapon_definition_index(ent)
	local nWeapon = entity.get_player_weapon(ent)
	
	if nWeapon ~= nil then
		return entity.get_prop(nWeapon, "m_iItemDefinitionIndex")
	end

	return nil
end

function get_last_location(ent)
	return entity.get_prop(ent, "m_szLastPlaceName") or "Unknown"
end

function is_in_table(tbl, val)
	for i = 1, #tbl do
		if tbl[i] == val then
			return true
		end
	end

	return false
end

function get_informant(ent)
	return
	{
		["Persona"] = entity.get_player_name(ent),
		["Competitive color"] = COMP_COLOR[get_color(ent)],
		["Damage dealt"] = g_aDamageCache[ent] ~= nil and ("-" .. g_aDamageCache[ent] .. " HP") or nil,
		["Weapon"] = "Holding the " .. csgo_weapons[get_weapon_definition_index(ent)].name,
		["Current health"] = "Currently has " .. get_health(ent) .. " HP",
		["Last known location"] = "Last seen @ " .. cleanup_last_place_name(get_last_location(ent))
	}
end

function push_to_log(ent)
	local aOptions = ui.get(g_pInformantOptions)
	local aInformant = get_informant(ent)
	local aRealInfo = {}

	for sKey, sData in pairs(aInformant) do
		if sData ~= nil and is_in_table(aOptions, sKey) then
			table.insert(aRealInfo, sData)
		end
	end

	if #aRealInfo > 0 then
		table.insert(g_aLogs, table.concat(aRealInfo, " | "))
	end
end

function on_player_death(e)
	local nLocalPlayer = entity.get_local_player()
	
	if is_warmup() or client.userid_to_entindex(e.userid) ~= nLocalPlayer or e.attacker == e.userid or e.attacker == 0 then
		return
	end

	-- Also log the player who just killed us
	local nAttacker = client.userid_to_entindex(e.attacker)

	if nAttacker ~= nil and g_aDamageCache[nAttacker] == nil then
		push_to_log(nAttacker)
	end

	-- HACK: I can't see a function to check if an entity index is present in the game without throwing an error. Therefore, I do this.
	local aEnemies = get_enemies_from_resource()

	for nEnemy, nDamage in pairs(g_aDamageCache) do
		if is_in_table(aEnemies, nEnemy) then
			push_to_log(nEnemy)
		end
	end

	for i = 1, #g_aLogs do
		client.delay_call(i * TIME_PER_MESSAGE, client.exec, "say_team ", g_aLogs[i] )
	end
end

function on_player_spawn(e)
	local nLocalPlayer = entity.get_local_player()
	
	if client.userid_to_entindex(e.userid) ~= nLocalPlayer then
		return
	end

	-- Empty memory when we spawn
	g_aLogs = {}
	g_aDamageCache = {}
end

function on_player_hurt(e)
	local nLocalPlayer = entity.get_local_player()
	
	if client.userid_to_entindex(e.attacker) ~= nLocalPlayer then
		return
	end

	local nEnemyID = client.userid_to_entindex(e.userid)
	local nCachedDamage = g_aDamageCache[nEnemyID]

	if nCachedDamage == nil then
		nCachedDamage = 0
	end

	g_aDamageCache[nEnemyID] = nCachedDamage + e.dmg_health
end

function on_informant_ui_callback()
	local pFunc = #(ui.get(g_pInformantOptions)) > 0 and client.set_event_callback or client.unset_event_callback
	pFunc("player_death", on_player_death)
	pFunc("player_spawn", on_player_spawn)
	pFunc("player_hurt", on_player_hurt)
end

ui.set_callback(g_pInformantOptions, on_informant_ui_callback)
on_informant_ui_callback()