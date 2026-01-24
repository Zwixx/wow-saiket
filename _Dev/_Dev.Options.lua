--[[****************************************************************************
  * _Dev by Saiket                                                             *
  * _Dev.Options.lua - Adds an options panel using Ace3                        *
  ****************************************************************************]]


local _Dev = _Dev;
local L = _DevLocalization;

-- Lade Ace3-Bibliotheken mit Fallback
local AceConfig, AceConfigDialog;
local hasAce = pcall(function()
	AceConfig = LibStub("AceConfig-3.0");
	AceConfigDialog = LibStub("AceConfigDialog-3.0");
end);

local NS = {};
_Dev.Options = NS;

-- Speicher für Callbacks für externe Verwendung
local Callbacks = {};
NS.Callbacks = Callbacks;
NS.Controls = {};

--[[****************************************************************************
  * Function: _Dev.Options.GetVariableVararg                                   *
  * Description: Returns the table and key name for a saved variable string.   *
  ****************************************************************************]]
do
	local select = select;
	function NS.GetVariableVararg ( ... )
		local Table = _DevOptions;
		local Count = select( "#", ... );
		for Index = 1, Count - 1 do
			Table = Table[ select( Index, ... ) ];
		end
		return Table, select( Count, ... );
	end
end

--[[****************************************************************************
  * Function: _Dev.Options.SetVariable                                         *
  * Description: Saves a value to a control's saved variable.                  *
  ****************************************************************************]]
function NS.SetVariable ( Variable, Value )
	local Table, Key = NS.GetVariableVararg( ( "." ):split( Variable ) );
	if ( Table[ Key ] ~= Value ) then
		Table[ Key ] = Value;
		if ( Callbacks[ Variable ] ) then
			Callbacks[ Variable ]( Value );
		end
	end
end

--[[****************************************************************************
  * Function: _Dev.Options.SetVariableCallback                                 *
  * Description: Adds a callback to call when a given variable is changed.     *
  ****************************************************************************]]
function NS.SetVariableCallback ( Variable, Callback )
	Callbacks[ Variable ] = Callback;
end

--[[****************************************************************************
  * Function: _Dev.Options.Update                                              *
  * Description: Syncs variables (compatibility function)                      *
  ****************************************************************************]]
function NS.Update ()
	-- Mit Ace3 automatisch, diese Funktion dient nur Kompatibilität
end

--[[****************************************************************************
  * Function: _Dev.Options.SlashCommand                                        *
  * Description: Slash command chat handler to open the options pane.          *
  ****************************************************************************]]
function NS.SlashCommand ()
	if hasAce and AceConfigDialog then
		AceConfigDialog:Open("_Dev");
	else
		print("Ace3-Bibliotheken nicht verfügbar. Bitte Ace3 installieren.");
	end
end

