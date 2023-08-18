local panorama_events = require "gamesense/panorama_events"
local steamworks = require "gamesense/steamworks"
local ffi = require "ffi"

-- Constants
local CONFIG_KEY = "serverbrowser_config"
local APP_ID = 730 -- CS:GO
local EVENTS = {
	Refresh = "ServerBrowser_Refresh",
	StopRefresh = "ServerBrowser_StopRefresh",
	QuickRefresh = "ServerBrowser_QuickRefresh",
	Connect = "ServerBrowser_Connect",
	ConnectWithPassword = "ServerBrowser_ConnectWithPassword",
	RequestFilters = "ServerBrowser_RequestFilters",
	SaveFilters = "ServerBrowser_SaveFilters",
	UpdateTagFilter = "ServerBrowser_UpdateTagFilter",
	AddToFavorites = "ServerBrowser_AddToFavorites",
	RemoveFromFavorites = "ServerBrowser_RemoveFromFavorites",
	AddToHistory = "ServerBrowser_AddToHistory",
	RemoveFromHistory = "ServerBrowser_RemoveFromHistory",
	RequestPlayerList = "ServerBrowser_RequestPlayerList"
}

local k_unFavoriteFlagNone = 0
local k_unFavoriteFlagFavorite = 1
local k_unFavoriteFlagHistory = 2

local ISteamMatchmakingServers = steamworks.ISteamMatchmakingServers
local ISteamMatchmaking = steamworks.ISteamMatchmaking
local concmdConnect = cvar.connect
local cvarPassword = cvar.password

local config = {
	filters = {{}, {}, {}, {}, {}, {}}
}
local function saveConfig()
	database.write(CONFIG_KEY, config)
end
local function loadConfig()
	local _config = database.read(CONFIG_KEY)
	if _config == nil then
		-- save default cfg to database
		saveConfig()
	else
		config = _config
	end
end
loadConfig()

