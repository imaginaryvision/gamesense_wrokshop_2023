local js = panorama['open']()
local MyPersonaAPI, LobbyAPI, PartyListAPI, FriendsListAPI, GameStateAPI = js['MyPersonaAPI'], js['LobbyAPI'], js['PartyListAPI'], js['FriendsListAPI'], js['GameStateAPI']
local L = {}

L['Get'] = ui['get']
L['Set'] = ui['set']

L['Delay'] = client['delay_call']
L['RandInt'] = client['random_int']
L['RegisterEvent'] = client['set_event_callback']

L['SetVisible'] = ui['set_visible']
L['SetCallback'] = ui['set_callback']
L['Button'] = ui['new_button']
L['Slider'] = ui['new_slider']
L['Combobox'] = ui['new_combobox']
L['Textbox'] = ui['new_textbox']
L['Checkbox'] = ui['new_checkbox']
L['ListBox'] = ui['new_listbox']
L['Label'] = ui['new_label']

if (not LobbyAPI.IsSessionActive()) then
	LobbyAPI.CreateSession()
	PartyListAPI.SessionCommand('MakeOnline', '')
end

panorama['loadstring']([[
	var waitForSearchingEventHandler = $.RegisterForUnhandledEvent('PanoramaComponent_Lobby_MatchmakingSessionUpdate', function() {});
]])()

local events = panorama['loadstring']([[
	return {
		start: function(callback) {
			waitForSearchingEventHandler = $.RegisterForUnhandledEvent('PanoramaComponent_Lobby_MatchmakingSessionUpdate', callback);
		},
		stop: function() {
			$.UnregisterForUnhandledEvent('PanoramaComponent_Lobby_MatchmakingSessionUpdate', waitForSearchingEventHandler);
		}
	}
]])()

-- jank asf
events.start(panorama['loadstring']([[return function() {}]])())
events.stop()

L['Config'] = {
	['Panel'] = 'LUA',
	['Side'] = 'B'
}

L['Chat'] = {
	['DefaultChatMsg'] = 'i\'m jackin off',
	['ErrorPrefix'] = '#SFUI_QMM_ERROR_',
	['Errors'] = {
		"1_FailPingServer",
		"1_FailReadyUp",
		"1_FailReadyUp_Title",
		"1_FailVerifyClan",
		"1_FailVerifyClan_Title",
		"1_InsufficientLevel",
		"1_InsufficientLevel02",
		"1_InsufficientLevel03",
		"1_InsufficientLevel04",
		"1_InsufficientLevel05",
		"1_NotLoggedIn",
		"1_NotVacVerified",
		"1_OngoingMatch",
		"1_PenaltySeconds",
		"1_PenaltySecondsGreen",
		"1_VacBanned",
		"1_VacBanned_Title",
		"ClientBetaVersionMismatch",
		"ClientUpdateRequired",
		"FailedToPingServers",
		"FailedToReadyUp",
		"FailedToSetupSearchData",
		"FailedToVerifyClan",
		"InvalidGameMode",
		"NoOngoingMatch",
		"NotLoggedIn",
		"NotVacVerified",
		"OperationPassInvalid",
		"OperationQuestIdInactive",
		"PartyRequired1",
		"PartyRequired2",
		"PartyRequired3",
		"PartyRequired4",
		"PartyRequired5",
		"PartyTooLarge",
		"SkillGroupLargeDelta",
		"SkillGroupMissing",
		"TournamentMatchInvalidEvent",
		"TournamentMatchNoEvent",
		"TournamentMatchRequired",
		"TournamentMatchSetupNoTeam",
		"TournamentMatchSetupSameTeam",
		"TournamentMatchSetupYourTeam",
		"TournamentTeamAccounts",
		"TournamentTeamSize",
		"UnavailMapSelect",
		"VacBanned",
		"X_AccountWarningNonPrime",
		"X_AccountWarningTrustMajor",
		"X_AccountWarningTrustMajor_Summary",
		"X_AccountWarningTrustMinor",
		"X_FailPingServer",
		"X_FailReadyUp",
		"X_FailVerifyClan",
		"X_InsecureBlocked",
		"X_InsufficientLevel",
		"X_InsufficientLevel02",
		"X_InsufficientLevel03",
		"X_InsufficientLevel04",
		"X_InsufficientLevel05",
		"X_NotLoggedIn",
		"X_NotVacVerified",
		"X_OngoingMatch",
		"X_PenaltySeconds",
		"X_PenaltySecondsGreen",
		"X_PerfectWorldDenied",
		"X_PerfectWorldRequired",
		"X_VacBanned"
	},
	['QueueErrors'] = {
		'X_VacBanned',
		'X_PenaltySeconds',
		'X_InsecureBlocked',
		'SkillGroupLargeDelta'
	},
	['MessageTypes'] = {
		'Invite',
		'Error',
		'Chat',
		'Start/Stop Queue',
		'Popup Window',
		'Ear Rape [1]',
		'Ear Rape [2]',
		'Mass Popup'
	},
	['Colours'] = {
		'Red',
		'Green',
		'Yellow'
	}
}