-- Nur wenn Ace3 verfügbar ist, registriere Optionen
if hasAce and AceConfig and AceConfigDialog then
	-- Definiere die Optionen für Ace3
	local options = {
		name = L.OPTIONS_TITLE,
		handler = NS,
		type = "group",
		args = {
			desc = {
				order = 0,
				type = "description",
				name = L.OPTIONS_DESC,
			},
			PrintLuaErrors = {
				order = 1,
				type = "toggle",
				name = L.OPTIONS.PrintLuaErrors,
				desc = L.OPTIONS.PrintLuaErrors_DESC or "",
				get = function() return _DevOptions.PrintLuaErrors; end,
				set = function(info, val) NS.SetVariable("PrintLuaErrors", val); end,
			},
			dump = {
				order = 2,
				type = "group",
				name = L.OPTIONS.DUMP or "Dump",
				args = {
					SkipGlobalEnv = {
						order = 1,
						type = "toggle",
						name = L.OPTIONS["Dump.SkipGlobalEnv"] or "Skip Global Env",
						desc = L.OPTIONS["Dump.SkipGlobalEnv_DESC"] or "",
						get = function() return _DevOptions.Dump.SkipGlobalEnv; end,
						set = function(info, val) NS.SetVariable("Dump.SkipGlobalEnv", val); end,
					},
					MaxExploreTime = {
						order = 2,
						type = "input",
						pattern = "%d+",
						name = L.OPTIONS["Dump.MaxExploreTime"] or "Max Explore Time",
						desc = L.OPTIONS["Dump.MaxExploreTime_DESC"] or "",
						get = function() return tostring(_DevOptions.Dump.MaxExploreTime or 0); end,
						set = function(info, val) NS.SetVariable("Dump.MaxExploreTime", tonumber(val) or 0); end,
					},
					MaxDepth = {
						order = 3,
						type = "input",
						pattern = "%d+",
						name = L.OPTIONS["Dump.MaxDepth"] or "Max Depth",
						desc = L.OPTIONS["Dump.MaxDepth_DESC"] or "",
						get = function() return tostring(_DevOptions.Dump.MaxDepth or 0); end,
						set = function(info, val) NS.SetVariable("Dump.MaxDepth", tonumber(val) or 0); end,
					},
					MaxTableLen = {
						order = 4,
						type = "input",
						pattern = "%d+",
						name = L.OPTIONS["Dump.MaxTableLen"] or "Max Table Length",
						desc = L.OPTIONS["Dump.MaxTableLen_DESC"] or "",
						get = function() return tostring(_DevOptions.Dump.MaxTableLen or 0); end,
						set = function(info, val) NS.SetVariable("Dump.MaxTableLen", tonumber(val) or 0); end,
					},
					MaxStrLen = {
						order = 5,
						type = "input",
						pattern = "%d+",
						name = L.OPTIONS["Dump.MaxStrLen"] or "Max String Length",
						desc = L.OPTIONS["Dump.MaxStrLen_DESC"] or "",
						get = function() return tostring(_DevOptions.Dump.MaxStrLen or 0); end,
						set = function(info, val) NS.SetVariable("Dump.MaxStrLen", tonumber(val) or 0); end,
					},
					EscapeMode = {
						order = 6,
						type = "select",
						name = L.OPTIONS["Dump.EscapeMode"] or "Escape Mode",
						desc = L.OPTIONS["Dump.EscapeMode_DESC"] or "",
						values = function()
							local args = L.OPTIONS["Dump.EscapeMode_ARGS"];
							if not args then return {[0] = "None"}; end
							local values = {};
							for i = 0, #args do
								values[i] = args[i];
							end
							return values;
						end,
						get = function() return _DevOptions.Dump.EscapeMode or 0; end,
						set = function(info, val) NS.SetVariable("Dump.EscapeMode", val); end,
					},
				},
			},
			outline = {
				order = 3,
				type = "group",
				name = L.OPTIONS.OUTLINE or "Outline",
				args = {
					BoundsThreshold = {
						order = 1,
						type = "input",
						pattern = "%d+",
						name = L.OPTIONS["Outline.BoundsThreshold"] or "Bounds Threshold",
						desc = L.OPTIONS["Outline.BoundsThreshold_DESC"] or "",
						get = function() return tostring(_DevOptions.Outline.BoundsThreshold or 0); end,
						set = function(info, val) NS.SetVariable("Outline.BoundsThreshold", tonumber(val) or 0); end,
					},
					BorderAlpha = {
						order = 2,
						type = "range",
						min = 0,
						max = 1,
						step = 0.1,
						name = L.OPTIONS["Outline.BorderAlpha"] or "Border Alpha",
						desc = L.OPTIONS["Outline.BorderAlpha_DESC"] or "",
						get = function() return _DevOptions.Outline.BorderAlpha or 0.5; end,
						set = function(info, val) 
							NS.SetVariable("Outline.BorderAlpha", val); 
							if _Dev.Outline and _Dev.Outline.Update then
								_Dev.Outline.Update();
							end
						end,
					},
				},
			},
		},
	};

	-- Registriere die Optionen mit Ace3
	AceConfig:RegisterOptionsTable("_Dev", options);
	AceConfigDialog:AddToBlizOptions("_Dev", L.OPTIONS_TITLE);
	
	print("|cffCCCC88_Dev|r: Optionen mit Ace3 registriert");
else
	print("|cffCCCC88_Dev|r: Warnung - Ace3 nicht gefunden. Optionen funktionieren möglicherweise nicht korrekt.");
	print("|cffCCCC88_Dev|r: Bitte stelle sicher, dass eine Ace3-Bibliothek installiert ist.");
end

-- Slash-Befehl registrieren
SLASH__DEV_OPTIONS1 = "/dev";
SlashCmdList[ "_DEV_OPTIONS" ] = NS.SlashCommand;