local js =
	panorama.loadstring(
	[[const IMG_BASE = 'https://relative.im/img'

const SIDE_LAYOUT = `<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/mainmenu.css" />
		<include src="file://{resources}/styles/mainmenu_play.css" />
	</styles>
	<Panel class="top-bottom-flow map-selection-list__quick-selection-sets">
		<Label text="Community Servers" class="map-selection__quick-selection-set-title" />
		<Panel id="serverbrowser-tabs" class="map-selection-list__quick-selection-sets__btns">
			<Button id="internet" class="map-selection__quick-selection-set horizontal-align-left preset-button">
				<Label text="Internet (0)" />
			</Button>
			<Button id="favorites" class="map-selection__quick-selection-set horizontal-align-left preset-button">
				<Label text="Favorites (0)" />
			</Button>
			<Button id="history" class="map-selection__quick-selection-set horizontal-align-left preset-button">
				<Label text="History (0)" />
			</Button>
			<Button id="spectate" class="map-selection__quick-selection-set horizontal-align-left preset-button">
				<Label text="Spectate (0)" />
			</Button>
			<Button id="lan" class="map-selection__quick-selection-set horizontal-align-left preset-button">
				<Label text="LAN (0)" />
			</Button>
			<Button id="friends" class="map-selection__quick-selection-set horizontal-align-left preset-button">
				<Label text="Friends (0)" />
			</Button>
		</Panel>
		<Label text="Actions" class="map-selection__quick-selection-set-title" />
		<Panel id="serverbrowser-actions" class="map-selection-list__quick-selection-sets__btns">
			<Button id="EditFilters" class="map-selection__quick-selection-set-icon save preset-button">
				<Image texturewidth="24" textureheight="24" src="file://{images}/icons/ui/edit.svg"/>
				<Label text="Edit Filters"/>
			</Button>

			<Button id="OpenOldBrowser" class="map-selection__quick-selection-set-icon save preset-button">
				<Image texturewidth="24" textureheight="24" src="file://{images}/icons/ui/link.svg"/>
				<Label text="Open Old Browser"/>
			</Button>
		</Panel>
	</Panel>
</root>`

const MAIN_LAYOUT = `<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/mainmenu.css" />
		<include src="file://{resources}/styles/mainmenu_play.css" />
		<include src="file://{resources}/styles/matchinfo.css" />
		<include src="file://{resources}/styles/matchinfo_scoreboard.css" />
		<include src="file://{resources}/styles/context_menus/context_menu_base.css" />
	</styles>
	<snippets>
		<snippet name="serverbrowser_server">
			<Panel class="left-right-flow full-width sb-row evenrow" style="margin: 0 0 3px;padding: 4px 0;">
				<Panel style="width:25px;margin-left: 6px;">
					<Image id="password" src="file://{images}/icons/ui/locked.svg" texturewidth="20px" scaling="none" />
				</Panel>
				<Panel style="width:25px;margin-left: 4px;">
					<Image id="vac" src="${IMG_BASE}/vac.svg" texturewidth="20px" scaling="none" />
				</Panel>
				<Label id="name" style="width: 1100px;margin-left: 4px;text-overflow:ellipsis;white-space:nowrap;" />
				<Label id="players" style="width:100px;" />
				<Label id="map" style="width:150px;text-overflow:ellipsis;white-space:nowrap;"/>
				<Label id="ping" style="width:100px;"/>
			</Panel>
		</snippet>
	</snippets>
	<Panel class="top-bottom-flow full-width full-height" style="margin:0px;padding:0px;margin-top:0px;">
		<Panel class="left-right-flow full-width sb-row no-hover oddrow" style="padding-top:5px;padding-bottom:5px;margin-right:2px;">
			<TooltipPanel id="password" style="width:25px;margin-left: 6px;" tooltip="Server requires password">
				<Image src="file://{images}/icons/ui/locked.svg" texturewidth="20px" scaling="none" />
			</TooltipPanel>
			<TooltipPanel id="vac" style="width:25px;margin-left: 4px;" tooltip="Server has Valve Anti-Cheat (VAC) enabled">
				<Image src="${IMG_BASE}/vac.svg" texturewidth="20px" scaling="none"/>
			</TooltipPanel>
			<Panel class="left-right-flow round-selection-button" style="width:1100px;margin-left: 4px;">
				<Label id="head-name" class="fontWeight-Bold" text="Name"/>
				<Image id="sort-name" src="file://{images}/icons/ui/expand.svg" texturewidth="16px" scaling="none" style="margin-left:4px;"/>
			</Panel>
			<Panel class="left-right-flow round-selection-button" style="width:100px;">
				<Label id="head-players" class="fontWeight-Bold" text="Players"/>
				<Image id="sort-players" src="file://{images}/icons/ui/expand.svg" texturewidth="16px" scaling="none" style="margin-left:4px;" />
			</Panel>
			<Panel class="left-right-flow round-selection-button" style="width:150px;">
				<Label id="head-map" class="fontWeight-Bold" text="Map"/>
				<Image id="sort-map" src="file://{images}/icons/ui/expand.svg" texturewidth="16px" scaling="none" style="margin-left:4px;" />
			</Panel>
			<Panel class="left-right-flow round-selection-button" style="width:100px;">
				<Label id="head-ping" class="fontWeight-Bold" text="Ping"/>
				<Image id="sort-ping" src="file://{images}/icons/ui/expand.svg" texturewidth="16px" scaling="none" style="margin-left:4px;" />
			</Panel>
		</Panel>
		<Panel id="serverbrowser-servers-internet" class="top-bottom-flow full-width vscroll">
		</Panel>
		<Panel id="serverbrowser-servers-favorites" class="top-bottom-flow full-width vscroll">
		</Panel>
		<Panel id="serverbrowser-servers-history" class="top-bottom-flow full-width vscroll">
		</Panel>
		<Panel id="serverbrowser-servers-spectate" class="top-bottom-flow full-width vscroll">
		</Panel>
		<Panel id="serverbrowser-servers-lan" class="top-bottom-flow full-width vscroll">
		</Panel>
		<Panel id="serverbrowser-servers-friends" class="top-bottom-flow full-width vscroll">
		</Panel>
	</Panel>
</root>`

const BTNS_LAYOUT = `<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/mainmenu.css" />
		<include src="file://{resources}/styles/mainmenu_play.css" />
		<include src="file://{resources}/styles/stats/playerstats.css" />
	</styles>
	<Panel class="left-right-flow">
		<Button id="QuickRefresh" class="content-navbar__manage-btn" style="height:46px;margin-right:12px;">
			<Label id="QuickRefreshText" text="QUICK REFRESH"/>
		</Button>
		<Button id="Refresh" class="content-navbar__manage-btn" style="height:46px;margin-right:12px;">
			<Panel id="RefreshSpinner" style="margin-right: 14px;" class="Spinner"/>
			<Label id="RefreshText" text="STOP REFRESH"/>
		</Button>
		<Button id="Connect" class="content-navbar__manage-btn" style="height:46px;">
			<Label id="ConnectText" text="CONNECT"/>
		</Button>
	</Panel>
</root>`

const TAGS_LAYOUT = `<root>
	<styles>
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/mainmenu.css" />
		<include src="file://{resources}/styles/mainmenu_play.css" />
	</styles>
	<Panel class="left-right-flow content-navbar__tabs" style="width: 100%;">
		<TextEntry id="TagFilter" class="workshop-search-textentry" placeholder="Search for tags" />
		<Panel id="FocusStealer" acceptsfocus="true"/>
	</Panel>
</root>`

const FWFH_LAYOUT = `<root>
	<styles>
	</styles>
	<Panel style="position: 0px 0px 0px;width:100%;height:100%;">
		<Button id="FWFHButton" style="width:100%;height:100%;"/>
	</Panel>
</root>`

const POPUP_FILTERS_LAYOUT = `<root>
	<styles>
		<include src="file://{resources}/styles/gamestyles.css" />
		<include src="file://{resources}/styles/popups/popups_shared.css" />
		<include src="file://{resources}/styles/popups/popup_play_gamemodeflags.css" />
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/settings/settings.css" />
		<include src="file://{resources}/styles/settings/settings_slider.css" />
	</styles>

	<script>
		const filterSchema = {
			notFull: ['ServerNotFull', 'check'],
			notEmpty: ['ServerNotEmpty', 'check'],
			notPasswordProtected: ['NotPasswordProtected', 'check'],
			latency: ['Latency', 'drop'],
			location: ['Location', 'drop'],
			anticheat: ['AntiCheat', 'drop'],
			map: ['Map', 'text']
		}

		function _Return(bProceed) {
			const cpnl = $.GetContextPanel()
			let callbackHandle = cpnl.GetAttributeInt('callback', -1);
			let cancelCallbackHandle = cpnl.GetAttributeInt('cancelcallback', -1);
			let callback = bProceed ? callbackHandle : cancelCallbackHandle;
			if (callbackHandle !== -1) {
				let options = {}
				for (let k in filterSchema) {
					const [id, type] = filterSchema[k]
					const el = cpnl.FindChildTraverse(id)
					let v
					switch (type) {
						case 'check':
							v = el.IsSelected()
							break;
						case 'drop':
							v = el.GetSelected().id
							break;
						case 'text':
							v = el.text
							break;
					}
					options[k] = v
				}
				UiToolkitAPI.InvokeJSCallback(callback, options);
			}

			if ( callbackHandle !== -1 )
				UiToolkitAPI.UnregisterJSCallback(callbackHandle);
			if ( cancelCallbackHandle !== -1 )
				UiToolkitAPI.UnregisterJSCallback(cancelCallbackHandle);

			$.DispatchEvent('UIPopupButtonClicked', '');
		}
		function SetupPopup() {
			const cpnl = $.GetContextPanel()
			for (let k in filterSchema) {
				const [id, type] = filterSchema[k]
				const el = cpnl.FindChildTraverse(id)
				const attrStr = cpnl.GetAttributeString(k, '')
				if (attrStr !== '') {
					switch (type) {
						case 'check':
							el.SetSelected(attrStr[0] === 't')
							break;
						case 'drop':
							el.SetSelected(attrStr)
							break;
						case 'text':
							el.text = attrStr
							break;
					}
				}
			}
			
		}
		function CancelPopup() {
			_Return(false);
		}
		function OnOKPressed() {
			_Return(true);
		}
	</script>

	<PopupCustomLayout class="PopupPanel" popupbackground="dim" onload="SetupPopup()" oncancel="CancelPopup()">
		<Label class="PopupTitle" text="Edit Filters" />

		<Panel class="radio-options-container">
			<Panel style="horizontal-align: left; margin-bottom: 10px;">
				<ToggleButton id="ServerNotFull" class="PopupButton Row" >
					<Label id="" text="Server not full" />
				</ToggleButton>
			</Panel>
			<Panel style="horizontal-align: left; margin-bottom: 10px;">
				<ToggleButton id="ServerNotEmpty" class="PopupButton Row" >
					<Label id="" text="Has users playing" />
				</ToggleButton>
			</Panel>
			<Panel style="horizontal-align: left; margin-bottom: 10px;">
				<ToggleButton id="NotPasswordProtected" class="PopupButton Row" >
					<Label text="Is not password protected" />
				</ToggleButton>
			</Panel>
			<Panel class="PopupButton Row" style="horizontal-align: left; margin-bottom: 10px;">
				<Label text="Latency"/>
				<DropDown class="PopupButton" id="Latency" menuclass="DropDownMenu Width-300">
					<Label text="&lt; All &gt;" id="LatencyAll" value="0"/>
					<Label text="&lt; 50" id="Latency50" value="50"/>
					<Label text="&lt; 100" id="Latency100" value="100"/>
					<Label text="&lt; 150" id="Latency150" value="150"/>
					<Label text="&lt; 250" id="Latency250" value="250"/>
					<Label text="&lt; 350" id="Latency350" value="350"/>
					<Label text="&lt; 600" id="Latency600" value="600"/>
				</DropDown>
			</Panel>
			<Panel class="PopupButton Row" style="horizontal-align: left; margin-bottom: 10px;">
				<Label text="Location"/>
				<DropDown class="PopupButton" id="Location" menuclass="DropDownMenu Width-300">
					<Label text="&lt; All &gt;" id="LocationAll" value="0"/>
					<Label text="US - East" id="LocationUSE" value="1"/>
					<Label text="US - West" id="LocationUSW" value="2"/>
					<Label text="South America" id="LocationSA" value="3"/>
					<Label text="Europe" id="LocationEU" value="4"/>
					<Label text="Asia" id="LocationAS" value="5"/>
					<Label text="Australia" id="LocationAU" value="6"/>
					<Label text="Middle East" id="LocationME" value="7"/>
					<Label text="Africa" id="LocationAF" value="8"/>
				</DropDown>
			</Panel>
			<Panel class="PopupButton Row" style="horizontal-align: left; margin-bottom: 10px;">
				<Label text="Anti cheat"/>
				<DropDown class="PopupButton" id="AntiCheat" menuclass="DropDownMenu Width-300">
					<Label text="&lt; All &gt;" id="AntiCheatAll" value="0"/>
					<Label text="Secure" id="AntiCheatSecure" value="1"/>
					<Label text="Not secure" id="AntiCheatInsecure" value="2"/>
				</DropDown>
			</Panel>
			<Panel class="PopupButton Row" style="horizontal-align: left; margin-bottom: 10px;">
				<Label text="Map"/>
				<TextEntry class="PopupButton" maxchars="32" id="Map" style="width: 300px;" />
			</Panel>
		</Panel>

		<Panel class="PopupButtonRow">
			<TextButton class="PopupButton" text="#OK" onactivate="OnOKPressed()" />
			<TextButton class="PopupButton" text="#Cancel_Button" onactivate="CancelPopup()" />
		</Panel>
	</PopupCustomLayout>
</root>`

const POPUP_SERVER_LAYOUT = `<root>
	<styles>
		<include src="file://{resources}/styles/gamestyles.css" />
		<include src="file://{resources}/styles/popups/popups_shared.css" />
		<include src="file://{resources}/styles/popups/popup_play_gamemodeflags.css" />
		<include src="file://{resources}/styles/csgostyles.css" />
		<include src="file://{resources}/styles/settings/settings.css" />
		<include src="file://{resources}/styles/settings/settings_slider.css" />
	</styles>
	<scripts>
		<include src="file://{resources}/scripts/common/formattext.js" />
	</scripts>

	<script>
		let server = {}
		let dataCallback = -1
		function InvokeCallback(...args) {
			let callback = $.GetContextPanel().GetAttributeInt('callback', -1)
			if (callback !== -1) {
				UiToolkitAPI.InvokeJSCallback(callback, ...args);
			}
			return callback;
		}
		function _Return(szType) {
			let callback = InvokeCallback(szType);
			if (callback !== -1) {
				UiToolkitAPI.UnregisterJSCallback(callback);
			}
			UiToolkitAPI.UnregisterJSCallback(dataCallback);

			UiToolkitAPI.HideTextTooltip();
			$.DispatchEvent('UIPopupButtonClicked', '');
		}

		function _ClearPlayerList() {
			$.GetContextPanel().FindChildTraverse('PlayerList').Children().forEach(ch => {
				ch.DeleteAsync(0.0);
			})
		}
		function _PlayerAdded(ply) {
			let el = $.CreatePanel(
				'Panel',
				$.GetContextPanel().FindChildTraverse('PlayerList'),
				''
			);
			el.BLoadLayoutSnippet('serverbrowser_player')
			el.FindChildTraverse('Name').text = ply.name
			el.FindChildTraverse('Score').text = ply.score
			el.FindChildTraverse('Time').text = FormatText.SecondsToSignificantTimeString(ply.timePlayed)
		}

		function _UpdateData(type, data) {
			switch (type) {
				case 'clearPlayerList':
					_ClearPlayerList();
					break
				case 'playerAdded':
					_PlayerAdded(data);
					break;
				case 'playerRefreshStatus':
					break;
			}
		}
		function SetupPopup() {
			let parameters = [
				'appId',
				'botPlayers',
				'doNotRefresh',
				'gameDesc',
				'gameDir',
				'gameTags',
				'i',
				'ip',
				'ipPort',
				'map',
				'maxPlayers',
				'password',
				'ping',
				'players',
				'port',
				'queryPort',
				'secure',
				'serverName',
				'serverVersion',
				'successful',
				'timeLastPlayed',
				'type',
			];
			for (let p of parameters) {
				server[p] = $.GetContextPanel().GetAttributeString(p, '?')
			}
			dataCallback = UiToolkitAPI.RegisterJSCallback(_UpdateData);
			_UpdateWithServer(server)
			InvokeCallback('players', dataCallback)
		}
		function _UpdateWithServer(server) {
			$.GetContextPanel().SetDialogVariable('name', server.serverName)
			$.GetContextPanel().SetDialogVariable('game', server.gameDesc)
			$.GetContextPanel().SetDialogVariable('map', server.map)
			$.GetContextPanel().SetDialogVariable('players', server.players + ' / ' + server.maxPlayers)
			$.GetContextPanel().SetDialogVariable('vac', server.secure === 'true' ? 'Secure' : 'Not secure')
			$.GetContextPanel().SetDialogVariable('ping', server.ping)
		}
		function CancelPopup() {
			_Return(false);
		}
		function OnCopyPressed() {
			SteamOverlayAPI.CopyTextToClipboard(server.ipPort)
			UiToolkitAPI.HideTextTooltip();
			UiToolkitAPI.ShowTextTooltipOnPanel($.GetContextPanel().FindChildTraverse('CopyButton'), 'Copied to clipboard');
		}
		function OnConnectPressed() {
			_Return('connect')
		}
	</script>
	
	<snippets>
		<snippet name="serverbrowser_player">
			<Panel class="left-right-flow full-width">
				<Label id="Name" text="?" style="width:235px;"/>
				<Label id="Score" text="?" style="width:70px;"/>
				<Label id="Time" text="?" style="width:200px;"/>
			</Panel>
		</snippet>
	</snippets>

	<PopupCustomLayout class="PopupPanel" popupbackground="dim" onload="SetupPopup()" oncancel="CancelPopup()">
		<Label class="PopupTitle" text="{s:name}" />

		<Panel class="left-right-flow" style="margin: 16px;width: 100%;">
			<Panel class="top-bottom-flow" style="width:35%;">
				<Label class="fontWeight-Bold text-align-right" text="Game" />
				<Label class="fontWeight-Bold text-align-right" text="Map" />
				<Label class="fontWeight-Bold text-align-right" text="Players" />
				<Label class="fontWeight-Bold text-align-right" text="Valve Anti-Cheat" />
				<Label class="fontWeight-Bold text-align-right" text="Latency" />
			</Panel>
			<Panel class="top-bottom-flow" style="horizontal-align: left;width:65%;">
				<Label text="{s:game}" />
				<Label text="{s:map}" />
				<Label text="{s:players}" />
				<Label text="{s:vac}" />
				<Label text="{s:ping}" />
			</Panel>
		</Panel>
		
		<Panel class="radio-options-container" style="margin-right: 16px;">
			<Panel class="left-right-flow full-width">
				<Label id="head-name" class="fontWeight-Bold" text="Player name" style="width:235px;"/>
				<Label id="head-score" class="fontWeight-Bold" text="Score" style="width:70px;"/>
				<Label id="head-time" class="fontWeight-Bold" text="Time" style="width:200px;"/>
			</Panel>
			<Panel id="PlayerList" class="top-bottom-flow full-width vscroll" style="max-height: 400px;">

			</Panel>
			
		</Panel>

		<Panel class="PopupButtonRow">
			<TextButton class="PopupButton" text="#GameUI_Close" onactivate="CancelPopup()" />
			<TextButton id="CopyButton" class="PopupButton" text="Copy IP" onactivate="OnCopyPressed()" onmouseout="UiToolkitAPI.HideTextTooltip()" />
			<TextButton class="PopupButton positiveColor" text="Connect" onactivate="OnConnectPressed()" style="border: 1px solid rgba(191, 191, 191, 0.3);" />
		</Panel>
	</PopupCustomLayout>
</root>`

const destroyAllPanels = (ch) => ch.DeleteAsync(0)
const hideAllPanels = (ch) => (ch.visible = false)
const hidePanels =
	(others = false) =>
	(ch) => {
		let ourPanel = (ch.id || '').startsWith('serverbrowser-')
		ch.visible = others ? ourPanel : !ourPanel
	}

const latencyIdToThreshold = (lat) => {
	let num = parseInt(lat.substring(7)) // 7 = 'Latency'.length
	if (!isNaN(num)) {
		return num
	}
	return 999999999999
}

const Types = {
	0: 'Internet',
	1: 'Favorites',
	2: 'History',
	3: 'Spectate',
	4: 'Lan',
	5: 'Friends',
	internet: 0,
	favorites: 1,
	history: 2,
	spectate: 3,
	lan: 4,
	friends: 5,
}

const hooks = []

hooks.new = (obj, name, callback) => {
	let hook = {
		destroyed: false,
		obj,
		name,
		original: obj[name],
		destroy() {
			if (this.destroyed) return true
			obj[name] = this.original
			this.destroyed = true
			return this.destroyed
		},
	}
	hook.original = obj[name]

	obj[name] = function () {
		// just in case theres a reference stored somewhere to this function
		if (hook.destroyed) return hook.original.apply(this, arguments)
		let thiz = this
		return callback.apply(
			{ hook, this: thiz, orig: hook.original.bind(thiz) },
			arguments
		)
	}

	hooks.push(hook)
	return hook
}

hooks.destroy = () => {
	hooks.forEach((hook) => !hook.destroyed && hook.destroy())
	return true
}

const ipToString = (num) =>
	[
		(num >> (8 * 3)) & 0xff,
		(num >> (8 * 2)) & 0xff,
		(num >> (8 * 1)) & 0xff,
		(num >> (8 * 0)) & 0xff,
	].join('.')

const Lua = {
	Events: {
		Refresh: 'ServerBrowser_Refresh',
		StopRefresh: 'ServerBrowser_StopRefresh',
		QuickRefresh: 'ServerBrowser_QuickRefresh',
		Connect: 'ServerBrowser_Connect',
		ConnectWithPassword: 'ServerBrowser_ConnectWithPassword',
		RequestFilters: 'ServerBrowser_RequestFilters',
		SaveFilters: 'ServerBrowser_SaveFilters',
		UpdateTagFilter: 'ServerBrowser_UpdateTagFilter',
		AddToFavorites: 'ServerBrowser_AddToFavorites',
		RemoveFromFavorites: 'ServerBrowser_RemoveFromFavorites',
		AddToHistory: 'ServerBrowser_AddToHistory',
		RemoveFromHistory: 'ServerBrowser_RemoveFromHistory',
		RequestPlayerList: 'ServerBrowser_RequestPlayerList',
	},
	init() {
		$.DefineEvent(Lua.Events.Refresh, 1, '', '')
		$.DefineEvent(Lua.Events.StopRefresh, 1, '', '')
		$.DefineEvent(Lua.Events.QuickRefresh, 2, '', '')
		$.DefineEvent(Lua.Events.Connect, 2, '', '')
		$.DefineEvent(Lua.Events.ConnectWithPassword, 3, '', '')
		$.DefineEvent(Lua.Events.RequestFilters, 1, '', '')
		$.DefineEvent(Lua.Events.SaveFilters, 2, '', '')
		$.DefineEvent(Lua.Events.UpdateTagFilter, 2, '', '')
		$.DefineEvent(Lua.Events.AddToFavorites, 4, '', '')
		$.DefineEvent(Lua.Events.RemoveFromFavorites, 4, '', '')
		$.DefineEvent(Lua.Events.AddToHistory, 4, '', '')
		$.DefineEvent(Lua.Events.RemoveFromHistory, 4, '', '')
		$.DefineEvent(Lua.Events.RequestPlayerList, 3, '', '')
	},
	refresh(type) {
		$.DispatchEvent(Lua.Events.Refresh, type)
	},
	stopRefresh(type) {
		$.DispatchEvent(Lua.Events.StopRefresh, type)
	},
	quickRefresh(type, server) {
		$.DispatchEvent(Lua.Events.QuickRefresh, type, server)
	},
	connect(ip, port) {
		$.DispatchEvent(Lua.Events.Connect, ip, port)
	},
	connectWithPassword(ip, port, password) {
		$.DispatchEvent(Lua.Events.ConnectWithPassword, ip, port, password)
	},
	requestFilters(type) {
		$.DispatchEvent(Lua.Events.RequestFilters, type)
	},
	saveFilters(type, filters) {
		$.DispatchEvent(Lua.Events.SaveFilters, type, JSON.stringify(filters))
	},
	updateTagFilter(type, tags) {
		$.DispatchEvent(Lua.Events.UpdateTagFilter, type, tags)
	},
	addToFavorites(appId, ip, port, queryPort) {
		$.DispatchEvent(Lua.Events.AddToFavorites, appId, ip, port, queryPort)
	},
	removeFromFavorites(appId, ip, port, queryPort) {
		$.DispatchEvent(Lua.Events.RemoveFromFavorites, appId, ip, port, queryPort)
	},
	addToHistory(appId, ip, port, queryPort) {
		$.DispatchEvent(Lua.Events.AddToHistory, appId, ip, port, queryPort)
	},
	removeFromHistory(appId, ip, port, queryPort) {
		$.DispatchEvent(Lua.Events.RemoveFromHistory, appId, ip, port, queryPort)
	},
	requestPlayerList(uid, ip, port) {
		$.DispatchEvent(Lua.Events.RequestPlayerList, uid, ip, port)
	},
}

const browser = {
	initialized: false,
	isOpen: false,

	tabs: ['internet', 'favorites', 'history', 'spectate', 'lan', 'friends'],
	selectedTab: 'internet',
	selectedType: 0,

	panelMain: null,
	panelSide: null,
	panelBtns: null,
	panelTags: null,
	panelFWFH: null,
	panelMainId: 'serverbrowser-main',
	panelSideId: 'serverbrowser-side',
	panelBtnsId: 'serverbrowser-btns',
	panelTagsId: 'serverbrowser-tags',
	panelFWFHId: 'serverbrowser-fwfh',
	panelIds: [
		'serverbrowser-main',
		'serverbrowser-side',
		'serverbrowser-btns',
		'serverbrowser-tags',
		'serverbrowser-fwfh',
	],
	playTopNavDropdown: null,
	doneWithFrame: true,

	panelServerLists: [],
	refreshing: [false, false, false, false, false, false],
	// prettier-ignore
	serverLists: [ [], [], [], [], [], [] ],
	filters: [{}, {}, {}, {}, {}, {}],
	selectedServer: ['', '', '', '', '', ''],

	playerCallbacks: {},

	lastSelectedItem: '',

	urlEncode(obj) {
		return Object.entries(obj)
			.map((i) => i.map(encodeURIComponent).join('='))
			.join('&')
	},

	// init/destroy
	fetchDependencyPanels() {
		let contextPanel = $.GetContextPanel()
		this.panelIds.forEach((panelId) => {
			let panel = contextPanel.FindChildTraverse(panelId)
			if (panel) panel.DeleteAsync(0)
		})

		this.JsQuickSelectParent = contextPanel.FindChildTraverse(
			'JsQuickSelectParent'
		)
		this.MapSelectionList = contextPanel.FindChildTraverse('MapSelectionList')
		if (!this.JsQuickSelectParent || !this.MapSelectionList) return false

		this.playTopNavDropdown =
			contextPanel.FindChildTraverse('PlayTopNavDropdown')
		if (!this.playTopNavDropdown) return false

		// settings-container content-navbar__tabs--small
		this.settingsContainer = contextPanel
			.FindChildTraverse('JsDirectChallengeBtn')
			.GetParent()
			.GetParent()
		if (!this.settingsContainer) return false

		this.workshopSearchBar = contextPanel.FindChildTraverse('WorkshopSearchBar')
		if (!this.workshopSearchBar) return false

		// apparently there are 3 different elements with id "GameModeSelectionRadios"
		this.gameModeSelectionRadios = this.workshopSearchBar
			.GetParent()
			.FindChild('GameModeSelectionRadios')
		if (!this.gameModeSelectionRadios) return false

		this.btnContainer = $.GetContextPanel()
			.FindChildTraverse('StartMatchBtn')
			.GetParent()
		if (!this.btnContainer) return false

		this.tagsContainer = this.workshopSearchBar.GetParent()
		if (!this.tagsContainer) return false

		return true
	},
	createPanelMain() {
		let parent = this.MapSelectionList.GetParent()
		this.panelMain = $.CreatePanel('Panel', parent, this.panelMainId)
		this.panelMain.BLoadLayoutFromString(MAIN_LAYOUT, false, false)
		this.panelMain.enabled = true
		this.panelMain.visible = false

		parent.MoveChildBefore(
			this.panelMain,
			parent.GetChild(0) /* MapSelectionList */
		)

		this.panelMain
			.FindChildTraverse('head-name')
			.SetPanelEvent('onactivate', () => this.nameHeaderPressed())
		this.panelMain
			.FindChildTraverse('head-players')
			.SetPanelEvent('onactivate', () => this.playersHeaderPressed())
		this.panelMain
			.FindChildTraverse('head-map')
			.SetPanelEvent('onactivate', () => this.mapHeaderPressed())
		this.panelMain
			.FindChildTraverse('head-ping')
			.SetPanelEvent('onactivate', () => this.pingHeaderPressed())

		this.panelServerLists.push(
			this.panelMain.FindChildTraverse('serverbrowser-servers-internet'),
			this.panelMain.FindChildTraverse('serverbrowser-servers-favorites'),
			this.panelMain.FindChildTraverse('serverbrowser-servers-history'),
			this.panelMain.FindChildTraverse('serverbrowser-servers-spectate'),
			this.panelMain.FindChildTraverse('serverbrowser-servers-lan'),
			this.panelMain.FindChildTraverse('serverbrowser-servers-friends')
		)
		this.panelServerLists.forEach(hideAllPanels)
	},
	createPanelSide() {
		let parent = this.JsQuickSelectParent.GetParent()
		this.panelSide = $.CreatePanel('Panel', parent, this.panelSideId)
		this.panelSide.BLoadLayoutFromString(SIDE_LAYOUT, false, false)
		this.panelSide.enabled = true
		this.panelSide.visible = false

		parent.MoveChildBefore(
			this.panelSide,
			parent.GetChild(0) /* JsQuickSelectParent */
		)

		this.panelSide
			.FindChildTraverse('serverbrowser-tabs')
			.Children()
			.forEach((ch) => {
				ch.SetPanelEvent('onactivate', () => this.selectTab(ch.id))
			})

		this.btnEditFilters = this.panelSide.FindChildTraverse('EditFilters')
		this.btnEditFilters.SetPanelEvent('onactivate', () =>
			this.editFiltersPressed()
		)
		this.btnOpenOldBrowser = this.panelSide.FindChildTraverse('OpenOldBrowser')
		this.btnOpenOldBrowser.SetPanelEvent('onactivate', () =>
			this.openOldBrowserPressed()
		)
	},
	createPanelBtns() {
		this.panelBtns = $.CreatePanel('Panel', this.btnContainer, this.panelBtnsId)
		this.panelBtns.BLoadLayoutFromString(BTNS_LAYOUT, false, false)
		this.panelBtns.enabled = true
		this.panelBtns.visible = false
		this.btnQuickRefresh = this.panelBtns.FindChild('QuickRefresh')
		this.btnRefresh = this.panelBtns.FindChild('Refresh')
		this.btnConnect = this.panelBtns.FindChild('Connect')

		this.btnQuickRefresh.SetPanelEvent('onactivate', () =>
			this.quickRefreshPressed()
		)
		this.btnRefresh.SetPanelEvent('onactivate', () => this.refreshPressed())
		this.btnConnect.SetPanelEvent('onactivate', () => this.connectPressed())
	},
	createPanelTags() {
		let parent = this.tagsContainer
		this.panelTags = $.CreatePanel('Panel', parent, this.panelTagsId)
		this.panelTags.BLoadLayoutFromString(TAGS_LAYOUT, false, false)
		this.panelTags.enabled = true
		this.panelTags.visible = false

		parent.MoveChildBefore(this.panelTags, parent.GetChild(0) /* front of el */)

		this.txtTags = this.panelTags.FindChildTraverse('TagFilter')
		this.txtTags.SetPanelEvent('ontextentrychange', () =>
			this.tagsFilterUpdated()
		)
		this.txtTags.SetPanelEvent('onfocus', () => this.tagsFilterFocus())

		// Fuck Valve
		this.tagsFocusStealer = this.panelTags.FindChildTraverse('FocusStealer')
	},
	createPanelFWFH() {
		this.panelFWFH = $.CreatePanel(
			'Panel',
			$.GetContextPanel(),
			this.panelFWFHId
		)
		this.panelFWFH.BLoadLayoutFromString(FWFH_LAYOUT, false, false)
		this.panelFWFH.enabled = true
		this.panelFWFH.visible = false

		this.btnFWFH = this.panelFWFH.FindChildTraverse('FWFHButton')
		this.btnFWFH.SetPanelEvent('onactivate', () => this.clickOutTriggered())
	},

	init() {
		if (this.initialized) return true

		if (!this.fetchDependencyPanels()) return false

		this.createPanelMain()
		this.createPanelSide()
		this.createPanelBtns()
		this.createPanelTags()
		this.createPanelFWFH()

		// calling SetSelected will trigger oninputsubmit
		// since you cant hook event listeners in panorama js, the only way to change the dropdown is using SetSelected(Index)
		// every time the item is community in oninputsubmit handler in mainmenu_play it will call the openserverbrowser concmd
		// opening our panel, and settingg PlayCommunity to the item and our game will crash

		hooks.new(
			this.playTopNavDropdown,
			'GetSelected',
			function (bypass = false) {
				let selected = this.orig()
				if (!bypass) {
					browser.lastSelectedItem = selected.id
					if (selected.id === 'PlayCommunity') {
						browser.doneWithFrame = false
					}
				}
				return selected
			}
		)
		hooks.new(this.playTopNavDropdown, 'SetSelected', function (item) {
			if (!browser.doneWithFrame) {
				item = 'PlayCommunity'
			}
			return this.orig(item)
		})

		// "on**user**inputsubmit" my ass
		this.playTopNavDropdown.SetPanelEvent('onuserinputsubmit', () => {
			let selectedId = this.playTopNavDropdown.GetSelected(true).id
			this.lastSelectedItem = selectedId
			this.doneWithFrame = true
			if (selectedId === 'PlayCommunity') {
				this.open()
			} else {
				this.close()
			}
		})

		this.updateHeaders()
		this.initialized = true
		return true
	},
	destroy() {
		this.close()
		this.initialized = false
		if (this.playTopNavDropdown) {
			this.playTopNavDropdown.ClearPanelEvent('onuserinputsubmit')
			this.playTopNavDropdown.SetSelected('Play-official')
		}
		if (this.panelMain) this.panelMain.DeleteAsync(0)
		if (this.panelSide) this.panelSide.DeleteAsync(0)
		if (this.panelBtns) this.panelBtns.DeleteAsync(0)
		if (this.panelTags) this.panelTags.DeleteAsync(0)
		if (this.panelFWFH) this.panelFWFH.DeleteAsync(0)
		if (this.hkSetSelected) this.hkSetSelected.destroy()
	},

	// fwfh focus mgr
	clickOutCallback: [],
	clickOutTriggered() {
		let cb
		while ((cb = this.clickOutCallback.shift())) {
			if (typeof cb === 'function') cb()
		}

		this.hideClickOut()
	},
	showClickOut(callback) {
		this.clickOutCallback.push(callback)
		this.panelFWFH.enabled = this.panelFWFH.visible = true
	},
	hideClickOut() {
		if (this.clickOutCallback.length > 0) this.clickOutCallback = []
		this.panelFWFH.enabled = this.panelFWFH.visible = false
	},

	// utility functions
	selectTab(tab) {
		this.selectedTab = tab
		this.selectedType = Types[tab]

		this.panelSide
			.FindChildTraverse('serverbrowser-tabs')
			.Children()
			.forEach((ch) => ch.SetHasClass('match', ch.id == tab))

		this.panelServerLists.forEach((ch, idx) => {
			ch.visible = idx === this.selectedType
		})

		let filter = this.filters[this.selectedType]
		this.txtTags.text = filter && filter.tags ? filter.tags : ''

		this.updateButtonState()
	},
	isRefreshing(type = this.selectedType) {
		return this.refreshing[type]
	},
	getSelectedServer(type = this.selectedType) {
		return this.selectedServer[type]
	},
	getSelectedServerObj(type = this.selectedType) {
		let uid = this.getSelectedServer(type)
		return this.serverLists[type].find((i) => i.uid === uid)
	},
	getSelectedServerEl(type = this.selectedType) {
		let uid = this.getSelectedServer(type)
		return this.panelServerLists[type].FindChildTraverse(`server-${uid}`)
	},
	selectServer(type, uid, el) {
		let oldEl = this.getSelectedServerEl(type)
		if (oldEl) {
			oldEl.RemoveClass('CartTournamentPasses')
			oldEl.AddClass('evenrow')
		}

		el.AddClass('CartTournamentPasses')
		el.RemoveClass('evenrow')
		this.selectedServer[type] = uid
	},
	updateButtonState() {
		// refresh btn
		let refreshing = this.isRefreshing()
		if (refreshing) {
			this.btnRefresh.FindChild('RefreshSpinner').visible = true
			this.btnRefresh.FindChild('RefreshText').text = 'STOP REFRESH'
		} else {
			this.btnRefresh.FindChild('RefreshSpinner').visible = false
			this.btnRefresh.FindChild('RefreshText').text = 'REFRESH ALL'
		}
	},
	getPlayersForServer(server, cb) {
		this.playerCallbacks[server.uid] = {
			callback: cb,
			players: [],
		}
		Lua.requestPlayerList(server.uid, server.ip, server.port)
	},
	viewServerInfo(server) {
		let callback = UiToolkitAPI.RegisterJSCallback((t, dcb) => {
			switch (t) {
				case 'connect':
					this.connectToServer(server)
					break
				case 'players':
					this.getPlayersForServer(server, dcb)
					break
			}
		})

		let parameters = Object.assign({}, { callback }, server)

		let panelPopup = UiToolkitAPI.ShowCustomLayoutPopupParameters(
			'',
			'',
			this.urlEncode(parameters)
		)
		panelPopup.BLoadLayoutFromString(POPUP_SERVER_LAYOUT, false, false)
	},
	connectToServer(server) {
		Lua.connect(server.ip, server.port)
	},
	addServer(type, server, forceCreate = false) {
		let panelServers = this.panelServerLists[type]
		let srv = panelServers.FindChild(`server-${server.uid}`)
		if (!srv || forceCreate) {
			srv = $.CreatePanel('Panel', panelServers, `server-${server.uid}`)

			srv.BLoadLayoutSnippet('serverbrowser_server')

			if (!forceCreate) {
				/*let svs = this.serverLists[type].slice()
				if (svs.length >= 3) {
					svs.sort(sortFn)
					let ourServer = svs.findIndex((s) => s.i === server.i)
					if (ourServer + 1 !== svs.length) {
						panelServers.MoveChildBefore(
							srv,
							panelServers.FindChild(`server-${svs[ourServer + 1].uid}`)
						)
					}
				}*/
				this.resort(type, false)

				this.panelSide
					.FindChildTraverse(Types[type].toLowerCase())
					.Children()[0].text = `${Types[type]} (${this.serverLists[type].length})`
			}
		}
		let isWorkshopMap = server.map.startsWith('workshop/')
		let mapFixed = server.map
		if (isWorkshopMap) {
			mapFixed = server.map.split('/')
			mapFixed = mapFixed[mapFixed.length - 1]
		}
		srv.FindChildTraverse('password').visible = server.password
		srv.FindChildTraverse('vac').visible = server.secure
		srv.FindChildTraverse('name').text = server.serverName
		srv.FindChildTraverse(
			'players'
		).text = `${server.players} / ${server.maxPlayers}`
		srv.FindChildTraverse('map').text = mapFixed
		srv.FindChildTraverse('ping').text = server.ping.toString()
		srv.enabled = true

		let listText = 'Add server to favorites'
		if (type === Types.favorites) {
			listText = 'Remove server from favorites'
		} else if (type === Types.history) {
			listText = 'Remove server from history'
		}

		let filter = this.filters[type]

		let contextMenu = [
			{
				label: 'Connect to server',
				jsCallback: () => {
					this.connectToServer(server)
				},
			},
			{
				label: 'View server info',
				jsCallback: () => {
					this.viewServerInfo(server)
				},
			},
			{
				label: 'Refresh server',
				jsCallback: () => {
					Lua.quickRefresh(type, server.i)
				},
			},
			{
				label: 'Copy IP to clipboard',
				jsCallback: () => {
					SteamOverlayAPI.CopyTextToClipboard(server.ipPort)
					UiToolkitAPI.HideTextTooltip()
					UiToolkitAPI.ShowTextTooltipOnPanel(
						srv.FindChildTraverse('name'),
						'Copied to clipboard'
					)
					$.Schedule(1, () => UiToolkitAPI.HideTextTooltip())
				},
			},
			{
				label: listText,
				jsCallback: () => {
					let fn = Lua.addToFavorites
					if (type === Types.favorites) {
						fn = Lua.removeFromFavorites
					} else if (type === Types.history) {
						fn = Lua.removeFromHistory
					}
					fn(server.appId, server.ip, server.port, server.queryPort)
				},
			},
			{
				label:
					filter.map === server.map
						? 'Remove map filter'
						: `Only show servers on ${
								server.map.length < 12 ? server.map : 'this map'
							}`,
				jsCallback: () => {
					let origFilter = this.filters[type]
					let alreadyFiltered = origFilter.map === server.map
					let filter = Object.assign({}, origFilter, {
						map: alreadyFiltered ? '' : server.map,
					})

					Lua.saveFilters(type, filter)
					$.Schedule(0.1, () => Lua.refresh(type))
				},
			},
		]
		srv.SetPanelEvent('onactivate', () => {
			this.selectServer(type, server.uid, srv)
		})
		srv.SetPanelEvent('ondblclick', () => {
			this.connectToServer(server)
		})
		srv.SetPanelEvent('oncontextmenu', () => {
			this.selectServer(type, server.uid, srv)
			UiToolkitAPI.ShowSimpleContextMenu('', `ServerContextMenu`, contextMenu)
		})
	},

	// sort lol
	sortColumn: '',
	sortDirection: 'asc',
	updateHeaders() {
		let sortName = this.panelMain.FindChildTraverse('sort-name')
		let sortPlayers = this.panelMain.FindChildTraverse('sort-players')
		let sortMap = this.panelMain.FindChildTraverse('sort-map')
		let sortPing = this.panelMain.FindChildTraverse('sort-ping')
		sortName.visible = false
		sortPlayers.visible = false
		sortMap.visible = false
		sortPing.visible = false

		let sortEl

		switch (this.sortColumn) {
			case 'serverName':
				sortEl = sortName
				break
			case 'players':
				sortEl = sortPlayers
				break
			case 'map':
				sortEl = sortMap
				break
			case 'ping':
				sortEl = sortPing
				break
			default:
				sortEl = null
				break
		}
		if (!sortEl) return
		sortEl.visible = true

		sortEl.style.paddingTop = this.sortDirection === 'asc' ? '4px' : '5px'
		sortEl.style.transform =
			this.sortDirection === 'asc' ? 'rotateZ(0deg)' : 'rotateZ(180deg)'
	},
	getSortFunction() {
		if (this.sortColumn === '')
			return () => {
				return 0
			}

		const numericSort = (a, b) => {
			if (this.sortDirection === 'asc') [a, b] = [b, a]
			return a[this.sortColumn] - b[this.sortColumn]
		}
		const stringSort = (a, b) => {
			if (this.sortDirection === 'asc') [a, b] = [b, a]
			let av = a[this.sortColumn],
				bv = b[this.sortColumn]
			if (av < bv) return -1
			if (av > bv) return 1
			return 0
		}

		if (this.sortColumn === 'serverName' || this.sortColumn === 'map')
			return stringSort

		return numericSort
	},
	resort(type = this.selectedType, rerender = true) {
		const sortFn = this.getSortFunction()
		let panelServers = this.panelServerLists[type]
		this.serverLists[type].sort((a, b) => {
			let retval = sortFn(a, b)

			if (!rerender) {
				let elA = panelServers.FindChild(`server-${a.uid}`)
				let elB = panelServers.FindChild(`server-${b.uid}`)
				if (elA && elB && retval !== 0) {
					if (retval < 0) {
						panelServers.MoveChildBefore(elA, elB)
					} else {
						panelServers.MoveChildAfter(elA, elB)
					}
				}
			}
			return retval
		})
		this.updateHeaders()
		if (rerender) this.rerender(type)
	},
	rerender(type = this.selectedType) {
		this.panelServerLists[type].Children().forEach(destroyAllPanels)
		for (let server of this.serverLists[type]) {
			this.addServer(type, server, true)
		}
	},

	// popup
	editFilters(type = this.selectedType) {
		let callback = UiToolkitAPI.RegisterJSCallback((filters) => {
			Lua.saveFilters(type, filters)
		})

		let parameters = Object.assign({}, { callback }, this.filters[type])

		let panelPopup = UiToolkitAPI.ShowGlobalCustomLayoutPopupParameters(
			'',
			'',
			this.urlEncode(parameters)
		)
		panelPopup.BLoadLayoutFromString(POPUP_FILTERS_LAYOUT, false, false)
	},

	// events
	playCommunityPressed() {
		//this.playTopNavDropdown.SetSelected('PlayCommunity')
		this.open()
	},
	quickRefreshPressed() {
		let srv = this.getSelectedServerObj()
		if (!srv) return
		Lua.quickRefresh(this.selectedType, srv.i)
		this.updateButtonState()
	},
	refreshPressed() {
		let refreshing = this.isRefreshing()
		if (refreshing) {
			Lua.stopRefresh(this.selectedType)
		} else {
			Lua.refresh(this.selectedType)
		}
		this.updateButtonState()
	},
	connectPressed() {
		let srv = this.getSelectedServerObj()
		if (!srv) return
		this.connectToServer(srv)
		this.updateButtonState()
	},
	editFiltersPressed() {
		this.editFilters()
	},
	openOldBrowserPressed() {
		GameInterfaceAPI.ConsoleCommand('gamemenucommand openserverbrowser ')
	},
	tagsFilterUpdated(type = this.selectedType) {
		let tags = $.HTMLEscape(this.txtTags.text, true).toLowerCase()
		Lua.updateTagFilter(type, tags)
	},
	tagsFilterFocus() {
		this.showClickOut(() => {
			this.tagsFocusStealer.SetFocus()
		})
	},

	nameHeaderPressed() {
		this.sortColumn = 'serverName'
		this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc'
		this.resort()
	},
	playersHeaderPressed() {
		this.sortColumn = 'players'
		this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc'
		this.resort()
	},
	mapHeaderPressed() {
		this.sortColumn = 'map'
		this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc'
		this.resort()
	},
	pingHeaderPressed() {
		this.sortColumn = 'ping'
		this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc'
		this.resort()
	},

	// visibility
	open() {
		if (!this.initialized) return
		this.MapSelectionList.visible = false
		this.JsQuickSelectParent.visible = false
		this.JsQuickSelectParent.GetParent().AddClass('competitive')
		this.JsQuickSelectParent.GetParent().AddClass('official')

		this.settingsContainer.visible = false
		this.gameModeSelectionRadios.AddClass('hidden')
		this.workshopSearchBar.AddClass('hidden')

		this.panelMain.visible = true
		this.panelSide.visible = true
		this.panelTags.visible = true
		this.btnContainer.Children().forEach(hidePanels(true))

		this.selectTab(this.selectedTab)

		this.isOpen = true
	},
	close() {
		if (!this.initialized) return
		this.MapSelectionList.visible = true
		this.JsQuickSelectParent.visible = true
		this.JsQuickSelectParent.GetParent().RemoveClass('competitive')
		this.JsQuickSelectParent.GetParent().RemoveClass('official')

		this.settingsContainer.visible = true
		this.gameModeSelectionRadios.RemoveClass('hidden')
		this.workshopSearchBar.RemoveClass('hidden')

		this.panelMain.visible = this.panelSide.visible = false
		this.panelTags.visible = this.panelBtns.visible = false
		this.btnContainer.Children().forEach(hidePanels(false))

		this.isOpen = false
	},

	// Lua -> JS bridge funcs
	_clearServerList(type) {
		this.panelSide
			.FindChildTraverse(Types[type].toLowerCase())
			.Children()[0].text = `${Types[type]} (0)`
		this.selectedServer[type] = ''
		this.serverLists[type] = []
		this.panelServerLists[type].Children().forEach(destroyAllPanels)
	},
	_setRefreshing(type, refreshing) {
		this.refreshing[type] = refreshing
		if (!refreshing) {
			this.resort(type)
		}
		this.updateButtonState()
	},
	_addServer(type, server) {
		if (this.filters[type]) {
			let flt = this.filters[type]
			if (flt.anticheat === 'AntiCheatInsecure' && server.secure) return
			if (flt.latency) {
				let lat = latencyIdToThreshold(flt.latency)
				if (server.ping > lat) return
			}
		}
		server.uid = `${type}-${server.i}`
		server.ipPort = ipToString(server.ip)
		if (server.port !== 27015) {
			server.ipPort += ':'
			server.ipPort += server.port
		}
		if (!this.serverLists[type].find((i) => i.i == server.i))
			this.serverLists[type].push(server)
		this.addServer(type, server)
	},
	_setFilters(type, filters) {
		this.filters[type] = filters
		if (type === this.selectedType) {
			if (this.txtTags && !this.txtTags.BHasKeyFocus()) {
				this.txtTags.text = filters.tags || ''
			}
		}
	},

	_clearPlayerList(uid) {
		try {
			let obj = this.playerCallbacks[uid]
			if (!obj) return
			UiToolkitAPI.InvokeJSCallback(obj.callback, 'clearPlayerList', {})
		} catch (err) {}
	},
	_playerRefreshStatus(uid, success) {
		try {
			let obj = this.playerCallbacks[uid]
			if (!obj) return
			UiToolkitAPI.InvokeJSCallback(obj.callback, 'playerRefreshStatus', {
				success,
			})
		} catch (err) {}
	},
	_playerAdded(uid, name, score, timePlayed) {
		try {
			let obj = this.playerCallbacks[uid]
			if (!obj) return
			UiToolkitAPI.InvokeJSCallback(obj.callback, 'playerAdded', {
				name,
				score,
				timePlayed,
			})
		} catch (err) {}
	},
}

Lua.init()
browser.init()

hooks.new(GameInterfaceAPI, 'ConsoleCommand', function (cmd) {
	if (
		cmd === 'gamemenucommand openserverbrowser' &&
		!MatchStatsAPI.IsConnectedToCommunityServer()
	) {
		if (!browser.initialized) {
			browser.init()
			browser.open()
		}
		return
	}
	return this.orig(cmd)
})

return {
	shutdown: () => {
		try {
			hooks.destroy()
		} catch (err) {
			$.Msg('Error while destroying hooks: ' + err.toString())
		}
		try {
			browser.destroy()
		} catch (err) {
			$.Msg('Error while destroying browser: ' + err.toString())
		}
		UiToolkitAPI.CloseAllVisiblePopups()
	},
	ClearServerList: (type) => browser._clearServerList(type),
	RefreshStatus: (type, refreshing) => browser._setRefreshing(type, refreshing),
	ServerAdded: (type, server) => browser._addServer(type, server),
	GetFilters: (type, filters) => browser._setFilters(type, filters),
	ClearPlayerList: (uid) => browser._clearPlayerList(uid),
	PlayerRefreshStatus: (uid, success) =>
		browser._playerRefreshStatus(uid, success),
	PlayerAdded: (uid, name, score, timePlayed) =>
		browser._playerAdded(uid, name, score, timePlayed),
}
]],
	"CSGOMainMenu"
)()

