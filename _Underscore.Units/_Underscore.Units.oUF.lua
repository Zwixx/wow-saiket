--[[****************************************************************************
  * _Underscore.Units by Saiket                                                *
  * _Underscore.Units.oUF.lua - Adds custom skinned unit frames using oUF.     *
  ****************************************************************************]]


local Units = select( 2, ... );
local L = Units.L;
local NS = {};
Units.oUF = NS;

NS.FontNormal = CreateFont( "_UnderscoreUnitsOUFFontNormal" );
NS.FontTiny = CreateFont( "_UnderscoreUnitsOUFFontTiny" );
NS.FontMicro = CreateFont( "_UnderscoreUnitsOUFFontMicro" );

NS.StyleMeta = {};

local Colors = _Underscore.Colors;
setmetatable( Colors, { __index = oUF.colors; } );
setmetatable( Colors.power, { __index = oUF.colors.power; } );
Colors.class = oUF.colors.class;

--- Common range alpha properties shared by Range/SpellRange elements.
NS.Range = {
	insideAlpha = 1.0;
	outsideAlpha = 0.4;
};




--- Raises and shows all auras when moused over.
function NS:OnEnter ()
	if ( self.AuraMouseover ) then
		self.AuraMouseover:Show(); -- Show unfiltered auras
	end
	UnitFrame_OnEnter( self );
end
--- Raises and shows all auras using the secure AuraMouseover frame.
NS.OnEnterSecure = [=[
	self:GetAttribute( "AuraMouseoverSecure" ):Show( true );
]=];




do
	--- Colors and sets text for a bar representing a dead player.
	-- @param Label  New bar text.
	local function SetDead ( self, Label )
		self.bg:SetVertexColor( 0.2, 0.2, 0.2 );
		if ( self.Text ) then
			self.Text:SetText( Label );
			self.Text:SetTextColor( unpack( Colors.disconnected ) );
		end
	end
	local FEIGN_DEATH = GetSpellInfo( 28728 );
	--- Sets health bar text and color when health changes.
	function NS:HealthPostUpdate ( UnitID, Health, HealthMax )
		if ( UnitIsGhost( UnitID ) ) then
			self:SetValue( 0 );
			SetDead( self, L.GHOST );
		elseif ( UnitIsDead( UnitID ) and not UnitAura( UnitID, FEIGN_DEATH ) ) then
			self:SetValue( 0 );
			SetDead( self, L.DEAD );
		elseif ( not UnitIsConnected( UnitID ) ) then
			SetDead( self, L.OFFLINE );
		elseif ( self.Text ) then
			self.Text:SetFormattedText( L.NumberFormats[ self.TextLength ]( Health, HealthMax ) );
		end
	end
end
--- Sets power bar text and color when power changes.
function NS:PowerPostUpdate ( UnitID, Power, PowerMax )
	local IsDead = UnitIsDeadOrGhost( UnitID );
	if ( IsDead ) then
		self:SetValue( 0 );
	end
	if ( self.Text ) then
		local _, PowerType = UnitPowerType( UnitID );
		if ( IsDead or PowerType ~= "MANA" ) then
			self.Text:SetText();
		else
			self.Text:SetFormattedText( L.NumberFormats[ self.TextLength ]( Power, PowerMax ) );
		end
	end
end


--- Replaces the golden "?" model used for unknown units with a gray "?".
function NS:PortraitPostUpdate ()
	local Model = self:GetModel();
	if ( type( Model ) == "string" and Model:lower() == [[interface\buttons\talktomequestionmark.m2]] ) then
		self:SetModel( [[Interface\Buttons\TalkToMeQuestion_Grey.mdx]] );
	end
end


do
	--- Starts or stops showing all auras for an Aura icon frame.
	local function AuraShowAll ( Icons, ShowAll )
		if ( Icons ) then
			Icons.ShowAll = ShowAll;
			Icons:SetFrameStrata( ShowAll and Icons:GetParent():GetFrameStrata() or "LOW" );
		end
	end
	--- Keeps all auras visible while mousing over the unit and its auras.
	function NS:AuraMouseoverOnUpdate ()
		if ( not self:IsMouseOver() ) then
			self:Hide();
		end
	end
	--- Shows all auras when mousing over buff area.
	function NS:AuraMouseoverOnShow ()
		local Frame = self:GetParent();
		AuraShowAll( Frame.Buffs, true );
		AuraShowAll( Frame.Debuffs, true );
		Frame.Buffs:ForceUpdate(); -- Refilter buffs and debuffs
	end
	--- Refilters auras once mouse leaves buff area.
	function NS:AuraMouseoverOnHide ()
		local Frame = self:GetParent();
		AuraShowAll( Frame.Buffs, nil );
		AuraShowAll( Frame.Debuffs, nil );
		Frame.Buffs:ForceUpdate();
	end
end
--- Begin showing all auras once moused over the secure aura driver.
NS.AuraMouseoverSecureOnShow = [=[
	local Strata = self:GetParent():GetFrameStrata();
	Buffs:Hide( true ); -- Prevent full updates after every attribute change
	Buffs:SetAttribute( "filter", "HELPFUL" );
	Buffs:SetAttribute( "consolidateTo", nil );
	Buffs:Show( true );
	-- Note: Can't resize frame after calling RegisterAutoHide.
	self:SetHeight( self:GetParent():GetHeight() + self:GetAttribute( "Padding" )
		+ Buffs:GetHeight() + Debuffs:GetHeight() );
	Buffs:SetFrameStrata( Strata );
	Debuffs:SetFrameStrata( Strata );
	self:RegisterAutoHide( 0 ); -- Hide immediately OnLeave without enabling mouse input
]=];
--- Return to a minimal aura list once moused out of the secure aura driver.
NS.AuraMouseoverSecureOnHide = [=[
	self:Hide( true ); -- Force hide if unit frame was hidden
	Buffs:SetFrameStrata( "LOW" ); -- Don't allow auras to overlap other units
	Debuffs:SetFrameStrata( "LOW" );
	Buffs:Hide( true );
	Buffs:SetAttribute( "filter", "HELPFUL|PLAYER" ); -- Player's buffs only
	Buffs:SetAttribute( "consolidateTo", 1 );
	Buffs:Show( true );
]=];

