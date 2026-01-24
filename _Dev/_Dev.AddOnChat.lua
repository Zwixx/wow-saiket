--[[****************************************************************************
  * _Dev by Saiket                                                             *
  * _Dev.AddOnChat.lua - Adds hidden addon communication to chat windows.      *
  * WoW 12.0+ compatible using Menu.ModifyMenu API                            *
  ****************************************************************************]]


local _Dev = _Dev;
local L = _DevLocalization;
local NS = CreateFrame( "Frame", nil, _Dev );
_Dev.AddOnChat = NS;

NS.ListenerCount = 0; -- Number of chat types registered across all chat frames
local ChatFrames = {};
NS.ChatFrames = ChatFrames;

--[[****************************************************************************
  * Function: _Dev.AddOnChat.EnableChatType                                    *
  * Description: Enables or disables a chat type for the given chat window.    *
  ****************************************************************************]]
function NS.EnableChatType ( ChatFrame, Type, Enable )
	if ( not ChatFrames[ ChatFrame ] ) then
		if ( not Enable ) then
			return;
		end
		ChatFrames[ ChatFrame ] = { n = 0 };
	end
	local TypeList = ChatFrames[ ChatFrame ];
	local TypeCount = TypeList.n;

	local Count = NS.ListenerCount;
	if ( Enable ) then
		if ( not TypeList[ Type ] ) then
			if ( Count == 0 ) then
				NS:RegisterEvent( "CHAT_MSG_ADDON" );
			end
			NS.ListenerCount = Count + 1;
			TypeList[ Type ] = true;
			TypeList.n = TypeCount + 1;
		end

	elseif ( TypeList[ Type ] ) then
		if ( Count == 1 ) then
			NS:UnregisterEvent( "CHAT_MSG_ADDON" );
		end
		NS.ListenerCount = Count - 1;
		TypeList[ Type ] = nil;
		if ( TypeCount == 1 ) then -- About to remove last chat type
			ChatFrames[ ChatFrame ] = nil;
		else
			TypeList.n = TypeCount - 1;
		end
	end
end

--[[****************************************************************************
  * Function: _Dev.AddOnChat.AddMessage                                        *
  * Description: Adds an addon chat message to all registered frames.          *
  ****************************************************************************]]
do
	local EscapeString = _Dev.Dump.EscapeString;
	local Print, tostring = _Dev.Print, tostring;
	function NS.AddMessage ( Prefix, Message, Type, Sender )
		local Color = ChatTypeInfo[ Type ];
		if L.ADDONCHAT_TYPES[ Type ] == nil then
			print("Channeltyp unbekannt: "..Type)
		end
		local Message = L.ADDONCHAT_MSG_FORMAT:format( L.ADDONCHAT_TYPES[ Type ],
			Type == "WHISPER_INFORM" and L.ADDONCHAT_OUTBOUND or "",
			Sender, EscapeString( tostring( Prefix ) ), EscapeString( tostring( Message ) ) );
		if ( Type == "WHISPER_INFORM" ) then
			Type = "WHISPER";
		end

		for ChatFrame, TypeList in pairs( ChatFrames ) do
			if ( TypeList[ Type ] ) then
				Print( Message, ChatFrame, Color );
			end
		end
	end
end

--[[****************************************************************************
  * Function: _Dev.AddOnChat:OnEvent                                           *
  ****************************************************************************]]
function NS:OnEvent ( Event, ... )
	NS.AddMessage( ... );
end

--[[****************************************************************************
  * Function: _Dev.AddOnChat.SendAddonMessage                                  *
  ****************************************************************************]]
do
	local strupper = strupper;
	function NS.SendAddonMessage ( Prefix, Message, Type, Target )
		if ( NS:IsEventRegistered( "CHAT_MSG_ADDON" ) and Type:upper() == "WHISPER" ) then
			NS.AddMessage( Prefix, Message, "WHISPER_INFORM", Target:lower():gsub( "^%a", strupper ) );
		end
	end
end

--[[****************************************************************************
  * Function: _Dev.AddOnChat.CreateChatMenuItems                               *
  * Description: Creates menu items for addon chat configuration               *
  ****************************************************************************]]
local function CreateChatMenuItems( rootDescription, ChatFrame )
	rootDescription:CreateDivider();
	submenu = rootDescription:CreateButton(L.ADDONCHAT_MESSAGES or "Addon Messages");
	
	-- Define chat types with their order
	local chatTypes = {
		"GUILD",
		"OFFICER",
		"RAID",
		"PARTY",
		"BATTLEGROUND",
		"WHISPER",
		"CHANNEL",
	};
	
	-- Create checkbox for each chat type
	for _, Type in ipairs(chatTypes) do
		-- Capture Type in a local variable to avoid closure issues
		local chatType = Type;
		local frame = ChatFrame;
		
		-- Create closures that capture the correct values
		local function GetChecked()
			local TypeList = ChatFrames[ frame ];
			return ( TypeList and TypeList[ chatType ] ) and true or false;
		end
		
		local function OnClick()
			local isCurrentlyEnabled = GetChecked();
			NS.EnableChatType( frame, chatType, not isCurrentlyEnabled );
		end
		
		-- The third parameter is the checked state getter (returns true/false)
		-- The second parameter is the click handler
		submenu:CreateCheckbox(
			L.ADDONCHAT_TYPES[ chatType ] or chatType,
			GetChecked,
			OnClick
		);
	end
end

--[[****************************************************************************
  * Function: _Dev.AddOnChat.SetupChatFrameMenu                                *
  * Description: Sets up the chat frame context menu                           *
  ****************************************************************************]]
function NS.SetupChatFrameMenu()
	-- Hook into chat frame tab menu
	Menu.ModifyMenu("MENU_FCF_TAB", function(ownerRegion, rootDescription, contextData)
		if contextData then
			for k, v in pairs(contextData) do
				print("|cffCCCC88_Dev|r:   "..tostring(k).." = "..tostring(v));
			end
		end
		
		-- Get the current chat frame
		local chatFrame = FCF_GetCurrentChatFrame();
		if chatFrame then
			print("|cffCCCC88_Dev|r: Current chat frame:", chatFrame:GetName());
			CreateChatMenuItems(rootDescription, chatFrame);
		end
	end);
end

--[[****************************************************************************
  * Initialization                                                              *
  ****************************************************************************]]
NS:SetScript( "OnEvent", NS.OnEvent );
NS.SetupChatFrameMenu();