local ptrToNum = function(ptr)
	return tonumber(ffi.cast("uintptr_t", ptr))
end

local function gameServerItemToTable(type, iServer, gsi)
	local tbl = {
		type = type,
		i = iServer,
		ip = tonumber(gsi.m_NetAdr.m_unIP),
		port = tonumber(gsi.m_NetAdr.m_usConnectionPort),
		queryPort = tonumber(gsi.m_NetAdr.m_usQueryPort),
		ping = tonumber(gsi.m_nPing),
		successful = gsi.m_bHadSuccessfulResponse == true,
		doNotRefresh = gsi.m_bDoNotRefresh == true,
		gameDir = ffi.string(gsi.m_szGameDir),
		map = ffi.string(gsi.m_szMap),
		gameDesc = ffi.string(gsi.m_szGameDescription),
		appId = gsi.m_nAppID,
		players = tonumber(gsi.m_nPlayers),
		maxPlayers = tonumber(gsi.m_nMaxPlayers),
		botPlayers = tonumber(gsi.m_nBotPlayers),
		password = gsi.m_bPassword == true,
		secure = gsi.m_bSecure == true,
		timeLastPlayed = tonumber(gsi.m_ulTimeLastPlayed),
		serverVersion = tonumber(gsi.m_nServerVersion),
		serverName = ffi.string(gsi.m_szServerName),
		gameTags = ffi.string(gsi.m_szGameTags)
	}
	return tbl