--- Adjusts buff/debuff icons when they're created.
function NS:AuraPostCreateIcon ( Frame )
	_Underscore.SkinButtonIcon( Frame.icon );
	Frame.icon:SetNonBlocking( true );
	Frame.cd:SetReverse( true );

	-- Keep count from going off left side of screen for units on the edge
	Frame.count:ClearAllPoints();
	Frame.count:SetPoint( "BOTTOMLEFT" );
end
--- Resizes the buffs frame to fit all icons.
function NS:AuraPreSetPosition ()
	local Visible = self.visibleBuffs or self.visibleDebuffs;
	local IconsPerRow = max( 1, floor( self:GetWidth() / self.size + 0.5 ) );
	local Height = self.size * ceil( Visible / IconsPerRow );
	self:SetHeight( Height < 1e-3 and 1e-3 or Height );
end
do
	local UnitCanAttack = UnitCanAttack;
	--- Switches buff filter based on unit hostility.
	function NS:BuffPreUpdate ( UnitID )
		self.Hostile = UnitCanAttack( "player", UnitID ) or UnitCanAttack( "pet", UnitID );
		if ( self.ShowAll or self.Hostile ) then
			self.filter = "HELPFUL";
		else
			self.filter = "HELPFUL|PLAYER"; -- Show player's buffs cast on friendlies
		end
	end
	--- Switches debuff filter based on unit hostility.
	function NS:DebuffPreUpdate ( UnitID )
		if ( not self.ShowAll
			and ( UnitCanAttack( "player", UnitID ) or UnitCanAttack( "pet", UnitID ) )
		) then
			self.filter = "HARMFUL|PLAYER"; -- Show only your debuffs on hostiles
		else
			self.filter = "HARMFUL";
		end
	end
end
do
	local select = select;
	--- Hides consolidated buffs unless moused-over.
	function NS:BuffCustomFilter ( UnitID, _, ... )
		if ( not self.Hostile and not self.ShowAll ) then
			return not select( 10, ... ); -- Not ShouldConsolidate
		else
			return true;
		end
	end
end


--- Recolors the reputation bar on update.
function NS:ReputationPostUpdate ( _, _, _, _, _, StandingID )
	TEST=StandingID
	self:SetStatusBarColor( unpack( Colors.reaction[ StandingID ] ) );
end

--- Adjusts the rested experience bar segment.
function NS:ExperiencePostUpdate ( UnitID, Value, ValueMax )
	local RestedExperience = GetXPExhaustion();
	if ( RestedExperience ) then
		local Percent = ValueMax == 0 and math.huge or ( Value + RestedExperience ) / ValueMax;
		self.RestTexture:SetPoint( "RIGHT", self, "LEFT", self:GetWidth() * min( 1, Percent ), 0 );
		self.RestTexture:Show();
	else -- Not resting
		self.RestTexture:Hide();
	end
end
--- Updates the rested experience segment's size with the bar.
function NS:ExperienceOnSizeChanged ()
	NS.ExperiencePostUpdate( self, self.__owner.unit, self:GetValue(), ( select( 2, self:GetMinMaxValues() ) ) );
end


do
	local Classifications = {
		elite = "elite"; worldboss = "elite";
		rare = "rare"; rareelite = "rare";
	};
	--- Shows the rare/elite border for appropriate mobs.
	function NS:ClassificationUpdate ( Event, UnitID )
		if ( not Event or UnitIsUnit( UnitID, self.unit ) ) then
			local Type = Classifications[ UnitClassification( self.unit ) ];
			local Texture = self.Classification;
			if ( Type ) then
				Texture:Show();
				Texture:SetDesaturated( Type == "rare" );
			else
				Texture:Hide();
			end
		end
	end
end




-- Custom tags
do
	local Plus = { worldboss = true; elite = true; rareelite = true; };
	--- Tag that displays level/classification or group # in raid.
	function NS.TagClassification ( UnitID )
		if ( UnitID == "player" and IsInRaid() ) then
			return L.OUF_GROUP_FORMAT:format( ( select( 3, GetRaidRosterInfo( GetNumGroupMembers() ) ) ) );
		else
			local Level = UnitLevel( UnitID );
			if ( Plus[ UnitClassification( UnitID ) ] or Level ~= MAX_PLAYER_LEVEL or UnitLevel( "player" ) ~= MAX_PLAYER_LEVEL ) then
				local Color = Level < 0 and QuestDifficultyColors[ "impossible" ] or GetQuestDifficultyColor( Level );
				return L.OUF_CLASSIFICATION_FORMAT:format( Hex( Color ), _TAGS[ "smartlevel" ]( UnitID ) );
			end
		end
	end
end
--- Colored name with server name if different from player's.
function NS.TagName ( UnitID, Override )
	local Name, Server = UnitName( Override or UnitID );

	local Color;
	if ( UnitIsPlayer( UnitID ) ) then
		Color = _COLORS.class[ select( 2, UnitClass( UnitID ) ) ];
	elseif ( UnitPlayerControlled( UnitID ) or UnitPlayerOrPetInRaid( UnitID ) ) then -- Pet
		Color = Colors.Pet;
	else -- NPC
		Color = _COLORS.reaction[ UnitReaction( UnitID, "player" ) or 5 ];
	end

	return L.OUF_NAME_FORMAT:format( Hex( Color ), ( Server and Server ~= "" ) and Name.."-"..Server or Name );
end

