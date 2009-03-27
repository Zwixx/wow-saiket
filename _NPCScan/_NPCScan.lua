--[[****************************************************************************
  * _NPCScan by Saiket                                                         *
  * _NPCScan.lua - Scans NPCs near you for specific rare NPC IDs.              *
  ****************************************************************************]]


local L = _NPCScanLocalization;
_NPCScanOptions = {
	IDs = { -- Keys must be lowercase, but don't have to match the NPC name
		-- Note: Tameable NPCs will be "found" if you encounter them as pets, so don't search for them.

		[ L[ "Time-Lost Proto Drake" ]:lower() ] = 32491;

		-- Northern Exposure (Northrend)
		[ L[ "Aotona" ]:lower() ] = 32481;
		[ L[ "Dirkee" ]:lower() ] = 32500;
		[ L[ "Griegen" ]:lower() ] = 32471;
		[ L[ "High Thane Jorfus" ]:lower() ] = 32501;
		[ L[ "Icehorn" ]:lower() ] = 32361;
		[ L[ "King Ping" ]:lower() ] = 32398;
		[ L[ "Old Crystalbark" ]:lower() ] = 32357;
		[ L[ "Putridus the Ancient" ]:lower() ] = 32487;
		[ L[ "Seething Hate" ]:lower() ] = 32429;
		[ L[ "Terror Spinner" ]:lower() ] = 32475;
		[ L[ "Vigdis the War Maiden" ]:lower() ] = 32386;
		[ L[ "Zul'drak Sentinel" ]:lower() ] = 32447;
		[ L[ "Crazed Indu'le Survivor" ]:lower() ] = 32409;
		[ L[ "Fumblub Gearwind" ]:lower() ] = 32358;
		[ L[ "Grocklar" ]:lower() ] = 32422;
		[ L[ "Hildana Deathstealer" ]:lower() ] = 32495;
		--[ L[ "King Krush" ]:lower() ] = 32485;
		--[ L[ "Loque'nahak" ]:lower() ] = 32517;
		[ L[ "Perobas the Bloodthirster" ]:lower() ] = 32377;
		[ L[ "Scarlet Highlord Daion" ]:lower() ] = 32417;
		[ L[ "Syreian the Bonecarver" ]:lower() ] = 32438;
		[ L[ "Tukemuth" ]:lower() ] = 32400;
		[ L[ "Vyragosa" ]:lower() ] = 32630;

		-- Bloody Rare (Outlands)
		[ L[ "Ambassador Jerrikar" ]:lower() ] = 18695;
		[ L[ "Chief Engineer Lorthander" ]:lower() ] = 18697;
		[ L[ "Collidus the Warp-Watcher" ]:lower() ] = 18694;
		[ L[ "Doomsayer Jurim" ]:lower() ] = 18686;
		[ L[ "Fulgorge" ]:lower() ] = 18678;
		[ L[ "Hemathion" ]:lower() ] = 18692;
		[ L[ "Marticar" ]:lower() ] = 18680;
		[ L[ "Morcrush" ]:lower() ] = 18690;
		[ L[ "Okrek" ]:lower() ] = 18685;
		[ L[ "Voidhunter Yar" ]:lower() ] = 18683;
		[ L[ "Bog Lurker" ]:lower() ] = 18682;
		[ L[ "Coilfang Emissary" ]:lower() ] = 18681;
		[ L[ "Crippler" ]:lower() ] = 18689;
		[ L[ "Ever-Core the Punisher" ]:lower() ] = 18698;
		--[ L[ "Goretooth" ]:lower() ] = 17144;
		[ L[ "Kraator" ]:lower() ] = 18696;
		[ L[ "Mekthorg the Wild" ]:lower() ] = 18677;
		--[ L[ "Nuramoc" ]:lower() ] = 20932;
		[ L[ "Speaker Mar'grom" ]:lower() ] = 18693;
		[ L[ "Vorakem Doomspeaker" ]:lower() ] = 18679;
	};
};


local me = CreateFrame( "Frame", "_NPCScan" );

local Tooltip = CreateFrame( "GameTooltip", "_NPCScanTooltip", me );
me.Tooltip = Tooltip

local IDs = {};
me.IDs = IDs;

me.IDMax = 0xFFFF; -- Largest ID that will fit in a GUID's 2-byte NPC ID field
me.UpdateRate = 0.1;




--[[****************************************************************************
  * Function: _NPCScan.Message                                                 *
  * Description: Prints a message in the default chat window.                  *
  ****************************************************************************]]
function me.Message ( Message, Color )
	if ( not Color ) then
		Color = NORMAL_FONT_COLOR;
	end
	DEFAULT_CHAT_FRAME:AddMessage( L.MESSAGE_FORMAT:format( Message ), Color.r, Color.g, Color.b );
end
--[[****************************************************************************
  * Function: _NPCScan.Alert                                                   *
  * Description: Dramatically prints a message and play a sound.               *
  ****************************************************************************]]
function me.Alert ( Message, Color )
	me.Message( Message, Color );
	PlaySoundFile( "sound\\event sounds\\event_wardrum_ogre.wav" );
	PlaySoundFile( "sound\\events\\scourge_horn.wav" );
	UIFrameFlash( LowHealthFrame, 0.5, 0.5, 6, false, 0.5 );
end