end

local requests = {}
local function getRequestForType(type)
	for k, v in pairs(requests) do
		if v.type == type and not v.released then
			return v
		end
	end
	return nil
end

local requestCallbacks =
	steamworks.ISteamMatchmakingServerListResponse.new(
	{
		ServerResponded = function(self, hRequest, iServer)
			local req = requests[ptrToNum(hRequest)]
			local det = ISteamMatchmakingServers.GetServerDetails(hRequest, iServer)
			local gst = gameServerItemToTable(req.type, iServer, det)
			js.ServerAdded(req.type, gst)
		end,
		ServerFailedToRespond = function(self, hRequest, iServer)
		end,
		RefreshComplete = function(self, hRequest, iServerSize)
			local req = requests[ptrToNum(hRequest)]
			js.RefreshStatus(req.type, false)
			req.refreshing = false
		end
	}
)

-- https://developer.valvesoftware.com/wiki/Master_Server_Query_Protocol#Region_codes
local function regionIdToCode(loc)
	if loc == "LocationUSE" then
		return "0"
	elseif loc == "LocationUSW" then
		return "1"
	elseif loc == "LocationSA" then
		return "2"
	elseif loc == "LocationEU" then
		return "3"
	elseif loc == "LocationAS" then
		return "4"
	elseif loc == "LocationAU" then
		return "5"
	elseif loc == "LocationME" then
		return "6"
	elseif loc == "LocationAF" then
		return "7"
	else -- LocationAll
		return "255"
	end