oUF.Tags.Methods[ "_UnderscoreUnitsClassification" ] = NS.TagClassification;
oUF.Tags.Events[ "_UnderscoreUnitsClassification" ] = "GROUP_ROSTER_UPDATE "..oUF.Tags.Events[ "smartlevel" ];

oUF.Tags.Methods[ "_UnderscoreUnitsName" ] = NS.TagName;
oUF.Tags.Events[ "_UnderscoreUnitsName" ] = "UNIT_NAME_UPDATE UNIT_FACTION";




local LibSharedMedia = LibStub( "LibSharedMedia-3.0" );
local BarTexture = LibSharedMedia:Fetch( LibSharedMedia.MediaType.STATUSBAR, _Underscore.MediaBar );

--- Creates a common bar background.
-- @return Background texture.
local function CreateBarBackground ( self )
	local Background = self:CreateTexture( nil, "BACKGROUND" );
	Background:SetAllPoints( self );
	Background:SetTexture( BarTexture );
	return Background;
end
local CreateBar;
do
	local SetStatusBarColorBackup;
	--- Hook that sets bar text color along with actual bar color.
	local function SetStatusBarColor ( self, ... )
		if ( self.Text ) then
			self.Text:SetTextColor( ... );
		end
		if ( not self.bg ) then -- Not a reverse bar
			return SetStatusBarColorBackup( self, ... );
		end
	end
	--- Creates a common status bar.
	-- @param Parent  Parent frame.
	-- @param TextFont  Font object to use for bar text, or nil for no text label.
	-- @return StatusBar frame.
	function CreateBar ( Parent, TextFont )
		local Bar = CreateFrame( "StatusBar", nil, Parent );
		Bar:SetStatusBarTexture( BarTexture );
		if ( TextFont ) then
			Bar.Text = Bar:CreateFontString( nil, "OVERLAY", TextFont:GetName() );
			Bar.Text:SetJustifyV( "MIDDLE" );
		end
		if ( not SetStatusBarColorBackup ) then
			SetStatusBarColorBackup = Bar.SetStatusBarColor;
		end
		Bar.SetStatusBarColor = SetStatusBarColor;
		return Bar;
	end
end


--- Creates a common aura frame shared by buffs and debuffs.
local function CreateAuras ( Frame, Style )
	local Auras = CreateFrame( "Frame", nil, Frame );
	Auras:SetHeight( 1 );
	Auras:SetFrameStrata( "LOW" ); -- Don't allow auras to overlap other units
	Auras.initialAnchor = "TOPLEFT";
	Auras[ "growth-y" ] = "DOWN";
	Auras.size = Style.AuraSize;
	Auras.PostCreateIcon = NS.AuraPostCreateIcon;
	Auras.PreSetPosition = NS.AuraPreSetPosition;
	return Auras;