L['Data'] = {
	['Targets'] = {
		[0] = '-',
		[1] = '-',
		[2] = '-',
		[3] = '-',
		[4] = '-',
		[5] = '-'
	},
	['BadMessages'] = {
		'Ear Rape [1]',
		'Ear Rape [2]',
		'Mass Popup'
	}
}

L['Funcs'] = {
	['table.HasValue'] = function(tble, value)
		for _, v in ipairs(L['Data']['BadMessages']) do
			if (v == value) then
				return true
			end
		end
	
		return false
	end,
	['arrToStr'] = function()
		local str = '['

		for _, v in pairs(L['Data']['Targets']) do
			str = string.format('%s\'%s\',', str, v)
		end

		return string.format('%s];', str)
	end,
	['GetRandomErrorMessage'] = function()
		return L['Chat']['Errors'][L['RandInt'](1, #L['Chat']['Errors'])]
	end,
	['BuildFuncs'] = function()
		local trustOnSearch = L['Get'](L['UI']['TrustMsgOnSearch']['Element'])
		local errPrefix = L['Chat']['ErrorPrefix']
		local tfArrToStr = L['Funcs']['arrToStr']()
		local autoStopQueue = L['Get'](L['UI']['StopQueue']['Element'])
		local autoStopMsg = L['Get'](L['UI']['StopQueue']['Hidden']['Error']['Element'])
		local autoStopQueueSilent = L['Get'](L['UI']['StopQueue']['Hidden']['Silent']['Element'])
		local target = L['Get'](L['UI']['Target']['Element'])

		events.stop()
		events.start(panorama['loadstring'](string.format([[
			return function() {
				if (LobbyAPI.GetMatchmakingStatusString() == '#SFUI_QMM_State_find_searching') {
					if (%s) {
						let trustFactorData = %s
						let sendTrustMsg = false;

						for (let i = 0; i < trustFactorData.length; i++) {
							let trustOption = trustFactorData[i];
			
							if (trustOption != '-') {
								let userXUID = PartyListAPI.GetXuidByIndex(i);

								if (trustOption === 'Red' || trustOption === 'Yellow') {sendTrustMsg = true;}
				
								let msgType = (trustOption === 'Red') ? 'ChatReportError' : 'ChatReportYellow';
								let msgCol = (trustOption === 'Red') ? "error" : "yellow";
								let trustMessage = (trustOption === 'Red') ? 'X_AccountWarningTrustMajor' : 'X_AccountWarningTrustMinor';
				
								PartyListAPI.SessionCommand(`Game::${msgType}`, `run all xuid ${userXUID} ${msgCol} %s${trustMessage}`);
							}
						}
				
						if (sendTrustMsg) {
							PartyListAPI.SessionCommand('Game::ChatReportError', `run all xuid ${MyPersonaAPI.GetXuid()} error %sX_AccountWarningTrustMajor_Summary `);
						}
					}
	
					if (%s) {
						let target = (LobbyAPI.BIsHost()) ? PartyListAPI.GetXuidByIndex(%s) : MyPersonaAPI.GetXuid();
	
						if (!%s) {
							PartyListAPI.SessionCommand('Game::ChatReportError', `run all xuid ${target} error %s%s`);
						}
	
						LobbyAPI.StopMatchmaking();
					}
				}
			}
		]], tostring(trustOnSearch), tfArrToStr, errPrefix, errPrefix, tostring(autoStopQueue), (target - 1), tostring(autoStopQueueSilent), errPrefix, autoStopMsg				 ) )())
	end,
	['ClearPopups'] = function()
		local element = 'CSGOMainMenu'

		if (GameStateAPI['IsLocalPlayerPlayingMatch']()) then
			element = 'ContextMenuManager'
		end

		panorama['loadstring']('UiToolkitAPI.CloseAllVisiblePopups()', element)()
	end,
	['ExecuteMessage'] = function()
		local baseMsgType = L['UI']['MessageType']
		local msgType = L['Get'](baseMsgType['Element'])
		local msg, other, extra = 'Game::', '', ''
		local target = LobbyAPI.BIsHost() and PartyListAPI.GetXuidByIndex(L['Get'](L['UI']['Target']['Element']) - 1) or MyPersonaAPI.GetXuid()

		if (msgType == 'Chat') then
			msg = string.format('%sChat', msg)
			other = 'chat'
			extra = L['Get'](baseMsgType['Hidden']['Text']):gsub(' ', ' ') -- if we dont replace regular space with invisible character we cant have spaces in msg :^(
		elseif (msgType == 'Error') then
			other = L['Get'](baseMsgType['Hidden']['Colour'])

			if (other == 'Red') then
				msg = string.format('%sChatReportError', msg)
				other = 'error'
			else
				msg = string.format('%sChatReport%s', msg, other)

				other = other:lower()
			end

			extra = string.format('%s%s', extra, L['Chat']['ErrorPrefix'])

			if (L['Get'](baseMsgType['Hidden']['RandErr']['Element'])) then
				extra = string.format('%s%s', extra, L['Funcs']['GetRandomErrorMessage']())
			else
				extra = string.format('%s%s', extra, L['Chat']['Errors'][ L['Get'](baseMsgType['Hidden']['ErrorList']) + 1 ])
			end
		elseif (msgType == 'Invite') then
			msg = string.format('%sChatInviteMessage', msg)
			target = MyPersonaAPI.GetXuid()
			other = 'friend'
			extra = FriendsListAPI.GetXuidByIndex(L['RandInt'](1, FriendsListAPI.GetCount() - 1))
		elseif (msgType == 'Start/Stop Queue') then
			LobbyAPI.StartMatchmaking( '', '', '', '' )
			LobbyAPI.StopMatchmaking()

			return
		elseif (msgType == 'Popup Window') then
			msg = string.format('%sHostEndGamePlayAgain', msg)

			L['Delay'](0.5, function()
				L['Funcs']['ClearPopups']()
			end)
		elseif (msgType == 'Ear Rape [1]') then
			for i = 1, L['Get'](L['UI']['LoopMessages']['Hidden']['Amt']) do
				LobbyAPI.StartMatchmaking( "", "", "", "" )
				LobbyAPI.StopMatchmaking()
			end

			return
		elseif (msgType == 'Ear Rape [2]') then
			for i = 1, L['Get'](L['UI']['LoopMessages']['Hidden']['Amt']) do
				PartyListAPI.SessionCommand('Game::Chat', string.format('run all xuid %s name %s chat ', MyPersonaAPI.GetXuid(), MyPersonaAPI.GetName()))
			end

			return
		else -- must be mass pop up
			for i = 1, L['Get'](L['UI']['LoopMessages']['Hidden']['Amt']) do
				PartyListAPI.SessionCommand('Game::HostEndGamePlayAgain', string.format('run all xuid %s', MyPersonaAPI.GetXuid()))
			end

			L['Delay'](0.5, function()
				L['Funcs']['ClearPopups']()
			end)

			return
		end

		PartyListAPI.SessionCommand(msg, string.format('run all xuid %s %s %s', target, (#other > 1 and ' ' .. other or ''), (#extra > 1 and ' ' .. extra or '')))
	end,
	['HandleMessage'] = function()
		local baseLoop = L['UI']['LoopMessages']['Hidden']
		local msgType = L['Get'](L['UI']['MessageType']['Element'])

		if (L['Get'](L['UI']['LoopMessages']['Element']) and not L['Funcs']['table.HasValue'](L['Data']['BadMessages'], msgType)) then
			for i = 1, L['Get'](baseLoop['Amt']) do
				if (not L['Get'](L['UI']['LoopMessages']['Element'])) then
					break
				end

				L['Funcs']['ExecuteMessage']()
			end

			L['Delay'](L['Get'](baseLoop['Delay']) / 1000, L['Funcs']['HandleMessage'])
		else
			L['Funcs']['ExecuteMessage']()
		end
	end
}

L['UI'] = {
	['lblStart'] = {
		['Element'] = L['Label'](L['Config']['Panel'], L['Config']['Side'], '---------------[Start Lobby Utils]--------------'),
		['Callback'] = function(e) end
	},

	['Target'] = {
		['Element'] = L['Slider'](L['Config']['Panel'], L['Config']['Side'], 'Target Player', 1, 5, 0),
		['Callback'] = function(e)
			L['Set'](L['UI']['TrustMsgOnSearch']['Hidden']['Message']['Element'], L['Data']['Targets'][L['Get'](e) - 1])

			L['Funcs']['BuildFuncs']()
		end
	},

	['TrustMsgOnSearch'] = {
		['Element'] = L['Checkbox'](L['Config']['Panel'], L['Config']['Side'], 'Trust Message on Search'),
		['Hidden'] = {
			['Message'] = {
				['Element'] = L['Combobox'](L['Config']['Panel'], L['Config']['Side'], 'Trust Message', {'-', 'Yellow', 'Red'}),
				['Callback'] = function(e)
					local target = L['Get'](L['UI']['Target']['Element'])

					if (L['Data']['Targets'][target - 1] ~= L['Get'](e)) then
						L['Data']['Targets'][target - 1] = L['Get'](e)
					end

					L['Funcs']['BuildFuncs']()
				end
			}
		},
		['Callback'] = function(e)
			L['SetVisible'](L['UI']['TrustMsgOnSearch']['Hidden']['Message']['Element'], L['Get'](e))

			L['Funcs']['BuildFuncs']()
		end
	},

	['StopQueue'] = {
		['Element'] = L['Checkbox'](L['Config']['Panel'], L['Config']['Side'], 'Auto Stop Queue'),
		['Hidden'] = {
			['Silent'] = {
				['Element'] = L['Checkbox'](L['Config']['Panel'], L['Config']['Side'], 'Silent'),
				['Callback'] = function(e)
					L['SetVisible'](L['UI']['StopQueue']['Hidden']['Error']['Element'], not L['Get'](e))

					L['Funcs']['BuildFuncs']()
				end
			},
			['Error'] = {
				['Element'] = L['Combobox'](L['Config']['Panel'], L['Config']['Side'], 'Queue Error', L['Chat']['QueueErrors']),
				['Callback'] = function(e)
					L['Funcs']['BuildFuncs']()
				end
			}
		},
		['Callback'] = function(e)
			local bool = L['Get'](e)
			local base = L['UI']['StopQueue']['Hidden']

			L['SetVisible'](base['Silent']['Element'], bool)
			L['SetVisible'](base['Error']['Element'], bool)

			L['Funcs']['BuildFuncs']()
		end
	},

	['LoopMessages'] = {
		['Element'] = L['Checkbox'](L['Config']['Panel'], L['Config']['Side'], 'Loop Messages'),
		['Hidden'] = {
			['Delay'] = L['Slider'](L['Config']['Panel'], L['Config']['Side'], 'Spam Delay', 1, 1000, 250, true, 'ms'),
			['Amt'] = L['Slider'](L['Config']['Panel'], L['Config']['Side'], 'Spam Per Loop', 1, 200, 1, true)
		},
		['Callback'] = function(e)
			local bool = L['Get'](e)
			local base = L['UI']['LoopMessages']['Hidden']

			L['SetVisible'](base['Delay'], bool)
			L['SetVisible'](base['Amt'], bool)
		end
	},

	['MessageType'] = {
		['Element'] = L['Combobox'](L['Config']['Panel'], L['Config']['Side'], 'Message Type', L['Chat']['MessageTypes']),
		['Hidden'] = {
			['Text'] = L['Textbox'](L['Config']['Panel'], L['Config']['Side'], 'Message Text'),
			['Colour'] = L['Combobox'](L['Config']['Panel'], L['Config']['Side'], 'Message Colour', L['Chat']['Colours']),
			['RandErr'] = {
				['Element'] = L['Checkbox'](L['Config']['Panel'], L['Config']['Side'], 'Random Error'),
				['Callback'] = function(e) L['SetVisible'](L['UI']['MessageType']['Hidden']['ErrorList'], not L['Get'](e)) L['Funcs']['BuildFuncs']() end
			},
			['ErrorList'] = L['ListBox'](L['Config']['Panel'], L['Config']['Side'], 'Error List', L['Chat']['Errors'])
		},
		['Callback'] = function(e)
			local bool = (L['Get'](e) == 'Error')
			local base = L['UI']['MessageType']['Hidden']

			L['SetVisible'](base['Text'], (L['Get'](e) == 'Chat'))
			L['SetVisible'](base['Colour'], bool)
			L['SetVisible'](base['RandErr']['Element'], bool)

			if (L['Get'](base['RandErr']['Element'])) then
				L['SetVisible'](base['ErrorList'], not L['Get'](base['RandErr']['Element']))
			else
				L['SetVisible'](base['ErrorList'], bool)
			end

			L['Funcs']['BuildFuncs']()
		end
	},

	['Close Windows'] = {
		['Element'] = L['Button'](L['Config']['Panel'], L['Config']['Side'], 'Force Close Windows', function(e) return end),
		['Callback'] = L['Funcs']['ClearPopups']
	},

	['Execute Message'] = {
		['Element'] = L['Button'](L['Config']['Panel'], L['Config']['Side'], 'Execute Message', function(e) return end),
		['Callback'] = L['Funcs']['HandleMessage']
	},

	['lblEnd'] = {
		['Element'] = L['Label'](L['Config']['Panel'], L['Config']['Side'], '---------------[End Lobby Utils]----------------'),
		['Callback'] = function(e) end
	}
}

L['RegisterEvent']('shutdown', function()
	events.stop()
end)

L['Funcs']['BuildFuncs']()

for _, entry in pairs(L['UI']) do
	if (entry['Hidden']) then
		for _, hidden in pairs(entry['Hidden']) do
			if (type(hidden) == 'table') then
				L['SetCallback'](hidden['Element'], hidden['Callback'])
				L['SetVisible'](hidden['Element'], false)
			else
				L['SetVisible'](hidden, false)
			end
		end
	else
		L['SetVisible'](entry['Element'], true)
	end

	L['SetCallback'](entry['Element'], entry['Callback'])
end