end

local function buildFilters(type)
	local f = config.filters[type + 1]

	local filters = {}
	local andFilters = {}
	local orFilters = {}
	local nandFilters = {}
	local norFilters = {}

	local gametagsAnd = {}
	local gametagsNor = {"valve_ds"}

	if f.map then
		table.insert(filters, {"map", f.map})
	end

	if f.notEmpty then
		table.insert(filters, {"empty", "1"})
	end

	if f.notFull then
		table.insert(filters, {"full", "1"})
	end

	if f.anticheat then
		if f.anticheat == "AntiCheatSecure" then
			table.insert(filters, {"secure", "1"}) -- value is ignored
		elseif f.anticheat == "AntiCheatInsecure" then
			table.insert(gametagsNor, "secure")
		end
	end

	if f.location then
		local region = regionIdToCode(f.location)
		if region ~= "255" then
			table.insert(filters, {"region", region})
		end
	end

	if f.tags then
		table.insert(gametagsAnd, f.tags)
	end

	--table.insert(filters, {"gametype", "notags"})

	if #andFilters > 0 then
		table.insert(filters, {"and", #andFilters})
		for i = 1, #andFilters do
			table.insert(filters, andFilters[i])
		end
	end
	if #orFilters > 0 then
		table.insert(filters, {"or", #orFilters})
		for i = 1, #orFilters do
			table.insert(filters, orFilters[i])
		end
	end
	if #nandFilters > 0 then
		table.insert(filters, {"nand", #nandFilters})
		for i = 1, #nandFilters do
			table.insert(filters, nandFilters[i])
		end
	end
	if #norFilters > 0 then
		table.insert(filters, {"nor", #norFilters})
		for i = 1, #norFilters do
			table.insert(filters, norFilters[i])
		end
	end

	if #gametagsAnd > 0 then
		table.insert(filters, {"gametagsand", table.concat(gametagsAnd, ",")})
	end

	if #gametagsNor > 0 then
		table.insert(filters, {"gametagsnor", table.concat(gametagsNor, ",")})
	end

	return #filters, filters
end

local function steamworksRequestServerList(type)
	local filterSize, filters = buildFilters(type)
	local filterArr = steamworks.MatchMakingKeyValuePair_t_arr(filterSize, filters)
	local ptrFilters = ffi.new("MatchMakingKeyValuePair_t*[1]")
	ptrFilters[0] = filterArr
	local req = -1
	if type == 0 then
		req = ISteamMatchmakingServers.RequestInternetServerList(APP_ID, ptrFilters, filterSize, requestCallbacks)
	elseif type == 1 then
		req = ISteamMatchmakingServers.RequestFavoritesServerList(APP_ID, ptrFilters, filterSize, requestCallbacks)
	elseif type == 2 then
		req = ISteamMatchmakingServers.RequestHistoryServerList(APP_ID, ptrFilters, filterSize, requestCallbacks)
	elseif type == 3 then
		req = ISteamMatchmakingServers.RequestSpectatorServerList(APP_ID, ptrFilters, filterSize, requestCallbacks)
	elseif type == 4 then
		req = ISteamMatchmakingServers.RequestLANServerList(APP_ID, requestCallbacks)
	elseif type == 5 then
		req = ISteamMatchmakingServers.RequestFriendsServerList(APP_ID, ptrFilters, filterSize, requestCallbacks)
	else
		return -1
	end
	requests[ptrToNum(req)] = {
		handle = req,
		type = type,
		refreshing = true,
		released = false
	}
	return ptrToNum(req)
end
local function steamworksRequestPlayerList(uid, ip, port)
	local req = -1
	local cb =
		steamworks.ISteamMatchmakingPlayersResponse.new(
		{
			AddPlayerToList = function(self, pchName, nScore, flTimePlayed)
				js.PlayerAdded(uid, ffi.string(pchName), tonumber(nScore), tonumber(flTimePlayed))
			end,
			PlayersFailedToRespond = function(self)
				js.PlayerRefreshStatus(uid, false) -- error
			end,
			PlayersRefreshComplete = function(self)
				js.PlayerRefreshStatus(uid, true) -- success
				requests[ptrToNum(req)].refreshing = false
			end
		}
	)
	js.ClearPlayerList(uid)
	req = ISteamMatchmakingServers.PlayerDetails(ip, port, cb)
	requests[ptrToNum(req)] = {
		handle = req,
		type = -1,
		refreshing = true
	}
end
local function steamworksRefreshQuery(type, req)
	ISteamMatchmakingServers.RefreshQuery(req)
	return req
end

local function steamworksAddToFavorites(appId, ip, port, queryPort)
	ISteamMatchmaking.AddFavoriteGame(appId, ip, port, queryPort, k_unFavoriteFlagFavorite, 0)
end
local function steamworksRemoveFromFavorites(appId, ip, port, queryPort)
	ISteamMatchmaking.RemoveFavoriteGame(appId, ip, port, queryPort, k_unFavoriteFlagFavorite)
end
local function steamworksAddToHistory(appId, ip, port, queryPort)
	ISteamMatchmaking.AddFavoriteGame(0, ip, port, queryPort, k_unFavoriteFlagHistory, 0)
end
local function steamworksRemoveFromHistory(appId, ip, port, queryPort)
	ISteamMatchmaking.RemoveFavoriteGame(0, ip, port, queryPort, k_unFavoriteFlagHistory)
end

local function refreshServerList(type)
	js.ClearServerList(type)
	js.RefreshStatus(type, true)
	steamworksRequestServerList(type)
end

local function isRefreshing(type)
	for k, v in pairs(requests) do
		if v.type == type and v.refreshing then
			return true, k
		end
	end
	return false, 0
end

local function stopRefreshing(type)
	for k, v in pairs(requests) do
		if v.type == type and v.refreshing then
			ISteamMatchmakingServers.CancelQuery(v.handle)
			v.refreshing = false
			js.RefreshStatus(v.type, false)
			return true, k
		end
	end
	return false, 0
end

local function stopRefreshingAll()
	for k, v in pairs(requests) do
		if v.refreshing then
			if v.type == -1 then -- this is a HServerQuery
				ISteamMatchmakingServers.CancelServerQuery(v.handle)
			else
				ISteamMatchmakingServers.CancelQuery(v.handle)
			end
			v.refreshing = false
			js.RefreshStatus(v.type, false)
		end
		if not v.released and v.type ~= -1 then
			ISteamMatchmakingServers.ReleaseRequest(v.handle)
			v.released = true
		end
	end
end

local function sendFiltersToJs(type)
	js.GetFilters(type, config.filters[type + 1])
end

local function ipToString(num)
	-- (num >> (8 * 3)) & 0xff,
	-- (num >> (8 * 2)) & 0xff,
	-- (num >> (8 * 1)) & 0xff,
	-- (num >> (8 * 0)) & 0xff,
	local seg = {
		bit.band(bit.rshift(num, 24), 255),
		bit.band(bit.rshift(num, 16), 255),
		bit.band(bit.rshift(num, 8), 255),
		bit.band(bit.rshift(num, 0), 255)
	}
	return table.concat(seg, ".")
end

local function connect(ip, port)
	concmdConnect:invoke_callback(ip .. ":" .. port)
end

local panoramaBridge = {
	refresh = function(type)
		local refreshing = isRefreshing(type)
		if refreshing then
			client.error_log("^^ Already refreshing!! ^^")
		else
			local foundReq = getRequestForType(type)
			if foundReq then
				if foundReq.refreshing then
					ISteamMatchmakingServers.CancelQuery(foundReq.handle)
					foundReq.refreshing = false
				end
				ISteamMatchmakingServers.ReleaseRequest(foundReq.handle)
				foundReq.released = true
			end
			refreshServerList(type)
		end
	end,
	stopRefresh = function(type)
		stopRefreshing(type)
	end,
	quickRefresh = function(type, server)
		local foundReq = getRequestForType(type)
		if foundReq then
			ISteamMatchmakingServers.RefreshServer(foundReq.handle, server)
		end
	end,
	connect = function(ip, port)
		local sIp = ipToString(ip)
		local sPort = "27015"
		if type(port) == "number" then
			sPort = tostring(port)
		end
		cvarPassword:set_string("")
		connect(sIp, sPort)
	end,
	connectWithPassword = function(ip, port, password)
		local sIp = ipToString(ip)
		local sPort = "27015"
		if type(port) == "number" then
			sPort = tostring(port)
		end
		if type(password) == "string" then
			cvarPassword:set_string(password)
		end
		connect(sIp, sPort)
	end,
	requestFilters = function(type)
		sendFiltersToJs(type)
	end,
	saveFilters = function(type, filters)
		filters = json.parse(filters)
		if filters == nil then
			return
		end
		local oldTags = ""
		if config.filters[type + 1] then
			oldTags = config.filters[type + 1].tags
		end
		config.filters[type + 1] = filters
		config.filters[type + 1].tags = oldTags
		sendFiltersToJs(type)
	end,
	updateTagFilter = function(type, tags)
		config.filters[type + 1] = config.filters[type + 1] or {}
		config.filters[type + 1].tags = tags
		sendFiltersToJs(type)
	end,
	addToFavorites = function(appId, ip, port, queryPort)
		steamworksAddToFavorites(appId, ip, port, queryPort)
	end,
	removeFromFavorites = function(appId, ip, port, queryPort)
		steamworksRemoveFromFavorites(appId, ip, port, queryPort)
	end,
	addToHistory = function(appId, ip, port, queryPort)
		steamworksAddToHistory(appId, ip, port, queryPort)
	end,
	removeFromHistory = function(appId, ip, port, queryPort)
		steamworksRemoveFromHistory(appId, ip, port, queryPort)
	end,
	requestPlayerList = function(uid, ip, port)
		steamworksRequestPlayerList(uid, ip, port)
	end
}

for type = 0, 5 do
	sendFiltersToJs(type)
end

panorama_events.register_event(EVENTS.Refresh, panoramaBridge.refresh)
panorama_events.register_event(EVENTS.StopRefresh, panoramaBridge.stopRefresh)
panorama_events.register_event(EVENTS.QuickRefresh, panoramaBridge.quickRefresh)
panorama_events.register_event(EVENTS.Connect, panoramaBridge.connect)
panorama_events.register_event(EVENTS.ConnectWithPassword, panoramaBridge.connectWithPassword)
panorama_events.register_event(EVENTS.RequestFilters, panoramaBridge.requestFilters)
panorama_events.register_event(EVENTS.SaveFilters, panoramaBridge.saveFilters)
panorama_events.register_event(EVENTS.UpdateTagFilter, panoramaBridge.updateTagFilter)
panorama_events.register_event(EVENTS.AddToFavorites, panoramaBridge.addToFavorites)
panorama_events.register_event(EVENTS.RemoveFromFavorites, panoramaBridge.removeFromFavorites)
panorama_events.register_event(EVENTS.AddToHistory, panoramaBridge.addToHistory)
panorama_events.register_event(EVENTS.RemoveFromHistory, panoramaBridge.removeFromHistory)
panorama_events.register_event(EVENTS.RequestPlayerList, panoramaBridge.requestPlayerList)

client.set_event_callback(
	"shutdown",
	function()
		stopRefreshingAll()
		js.shutdown()
		saveConfig()
	end
)