end
local CreateAurasSecure;
do
	--- Refreshes this button's buff tooltip.
	local function UpdateTooltip ( self )
		local UnitID, Slot = self:GetParent():GetAttribute( "unit" ), self:GetAttribute( "target-slot" );
		if ( Slot ) then -- Temporary enchant
			GameTooltip:SetInventoryItem( UnitID, Slot );
		else
			GameTooltip:SetUnitAura( UnitID, self:GetID(), self:GetAttribute( "filter" ) );
		end
	end
	--- Shows this button's aura tooltip on mouseover.
	local function ButtonOnEnter ( self )
		self:GetParent().Mouseover = self;
		GameTooltip:SetOwner( self, "ANCHOR_BOTTOMRIGHT" );
		return self:UpdateTooltip();
	end
	--- Hides this button's aura tooltip.
	local function ButtonOnLeave ( self )
		GameTooltip:Hide();
		self:GetParent().Mouseover = nil;
	end
	local UpdaterOnUpdate;
	do
		local ipairs, UnitAura = ipairs, UnitAura;
		local DebuffTypeColor = DebuffTypeColor;
		--- Updates all aura buttons' displays.
		function UpdaterOnUpdate ( Updater )
			local Header = Updater:GetParent();
			local IsBuff = Header:GetAttribute( "IsBuffs" );
			local UnitID, Filter = Header:GetAttribute( "unit" ), Header:GetAttribute( "filter" );
			for Index, Button in ipairs( Header ) do
				local Slot = Button:GetAttribute( "target-slot" );
				if ( Button:IsShown() ) then
					local Texture, Count, Type, Duration, Expires, _;
					if ( Slot ) then -- Temporary enchant
						Texture = GetInventoryItemTexture( UnitID, Slot );
						Type = ITEM_QUALITY_COLORS[ 4 ]; -- Epic
					else
						local TypeName;
						_, _, Texture, Count, TypeName, Duration, Expires = UnitAura( UnitID, Button:GetID(), Filter );
						if ( not IsBuff ) then -- Don't show buff types
							Type = DebuffTypeColor[ TypeName ] or DebuffTypeColor[ "none" ];
						end
					end

					Button.icon:SetTexture( Texture );
					if ( Duration and Duration > 0 ) then
						Button.cd:SetCooldown( Expires - Duration, Duration );
						Button.cd:Show();
					else
						Button.cd:Hide();
					end
					if ( Type ) then
						Button.overlay:SetVertexColor( Type.r, Type.g, Type.b );
						Button.overlay:Show();
					else
						Button.overlay:Hide();
					end
					Button.count:SetText( ( Count and Count > 1 ) and Count or nil );
				elseif ( not Slot ) then -- First hidden aura button
					break;
				end
			end

			-- Update tooltip if mouse was over an aura button
			if ( Header.Mouseover ) then
				return Header.Mouseover:UpdateTooltip();
			end
		end
	end
	--- Throttles aura updates to at most once per frame.
	local function UpdateButtons ( Header )
		return Header.Updater:Show();
	end
	--- Sets up this aura header's new button with common elements.
	local function SetupButton ( Header )
		local AuraMouseoverSecure = GetFrameHandleFrame( Header:GetAttribute( "AuraMouseoverSecure" ) );
		local Button = GetFrameHandleFrame( AuraMouseoverSecure:GetAttribute( "ButtonLatest" ) );
		if ( Button:GetAttribute( "IsEnchant" ) ) then
			tinsert( Header, 1, Button ); -- Guarantee enchant buttons get updated
		else
			Header[ #Header + 1 ] = Button;
		end
		Button:SetScript( "OnEnter", ButtonOnEnter );
		Button:SetScript( "OnLeave", ButtonOnLeave );
		Button.UpdateTooltip = UpdateTooltip;

		local Cooldown = CreateFrame( "Cooldown", nil, Button, "CooldownFrameTemplate" );
		Cooldown:Show();
		Button.cd = Cooldown;
		Cooldown:SetAllPoints();

		local Icon = Button:CreateTexture( nil, "BORDER" );
		Button.icon = Icon;
		Icon:SetAllPoints();

		local Count = Button:CreateFontString( nil, "OVERLAY" );
		Button.count = Count;
		Count:SetFontObject( NumberFontNormal );

		local Overlay = Button:CreateTexture( nil, "OVERLAY" );
		Button.overlay = Overlay;
		Overlay:SetAllPoints();
		Overlay:SetTexture( [[Interface\Buttons\UI-Debuff-Overlays]] );
		Overlay:SetTexCoord( 0.296875, 0.5703125, 0, 0.515625 );

		if ( Header:GetAttribute( "IsBuffs" ) ) then
			Button:RegisterForClicks( "RightButtonUp" ); -- Right click to cancel buff
		end
		NS:AuraPostCreateIcon( Button );
		return Header:UpdateButtons();
	end
	--- Sets up protected settings for this header's new button.
	local SetupButtonSecure = [=[
		local Header = self:GetParent();
		local AuraSize = Header:GetAttribute( "AuraSize" );
		self:SetWidth( AuraSize );
		self:SetHeight( AuraSize );

		if ( Header:GetAttribute( "IsBuffs" ) ) then
			self:SetAttribute( "type", "cancelaura" );
		end
		-- Note: Using AuraMouseoverSecure to store ButtonLatest so the SecureAuraHeader doesn't react to OnAttributeChanged.
		Header:GetAttribute( "AuraMouseoverSecure" ):SetAttribute( "ButtonLatest", self );
		return Header:CallMethod( "SetupButton" );
	]=];
	--- Styles aura buttons when auras change.
	local function HeaderOnEvent ( self, Event, UnitID )
		-- Only run if SecureAuraHeader_OnEvent would update
		if ( Event == "UNIT_AURA" and self:IsVisible() and UnitID == self:GetAttribute( "unit" ) ) then
			return self:UpdateButtons( self );
		end
	end
	--- Styles aura buttons when header options change.
	local function HeaderOnAttributeChanged ( Header )
		if ( Header:IsVisible() and not Header:GetAttribute( "_ignore" ) ) then
			return Header:UpdateButtons();
		end
	end
	--- @return A basic secure aura header frame.
	function CreateAurasSecure ( Frame, Style, UnitID )
		local Header = CreateFrame( "Frame", nil, Frame, "SecureAuraHeaderTemplate" );
		Header:SetAttribute( "AuraMouseoverSecure", Frame:GetAttribute( "AuraMouseoverSecure" ) );
		Header:SetAttribute( "AuraSize", Style.AuraSize );
		Header:SetAttribute( "unit", UnitID );
		Header:SetAttribute( "separateOwn", 1 ); -- Own auras first
		Header:SetAttribute( "sortMethod", "TIME" );
		Header:SetAttribute( "sortDirection", "+" );
		Header:SetAttribute( "point", "TOPLEFT" );
		Header:SetAttribute( "xOffset", Style.AuraSize );
		Header:SetAttribute( "yOffset", 0 );
		Header:SetAttribute( "wrapXOffset", 0 );
		Header:SetAttribute( "wrapYOffset", -Style.AuraSize );
		Header:SetAttribute( "minHeight", 1e-3 ); -- Near-zero to appear hidden
		local ButtonsPerRow = max( 1, floor( Frame:GetWidth() / Style.AuraSize + 0.5 ) );
		Header:SetAttribute( "wrapAfter", ButtonsPerRow );
		Header:SetAttribute( "initialConfigFunction", SetupButtonSecure );
		Header.SetupButton, Header.UpdateButtons = SetupButton, UpdateButtons;

		Header:HookScript( "OnAttributeChanged", HeaderOnAttributeChanged );
		Header:HookScript( "OnEvent", HeaderOnEvent );
		Header:HookScript( "OnShow", UpdateButtons );

		Header.Updater = CreateFrame( "Frame", nil, Header );
		Header.Updater:Hide();
		Header.Updater:SetScript( "OnUpdate", UpdaterOnUpdate );
		return Header;
	end
end


local CreateIcon;
do
	--- Updates icon anchors when one is shown or hidden at most once per frame.
	local function OnUpdate ( Icons )
		Icons:SetScript( "OnUpdate", nil );

		local Count, IconLast = 0;
		for _, Icon in ipairs( Icons ) do
			if ( Icon:IsShown() ) then
				Icon:ClearAllPoints();
				if ( IconLast ) then
					Icon:SetPoint( "LEFT", IconLast, "RIGHT" );
				else
					Icon:SetPoint( "TOPLEFT" );
				end
				Count, IconLast = Count + 1, Icon;
			end
		end
		Icons:SetWidth( max( 1e-3, Icons:GetHeight() * Count ) );
	end
	local ShowBackup, HideBackup;
	--- Hook to resize the icons list when one is shown.
	local function Show ( Icon, ... )
		Icon:GetParent():SetScript( "OnUpdate", OnUpdate );
		return ShowBackup( Icon, ... );
	end
	--- Hook to resize the icons list when one is hidden.
	local function Hide ( Icon, ... )
		Icon:GetParent():SetScript( "OnUpdate", OnUpdate );
		return HideBackup( Icon, ... );
	end
	--- Adds an icon texture to the expanding icons frame.
	function CreateIcon ( Icons )
		local Icon = Icons:CreateTexture( nil, "ARTWORK" );
		Icon:Hide();
		local Size = Icons:GetHeight();
		Icon:SetSize( Size, Size );
		Icons[ #Icons + 1 ] = Icon;

		-- Hooks to trigger resizing the icon list
		if ( not ShowBackup ) then
			ShowBackup, HideBackup = Icon.Show, Icon.Hide;
		end
		Icon.Show, Icon.Hide = Show, Hide;

		return Icon;
	end
end


local CreateDebuffHighlight;
if ( IsAddOnLoaded( "oUF_DebuffHighlight" ) ) then
	--- Mimics the Texture:SetVertexColor method to color all border textures.
	local function SetVertexColor ( self, ... )
		for Index = 1, #self do
			self[ Index ]:SetVertexColor( ... );
		end
	end
	--- Mimics the Texture:GetVertexColor method to get the color of the debuff textures.
	local function GetVertexColor ( self )
		return self[ 1 ]:GetVertexColor();
	end
	--- Creates a texture for one side of the debuff outline.
	-- @param Parent  Frame to parent new texture to.
	-- @param Point1  First anchor point.
	-- @param PointFrame  First anchor point frame.
	-- @param ...  Arguments for second anchor.
	-- @return New Texture object.
	local function CreateTexture( Parent, Point1, Point1Frame, ... )
		local Texture = Parent:CreateTexture( nil, "OVERLAY" );
		Texture:SetTexture( [[Interface\Buttons\WHITE8X8]] );
		Texture:SetPoint( Point1, Point1Frame );
		Texture:SetPoint( ... );
		return Texture;
	end
	--- Creates a border for oUF_DebuffHighlight between Parent and a containing frame Outer.
	-- @param Parent  Frame to outline and parent textures to.
	-- @param Outer  Containing region to anchor textures to.
	-- @return Table that implements Texture methods used by oUF_DebuffHighlight.
	function CreateDebuffHighlight ( Parent, Outer )
		local DebuffHighlight = {
			GetVertexColor = GetVertexColor;
			SetVertexColor = SetVertexColor;
			-- Four separate outline textures so faded frames blend correctly
			CreateTexture( Parent, "TOPLEFT", Outer,     "BOTTOMRIGHT", Parent, "TOPRIGHT" ), -- Top
			CreateTexture( Parent, "TOPRIGHT", Outer,    "BOTTOMLEFT", Parent, "BOTTOMRIGHT" ), -- Right
			CreateTexture( Parent, "BOTTOMRIGHT", Outer, "TOPLEFT", Parent, "BOTTOMLEFT" ), -- Bottom
			CreateTexture( Parent, "BOTTOMLEFT", Outer,  "TOPRIGHT", Parent, "TOPLEFT" ) -- Left
		};
		DebuffHighlight:SetVertexColor( 0, 0, 0, 0 ); -- Default color used when not debuffed
		return DebuffHighlight;
	end
end




--- Sets up a unit frame based on its style table.
-- @param Style  Properties table.
-- @param Frame  Unit frame to add to.
-- @param UnitID  Unit this frame represents.
function NS.StyleMeta.__call ( Style, Frame, UnitID )
	Frame.colors = Colors;
	Frame:SetAttribute( "toggleForVehicle", false );

	Frame:SetSize( Style.Width, Style.Height );
	Frame:SetScript( "OnEnter", NS.OnEnter );
	Frame:SetScript( "OnLeave", UnitFrame_OnLeave );

	-- Enable the right-click menu
	SecureUnitButton_OnLoad( Frame, UnitID, _Underscore.Units.ShowGenericMenu );
	Frame:RegisterForClicks( "LeftButtonUp", "RightButtonUp" );

	local Backdrop = _Underscore.Backdrop.Create( Frame );
	Frame:SetHighlightTexture( [[Interface\QuestFrame\UI-QuestTitleHighlight]] );
	Frame:GetHighlightTexture():SetAllPoints( Backdrop );
	local Background = Frame:CreateTexture( nil, "BACKGROUND" );
	Background:SetAllPoints();
	Background:SetTexture( 0, 0, 0 );

	local BarWidth = Style.Width;
	local Bars = CreateFrame( "Frame", nil, Frame );
	Frame.Bars = Bars;
	-- Portrait and overlapped elements
	if ( Style.PortraitSide ) then
		local Portrait = CreateFrame( "PlayerModel", nil, Frame );
		Frame.Portrait = Portrait;
		local Side = Style.PortraitSide;
		local Opposite = Side == "RIGHT" and "LEFT" or "RIGHT";
		Portrait:SetPoint( "TOP" );
		Portrait:SetPoint( "BOTTOM" );
		Portrait:SetPoint( Side );
		Portrait:SetWidth( Style.Height );
		Portrait.PostUpdate = NS.PortraitPostUpdate;
		BarWidth = BarWidth - Style.Height;

		local Classification = Portrait:CreateTexture( nil, "OVERLAY" );
		local Size = Style.Height * 1.35;
		Frame.Classification = Classification;
		Classification:SetPoint( "CENTER" );
		Classification:SetSize( Size, Size );
		Classification:SetTexture( [[Interface\AchievementFrame\UI-Achievement-IconFrame]] );
		Classification:SetTexCoord( 0, 0.5625, 0, 0.5625 );
		Classification:SetAlpha( 0.8 );
		tinsert( Frame.__elements, NS.ClassificationUpdate );
		Frame:RegisterEvent( "UNIT_CLASSIFICATION_CHANGED", NS.ClassificationUpdate );

		local RaidIcon = Portrait:CreateTexture( nil, "OVERLAY" );
		local Size = Style.Height / 2;
		Frame.RaidIcon = RaidIcon;
		RaidIcon:SetPoint( "CENTER" );
		RaidIcon:SetSize( Size, Size );

		if ( IsAddOnLoaded( "oUF_CombatFeedback" ) ) then
			local FeedbackText = Portrait:CreateFontString( nil, "OVERLAY", "NumberFontNormalLarge" );
			Frame.CombatFeedbackText = FeedbackText;
			FeedbackText:SetPoint( "CENTER" );
			FeedbackText.ignoreEnergize = true;
			FeedbackText.ignoreOther = true;
		end

		Bars:SetPoint( "TOP" );
		Bars:SetPoint( "BOTTOM" );
		Bars:SetPoint( Side, Portrait, Opposite );
		Bars:SetPoint( Opposite );
	else
		Bars:SetAllPoints();
	end


	-- Health bar
	local Health = CreateBar( Frame, Style.HealthText and Style.BarTextFont );
	Frame.Health = Health;
	Health:SetPoint( "TOPLEFT", Bars );
	Health:SetPoint( "RIGHT", Bars );
	Health:SetHeight( Style.Height * ( 1 - Style.PowerHeight - Style.ProgressHeight ) );
	Health:SetStatusBarColor( 0.1, 0.1, 0.1 );
	Health.bg = CreateBarBackground( Health );
	Health.bg:SetPoint( "TOPLEFT", Health:GetStatusBarTexture(), "TOPRIGHT" );
	Health.frequentUpdates = true;
	Health.colorTapping = true;
	Health.colorSmooth = true;
	Health.smoothGradient = Colors.HealthSmooth;

	if ( Health.Text ) then
		Health.Text:SetPoint( "TOPRIGHT", -2, 0 );
		Health.Text:SetPoint( "BOTTOM" );
		Health.Text:SetAlpha( 0.75 );
		Health.TextLength = Style.HealthText;
	end
	if ( IsAddOnLoaded( "oUF_Smooth" ) ) then
		Health.Smooth = true;
	end

	-- Healing prediction
	local MyBar = CreateBar( Health );
	MyBar:SetPoint( "TOPLEFT", Health:GetStatusBarTexture(), "TOPRIGHT" );
	MyBar:SetPoint( "BOTTOM", Health:GetStatusBarTexture() );
	MyBar:SetWidth( BarWidth );
	MyBar:SetAlpha( 0.75 );
	MyBar:SetStatusBarColor( unpack( Colors.reaction[ 8 ] ) );
	local OtherBar = CreateBar( Health );
	OtherBar:SetPoint( "TOPLEFT", MyBar:GetStatusBarTexture(), "TOPRIGHT" );
	OtherBar:SetPoint( "BOTTOM", MyBar:GetStatusBarTexture() );
	OtherBar:SetWidth( BarWidth );
	OtherBar:SetAlpha( 0.5 );
	OtherBar:SetStatusBarColor( unpack( Colors.reaction[ 8 ] ) );
	Frame.HealPrediction = {
		myBar = MyBar;
		otherBar = OtherBar;
		maxOverflow = math.huge;
	};

	Health.PostUpdate = NS.HealthPostUpdate;


	-- Power bar
	local Power = CreateBar( Frame, Style.PowerText and Style.BarTextFont );
	Frame.Power = Power;
	Power:SetPoint( "TOPLEFT", Health, "BOTTOMLEFT" );
	Power:SetPoint( "RIGHT", Bars );
	Power:SetHeight( Style.Height * Style.PowerHeight );
	CreateBarBackground( Power ):SetVertexColor( 0.14, 0.14, 0.14 );
	Power.frequentUpdates = true;
	Power.colorPower = true;

	if ( Power.Text ) then
		Power.Text:SetPoint( "TOPRIGHT", -2, 0 );
		Power.Text:SetPoint( "BOTTOM" );
		Power.Text:SetAlpha( 0.75 );
		Power.TextLength = Style.PowerText;
	end

	Power.PostUpdate = NS.PowerPostUpdate;


	-- Casting/rep/exp bar
	local Progress = CreateBar( Frame );
	Progress:SetPoint( "BOTTOMLEFT", Bars );
	Progress:SetPoint( "TOPRIGHT", Power, "BOTTOMRIGHT" );
	Progress:SetAlpha( 0.8 );
	Progress:Hide();
	local Background = CreateBarBackground( Progress );
	Background:SetParent( Bars ); -- Show background while hidden
	Background:SetVertexColor( 0.07, 0.07, 0.07 );
	if ( UnitID == "player" ) then
		if ( IsAddOnLoaded( "oUF_Experience" ) and UnitLevel( "player" ) ~= MAX_PLAYER_LEVEL and not IsXPUserDisabled() ) then
			Frame.Experience = Progress;
			Progress:SetStatusBarColor( unpack( Colors.Experience ) );
			Progress.PostUpdate = NS.ExperiencePostUpdate;
			Progress:SetScript( "OnSizeChanged", NS.ExperienceOnSizeChanged );
			Progress:Show();
			local Rest = Progress:CreateTexture( nil, "ARTWORK" );
			Progress.RestTexture = Rest;
			Rest:SetTexture( BarTexture );
			Rest:SetVertexColor( unpack( Colors.ExperienceRested ) );
			Rest:SetPoint( "TOPLEFT", Progress:GetStatusBarTexture(), "TOPRIGHT" );
			Rest:SetPoint( "BOTTOM" );
			Rest:Hide();
		elseif ( IsAddOnLoaded( "oUF_Reputation" ) ) then
			Frame.Reputation = Progress;
			Progress.PostUpdate = NS.ReputationPostUpdate;
		end
	elseif ( UnitID == "pet" ) then
		if ( IsAddOnLoaded( "oUF_Experience" ) and select( 2, UnitClass( "player" ) ) == "HUNTER" ) then
			Frame.Experience = Progress;
			Progress:SetStatusBarColor( unpack( Colors.Experience ) );
			Progress:Show();
		end
	else -- Castbar
		Frame.Castbar = Progress;
		Progress:SetStatusBarColor( unpack( Colors.Cast ) );

		local Time;
		if ( Style.CastTime ) then
			Time = Progress:CreateFontString( nil, "OVERLAY", NS.FontMicro:GetName() );
			Progress.Time = Time;
			Time:SetPoint( "BOTTOMRIGHT", -6, 0 );
		end

		local Text = Progress:CreateFontString( nil, "OVERLAY", NS.FontMicro:GetName() );
		Progress.Text = Text;
		Text:SetPoint( "BOTTOMLEFT", 2, 0 );
		if ( Time ) then
			Text:SetPoint( "RIGHT", Time, "LEFT" );
		else
			Text:SetPoint( "RIGHT", -2, 0 );
		end
		Text:SetJustifyH( "LEFT" );
	end


	-- Name
	local Name = Health:CreateFontString( nil, "OVERLAY", Style.NameFont:GetName() );
	Frame.Name = Name;
	Name:SetPoint( "LEFT", 2, 0 );
	if ( Health.Text ) then
		Name:SetPoint( "RIGHT", Health.Text, "LEFT" );
	else
		Name:SetPoint( "RIGHT", -2, 0 );
	end
	Name:SetJustifyH( "LEFT" );
	Frame:Tag( Name, "[_UnderscoreUnitsName]" );


	-- Info string
	local Info = Health:CreateFontString( nil, "OVERLAY", NS.FontTiny:GetName() );
	Frame.Info = Info;
	Info:SetPoint( "BOTTOM", 0, 2 );
	Info:SetPoint( "TOPLEFT", Name, "BOTTOMLEFT" );
	Info:SetJustifyV( "BOTTOM" );
	Info:SetAlpha( 0.8 );
	Frame:Tag( Info, "[_UnderscoreUnitsClassification]" );


	if ( Style.Auras ) then
		if ( UnitID == "player" or UnitID == "pet" ) then
			-- Secure aura frames to cancel buffs with
			local AuraMouseoverSecure = CreateFrame( "Frame", nil, Frame, "SecureHandlerShowHideTemplate" );
			Frame.AuraMouseoverSecure = AuraMouseoverSecure;
			AuraMouseoverSecure:Execute( [=[
				self:GetParent():SetAttribute( "AuraMouseoverSecure", self );
			]=] );
			AuraMouseoverSecure:WrapScript( Frame, "OnEnter", NS.OnEnterSecure );

			local Buffs = CreateAurasSecure( Frame, Style, UnitID );
			Buffs:SetAttribute( "template", "SecureActionButtonTemplate" );
			Buffs:SetAttribute( "includeWeapons", 1 );
			Buffs:SetAttribute( "weaponTemplate", "_UnderscoreUnitsEnchantTemplate" );
			Buffs:SetAttribute( "consolidateTo", 1 );
			Buffs:SetAttribute( "consolidateDuration", 0 ); -- Hide all consolidatable buffs
			Buffs:SetAttribute( "IsBuffs", true );
			local Padding = _Underscore.Backdrop.Padding; -- Can't anchor secure frame to Backdrop region
			Buffs:SetPoint( "TOPLEFT", Frame, "BOTTOMLEFT", 0, -Padding ); -- Don't go off left side of screen
			Buffs:SetPoint( "RIGHT", Frame, Padding, 0 );

			local Debuffs = CreateAurasSecure( Frame, Style, UnitID );
			Debuffs:SetAttribute( "template", "SecureFrameTemplate" );
			Debuffs:SetPoint( "TOPLEFT", Buffs, "BOTTOMLEFT" );
			Debuffs:SetPoint( "RIGHT", Buffs );
			Debuffs:SetAttribute( "filter", "HARMFUL" );

			AuraMouseoverSecure:Hide();
			local Padding = 8;
			AuraMouseoverSecure:SetAttribute( "Padding", Padding );
			AuraMouseoverSecure:SetPoint( "TOPLEFT", -Padding, 0 );
			AuraMouseoverSecure:SetPoint( "RIGHT", Padding, 0 );
			AuraMouseoverSecure:SetHeight( Frame:GetHeight() ); -- Resized when shown
			AuraMouseoverSecure:SetAttribute( "_onshow", NS.AuraMouseoverSecureOnShow );
			AuraMouseoverSecure:SetAttribute( "_onhide", NS.AuraMouseoverSecureOnHide );
			AuraMouseoverSecure:SetFrameRef( "Buffs", Buffs );
			AuraMouseoverSecure:SetFrameRef( "Debuffs", Debuffs );
			AuraMouseoverSecure:Execute( [=[
				Buffs, Debuffs = self:GetFrameRef( "Buffs" ), self:GetFrameRef( "Debuffs" );
				return self:RunAttribute( "_onhide" );
			]=] );
			Buffs:Show();
			Debuffs:Show();
		else -- Insecure aura frames
			local Buffs, Debuffs = CreateAuras( Frame, Style ), CreateAuras( Frame, Style );
			Frame.Buffs, Frame.Debuffs = Buffs, Debuffs;
		
			-- Buffs
			Buffs:SetPoint( "TOPLEFT", Backdrop, "BOTTOMLEFT" );
			Buffs:SetPoint( "RIGHT", Backdrop );
			Buffs.PreUpdate = NS.BuffPreUpdate;
			Buffs.CustomFilter = NS.BuffCustomFilter;

			-- Debuffs
			Debuffs:SetPoint( "TOPLEFT", Buffs, "BOTTOMLEFT" );
			Debuffs:SetPoint( "RIGHT", Buffs );
			Debuffs.showDebuffType = true;
			Debuffs.PreUpdate = NS.DebuffPreUpdate;

			-- Mouseover handler
			local AuraMouseover = CreateFrame( "Frame", nil, Frame );
			Frame.AuraMouseover = AuraMouseover;
			AuraMouseover:Hide();
			AuraMouseover:SetPoint( "TOPLEFT", -8, 0 ); -- Allow some leeway on the sides and bottom
			AuraMouseover:SetPoint( "BOTTOMRIGHT", Debuffs, "BOTTOMRIGHT", 8, -8 );
			AuraMouseover:SetScript( "OnUpdate", NS.AuraMouseoverOnUpdate );
			AuraMouseover:SetScript( "OnShow", NS.AuraMouseoverOnShow );
			AuraMouseover:SetScript( "OnHide", NS.AuraMouseoverOnHide );
		end
	end

	-- Debuff highlight
	if ( CreateDebuffHighlight and Style.DebuffHighlight ) then
		Frame.DebuffHighlight = CreateDebuffHighlight( Frame, Backdrop );
		Frame.DebuffHighlightAlpha = 1;
		Frame.DebuffHighlightFilter = Style.DebuffHighlight ~= "ALL";
	end

	-- Range fading
	Frame[ IsAddOnLoaded( "oUF_SpellRange" ) and "SpellRange" or "Range" ] = NS.Range;


	-- Icons
	local Icons = CreateFrame( "Frame", nil, Health );
	Frame.Icons = Icons;
	Icons:SetHeight( 16 );
	Icons:SetPoint( "TOPLEFT", 1, -1 );

	Frame.Leader = CreateIcon( Icons );
	Frame.MasterLooter = CreateIcon( Icons );
	if ( UnitID == "player" ) then
		Frame.Resting = CreateIcon( Icons );
	end
	Frame.LFDRole = CreateIcon( Icons );
end




NS.FontNormal:SetFont( [[Fonts\ARIALN.TTF]], 10, "OUTLINE" );
NS.FontTiny:SetFont( [[Fonts\ARIALN.TTF]], 8, "OUTLINE" );
NS.FontMicro:SetFont( [[Fonts\ARIALN.TTF]], 6 );

-- Defaults
NS.StyleMeta.__index = {
	Width = 130;
	Height = 50;

	PortraitSide = "RIGHT"; -- "LEFT"/"RIGHT"/false
	HealthText = "Small"; -- "Full"/"Small"/"Tiny"
	PowerText  = "Small"; -- Same as Health
	NameFont = NS.FontNormal;
	BarTextFont = NS.FontTiny;
	CastTime = true;
	AuraSize = 15;
	Auras = true;
	DebuffHighlight = true; -- "ALL" for all, true for cleansable debuffs only, or false for none

	PowerHeight = 0.25;
	ProgressHeight = 0.1;
};

oUF:RegisterStyle( "_UnderscoreUnits", setmetatable( {
	Width = 160;
}, NS.StyleMeta ) );
oUF:RegisterStyle( "_UnderscoreUnitsSelf", setmetatable( {
	PortraitSide = false;
	HealthText = "Full";
	PowerText  = "Full";
	CastTime = false;
	DebuffHighlight = "ALL";
}, NS.StyleMeta ) );
oUF:RegisterStyle( "_UnderscoreUnitsSmall", setmetatable( {
	PortraitSide = "LEFT";
	HealthText = "Tiny";
	NameFont = NS.FontTiny;
	CastTime = false;
	AuraSize = 10;
}, NS.StyleMeta ) );


-- Top row
oUF:SetActiveStyle( "_UnderscoreUnitsSelf" );
NS.Player = oUF:Spawn( "player", "_UnderscoreUnitsPlayer" );
NS.Player:SetPoint( "TOPLEFT", _Underscore.TopMargin, "BOTTOMLEFT" );

oUF:SetActiveStyle( "_UnderscoreUnits" );
NS.Target = oUF:Spawn( "target", "_UnderscoreUnitsTarget" );
NS.Target:SetPoint( "TOPLEFT", NS.Player, "TOPRIGHT", 28, 0 );

oUF:SetActiveStyle( "_UnderscoreUnitsSmall" );
NS.TargetTarget = oUF:Spawn( "targettarget", "_UnderscoreUnitsTargetTarget" );
NS.TargetTarget:SetPoint( "TOPLEFT", NS.Target, "TOPRIGHT", 2 * _Underscore.Backdrop.Padding, 0 );


-- Bottom row
oUF:SetActiveStyle( "_UnderscoreUnitsSmall" );
NS.Pet = oUF:Spawn( "pet", "_UnderscoreUnitsPet" );
NS.Pet:SetPoint( "TOPLEFT", NS.Player, "BOTTOMLEFT", 0, -56 );

oUF:SetActiveStyle( "_UnderscoreUnits" );
NS.Focus = oUF:Spawn( "focus", "_UnderscoreUnitsFocus" );
NS.Focus:SetPoint( "LEFT", NS.Target );
NS.Focus:SetPoint( "TOP", NS.Pet );

oUF:SetActiveStyle( "_UnderscoreUnitsSmall" );
NS.FocusTarget = oUF:Spawn( "focustarget", "_UnderscoreUnitsFocusTarget" );
NS.FocusTarget:SetPoint( "LEFT", NS.TargetTarget );
NS.FocusTarget:SetPoint( "TOP", NS.Pet );


if ( not _Underscore.IsAddOnLoadable( "_Underscore.Units.Arena" ) ) then
	-- Garbage collect initialization code
	NS.StyleMeta.__call = nil;
end