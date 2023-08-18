local MusicKitArray = {
	[1] = 'Default',

	[3] = 'Crimson Assault',
	[4] = 'Sharpened',
	[5] = 'Insurgency',
	[6] = 'A*D*8',
	[7] = 'High Noon',
	[8] = 'Death\'s Head Demolition',
	[9] = 'Desert Fire',

	[10] = 'LNOE',
	[11] = 'Metal',
	[12] = 'All I Want for Christmas',
	[13] = 'IsoRhythm',
	[14] = 'For No Mankind',
	[15] = 'Hotline Miami',
	[16] = 'Total Domination',
	[17] = 'The Talos Principle',
	[18] = 'Battlepack',
	[19] = 'MOLOTOV',

	[20] = 'Uber Blasto Phone',
	[21] = 'Hazardous Environments',
	[22] = 'Headshot',
	[23] = 'The 8-Bit Kit',
	[24] = 'I Am',
	[25] = 'Diamonds',
	[26] = 'Invasion!',
	[27] = 'Lion\'s Mouth',
	[28] = 'Sponge Fingerz',
	[29] = 'Disgusting',
	[30] = 'Java Havana Funkaloo',

	[31] = 'Moments CSGO',
	[32] = 'Aggressive',
	[33] = 'The Good Youth',
	[34] = 'FREE',
	[35] = 'Life\'s Not Out To Get You',
	[36] = 'Backbone',
	[37] = 'GLA',
	[38] = 'III-Arena',
	[39] = 'EZ4ENCE',
	[40] = 'The Master Chief Collection',

	[41] = 'Scar',
	[42] = 'Anti Citizen',
	[43] = 'Bachram',
	[44] = 'Gunman Taco Truck',
	[45] = 'Eye of the Dragon',
	[46] = 'M.U.D.D. FORCE',
	[47] = 'Neo Noir',
	[48] = 'Bodacious',
	[49] = 'Drifter',
	[50] = 'All for Dust',

	[51] = 'Hades Music Kit',
	[52] = 'The Lowlife Pack',
	[53] = 'CHAIN$AW.LXADXUT.',

	[54] = 'Mocha Petal',
	[55] = '~Yellow Magic~',
	[56] = 'Vici',
	[57] = 'Astro Bellum',
	[58] = 'Work Hard, Play Hard',
	[59] = 'KOLIBRI',
	[60] = 'u mad!',
	[61] = 'Flashbang Dance',

	[62] = 'Heading for the Source',
	[63] = 'Void',
	[64] = 'Shooters',
	[65] = 'dashstar*',
	[66] = 'Gothic Luxury',
	[67] = 'Lock Me Up',

	[68] = '花脸 Hua Lian (Painted Face)',

    [69] = 'ULTIMATE',
}

ui.new_label('LUA', 'B', 'Music Kits')
local listMusicKit = ui.new_listbox('LUA', 'B', 'Music Kits', MusicKitArray)

local changeKits = function()
	if (entity.get_local_player() ~= nil) then
		local me = entity.get_local_player()
		local musicKit = ui.get(listMusicKit)
		local id = ((musicKit == 0) and 1 or musicKit + 2)

		if (entity.get_prop(entity.get_player_resource(), 'm_nMusicID', me) ~= id) then
			entity.set_prop(entity.get_player_resource(), 'm_nMusicID', id, me)
		end
	end
end

ui.set_callback(listMusicKit, changeKits)
client.set_event_callback('round_start', changeKits)