--[[****************************************************************************
  * Function: _NPCScan.TestID                                                  *
  * Description: Checks for a given NPC ID.                                    *
  ****************************************************************************]]
do
	local GUID;
	function me.TestID ( ID )
		GUID = ( "unit:0xF53000%04X000000" ):format( ID );
		Tooltip:SetOwner( WorldFrame, "ANCHOR_NONE" );
		Tooltip:SetHyperlink( GUID );
		if ( Tooltip:IsShown() ) then
			return Tooltip.Text:GetText();
		end
	end
end

--[[****************************************************************************
  * Function: _NPCScan.Add                                                     *
  * Description: Adds an NPC ID to scan for.                                   *
  ****************************************************************************]]
function me.Add ( Name, ID )
	assert( type( Name ) == "string", "Invalid argument #1 \"Name\" to _NPCScan.Add - string expected." );
	assert( tonumber( ID ), "Invalid argument #2 \"ID\" to _NPCScan.Add - number expected." );
	assert( ID >= 1 and ID <= me.IDMax, "Invalid argument #2 \"ID\" to _NPCScan.Add - Out of range." );

	local NameKey = Name:lower();
	if ( not _NPCScanOptions.IDs[ NameKey ] ) then
		local FoundName = me.TestID( ID );
		if ( FoundName ) then -- Already seen
			me.Message( L.ALREADY_CACHED_FORMAT:format( L.NAME_FORMAT:format( FoundName ) ), RED_FONT_COLOR );
		else
			IDs[ ID ] = true;
		end
		_NPCScanOptions.IDs[ NameKey ] = ID;
		return true;
	end
end
--[[****************************************************************************
  * Function: _NPCScan.Remove                                                  *
  * Description: Removes an NPC from the scanning list.                        *
  ****************************************************************************]]
function me.Remove ( Name )
	assert( type( Name ) == "string", "Invalid argument #1 \"Name\" to _NPCScan.Remove - string expected." );

	local NameKey = Name:lower();
	local ID = _NPCScanOptions.IDs[ NameKey ];
	if ( ID ) then
		IDs[ ID ] = nil;
		_NPCScanOptions.IDs[ NameKey ] = nil;
		return true;
	end
end


--[[****************************************************************************
  * Function: _NPCScan:OnUpdate                                                *
  * Description: Scans all NPCs and alerts if any are found.                   *
  ****************************************************************************]]
do
	local pairs = pairs;
	local Name;
	local LastUpdate = 0;
	function me:OnUpdate ( Elapsed )
		LastUpdate = LastUpdate + Elapsed;
		if ( LastUpdate >= me.UpdateRate ) then
			LastUpdate = 0;

			for ID in pairs( IDs ) do
				Name = me.TestID( ID );
				if ( Name ) then
					me.Alert( L.FOUND_FORMAT:format( Name ), GREEN_FONT_COLOR );
					me.Button.SetNPC( Name, ID );
					IDs[ ID ] = nil; -- Stop searching for this NPC
				end
			end
		end
	end
end
--[[****************************************************************************
  * Function: _NPCScan:ADDON_LOADED                                            *
  ****************************************************************************]]
function me:ADDON_LOADED ( _, AddOn )
	if ( AddOn:upper() == "_NPCSCAN" ) then
		me:UnregisterEvent( "ADDON_LOADED" );
		me.ADDON_LOADED = nil;

		-- Add all NPCs from options
		local CachedNames = {};
		for Name, ID in pairs( _NPCScanOptions.IDs ) do
			-- Don't add NPCs already in the cache
			local FoundName = me.TestID( ID );
			if ( FoundName ) then
				CachedNames[ #CachedNames + 1 ] = L.NAME_FORMAT:format( FoundName );
			else -- Add
				IDs[ ID ] = true;
			end
		end
		-- Print all cached names
		if ( next( CachedNames ) ) then
			table.sort( CachedNames );
			me.Message( L.ALREADY_CACHED_FORMAT:format( table.concat( CachedNames, L.NAME_SEPARATOR ) ) );
		end
	end
end
--[[****************************************************************************
  * Function: _NPCScan:PLAYER_ENTERING_WORLD                                   *
  ****************************************************************************]]
function me:PLAYER_ENTERING_WORLD ()
	-- Do not scan while in instances
	if ( IsInInstance() ) then
		self:Hide();
	else
		self:Show();
	end
end
--[[****************************************************************************
  * Function: _NPCScan:OnEvent                                                 *
  * Description: Global event handler.                                         *
  ****************************************************************************]]
do
	local type = type;
	function me:OnEvent ( Event, ... )
		if ( type( self[ Event ] ) == "function" ) then
			self[ Event ]( self, Event, ... );
		end
	end
end




--------------------------------------------------------------------------------
-- Function Hooks / Execution
-----------------------------

do
	me:SetScript( "OnUpdate", me.OnUpdate );
	me:SetScript( "OnEvent", me.OnEvent );
	me:RegisterEvent( "ADDON_LOADED" );
	me:RegisterEvent( "PLAYER_ENTERING_WORLD" );

	-- Add template text lines
	Tooltip.Text = Tooltip:CreateFontString( "$parentTextLeft1", nil, "GameTooltipText" );
	Tooltip:AddFontStrings(
		Tooltip.Text,
		Tooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" ) );
end