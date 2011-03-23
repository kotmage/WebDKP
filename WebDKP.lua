------------------------------------------------------------------------
-- WEB DKP
------------------------------------------------------------------------
-- An addon to help manage the dkp for a guild. The addon provides a 
-- list of the dkp of all players as well as an interface to add / deduct dkp 
-- points. 
-- The addon generates a log file which can then be uploaded to a companion 
-- website at www.webdkp.com
--
--
-- HOW THIS ADDON IS ORGANIZED:
-- The addon is grouped into a series of files which hold code for certain
-- functions. 
-- 
-- WebDKP			Code to handle start / shutdown / registering events
--					and GUI event handlers. This is the main entry point
--					of the addon and directs events to the functionality
--					in the other files
--
-- GroupFunctions	Methods the handle scanning the current group, updating
--					the dkp table to be show based on filters, sorting, 
--					and updating the gui with the current table
--
-- Announcements	Code handling announcements as they are echoed to the screen
--
-- WhisperDKP		Implementation of the Whisper DKP feature. 
--
-- Utility			Utility and helper methods. For example, methods
--					to find out a users guild or print something to the 
--					screen. 
--
-- AutoFill			Methods related to autofilling in item names when drops
--					Occur		
--
-- Bidding			Implements the automatted bidding feature for WebDKP. 
--					Contains code for the bidding GUI as well as handling
--					incoming bid whispers
--
-- Options			Implements a GUI for updating and changing addon options. 
--					This used to be in WebDKP but was branched to a seperate GUI
--					and file as options grew. 
------------------------------------------------------------------------

---------------------------------------------------
-- MEMBER VARIABLES
---------------------------------------------------
-- Sets the range of dkp that defines tiers.
-- Example, 50 would be:
-- 0-50 = teir 0
-- 51-100 = teir 1, etc
WebDKP_TierInterval = 50;   

-- Specify what filters are turned on and off. 1 = on, 0 = off
WebDKP_Filters = {
	["Druid"] = 1,
	["Hunter"] = 1,
	["Mage"] = 1,
	["Rogue"] = 1,
	["Shaman"] = 1,
	["Paladin"] = 1,
	["Priest"] = 1,
	["Warrior"] = 1,
	["Warlock"] = 1,
	["Group"] = 1
}

-- Specifies what classes compose different filter groups
WebDKP_FilterGroups = {
	["Casters"] = "Paladin Shaman Mage Warlock Priest Druid",
	["Melee"] = "Paladin Shaman Warrior Rogue Druid Hunter",
	["Healer"] = "Shaman Paladin Priest Druid",
	["Chain"] = "Shaman Hunter",
	["Cloth"] = "Warlock Mage Priest",
	["Leather"] = "Rogue Druid",
	["Plate"] = "Warrior Paladin"
}

-- Items to ignore for auto dkp. If they are picked up, auto dkp will not show
WebDKP_IgnoreItems = {
	"Badge of Justice",
	"Void Crystal",
}


-- The dkp table itself (This is loaded from the saved variables file)
-- Its structure is:
-- ["playerName"] = {
--		["dkp"] = 100,
--		["class"] = "ClassName",
--		["Selected"] = true/ false if they are selected in the gui
-- }
WebDKP_DkpTable = {};

-- Holds the list of users tables on the site. This is used for those guilds
-- who have multiple dkp tables for 1 guild. 
-- When there are multiple table names in this list a drop down will appear 
-- in the addon so a user can select which table they want to award dkp to
-- Its structure is: 
-- ["tableName"] = { 
--		["id"] = 1 (this is the tableid of the table on the webdkp site)
-- }
WebDKP_Tables = {};
selectedTableid = 1;


-- The dkp table that will be shown. This is filled programmatically
-- based on running through the big dkp table applying the selected filters
WebDKP_DkpTableToShow = {}; 

-- Keeps track of the current players in the group. This is filled programmatically
-- and is filled with Raid data if the player is in a raid, or party data if the
-- player is in a party. It is used to apply the 'Group' filter
WebDKP_PlayersInGroup = {};

-- Keeps track of the sorting options. 
-- Curr = current columen being sorted
-- Way = asc or desc order. 0 = desc. 1 = asc
WebDKP_LogSort = {
	["curr"] = 3,
	["way"] = 1 -- Desc
};

-- Additional user options and information that must be saved across reloads. 
-- Note, that this data is only here for quick reference. Many of these values are initalized
-- to default values in the Options.lua file. 
WebDKP_Options = {
	["AutofillEnabled"] = 1,		-- auto fill data. 0 = disabled. 1 = enabled. 
	["AutofillThreshold"] = 2,		-- What level of items should be picked up by auto fill. -1 = Gray, 4 = Orange
	["AutoAwardEnabled"] = 1,		-- Whether dkp awards should be recorded automatically if all data can be auto filled (user is still prompted)
	["SelectedTableId"] = 1,		-- The last table that was being looked at
	["MiniMapButtonAngle"] = 1,
	["BidAnnounceRaid"] = 0,		-- Announces when bids start / stop in raid warning
	["BidConfirmPopup"] = 1,		-- Displays a popup when a winning bid is determined so that the user can tweak how much to award
	["BidAllowNegativeBids"] = 0,	-- Whether or not to allow people to bid more dkp than they have
	["BidFixedBidding"] = 0,		-- Whether fixed bidding is enabled. With fixed bidding users say !need instead of bidding a specific amount. Winners (those with most dkp) are then deducted points based on the items cost in the loot table
	["BidNotifyLowBids"] = 0,		-- Tells people when they have bid lower than the highest bid so far
	["TimedAwardRepeat"] = 1,		-- Whether timed awards should repeat after they have finished
	["TimedAwardInProgress"] = false,-- Whether a timed award is in progress (0 = no, 1 = yes)
	["TimedAwardTimer"] = 0,		-- The current timer for a timed award (seconds). If a timed award is in progress and this reaches 0 an award must be given
	["TimedAwardTotalTime"] = 5,	-- How many minutes the timer started at.
	["TimedAwardDkp"] = 0,			-- How much DKP should be awarded for a timed award
	["TimedAwardMiniTimer"] = 0,	-- 1 = mini timer is shown, 0 = mini timer is hidden
}

-- User options that are syncronized with the website
WebDKP_WebOptions = {			
	["ZeroSumEnabled"] = 0,			-- Whether or not to use ZeroSum DKP settings
	["CombineAlts"] = 0	,			-- Whether or not alts and mains are combined and share dkp
}

WebDKP_Alts = {};					-- Holds list of alts in the game. Structure is: 
									-- ["AltName"] = "Main Name", 

local WebDKP_Loaded = false;		-- used to flag whether the addon has been loaded already (wow 2.0 seems to load it twice?)

---------------------------------------------------
-- INITILIZATION
---------------------------------------------------
-- ================================
-- On load setup the slash event that will toggle the gui
-- and register for some extra events
-- ================================
function WebDKP_OnLoad()


	if ( WebDKP_Loaded == false ) then
		WebDKP_Loaded = true;
		--register the slash event
		SlashCmdList["WEBDKP"] = WebDKP_ToggleGUI;
		SLASH_WEBDKP1 = "/webdkp";
			
		--register extra events
		this:RegisterEvent("PARTY_MEMBERS_CHANGED");			--so we can handle party changes
		this:RegisterEvent("RAID_ROSTER_UPDATE"); 
		this:RegisterEvent("ITEM_TEXT_READY");
		this:RegisterEvent("ADDON_LOADED");	
		this:RegisterEvent("CHAT_MSG_WHISPER");					--chat handles so we can look for webdkp commands			
		this:RegisterEvent("CHAT_MSG_LOOT");
		this:RegisterEvent("CHAT_MSG_PARTY");
		this:RegisterEvent("CHAT_MSG_RAID");
		this:RegisterEvent("CHAT_MSG_RAID_LEADER");
		this:RegisterEvent("CHAT_MSG_RAID_WARNING");
		this:RegisterEvent("ADDON_ACTION_FORBIDDEN");			--debugging - Blizzards new code likes to blame us for things we don't do :(
		
		WebDKP_OnEnable();
	end
end

-- ================================
-- Called when the addon is enabled. 
-- Takes care of basic startup tasks: hide certain forms, 
-- get the people currently in the group, etc.
-- ================================
function WebDKP_OnEnable()
	WebDKP_Frame:Hide();
	getglobal("WebDKP_FiltersFrame"):Show();
	getglobal("WebDKP_AwardDKP_Frame"):Hide();
	getglobal("WebDKP_AwardItem_Frame"):Hide();
	
	WebDKP_UpdatePlayersInGroup();
	WebDKP_UpdateTableToShow();
	
	-- place a hook on the chat frame so we can filter out our whispers
	WebDKP_Register_WhisperHook();
	
	-- place a hook on item shift+clicks so we can get item details -- MOD: 2.0+
	-- hooksecurefunc("SetItemRef",WebDKP_ItemChatClick);
	-- hooksecurefunc("HandleModifiedItemClick",  WebDKP_HandleModifiedItemClick);
end

-- ================================
-- Invoked when we recieve one of the requested events. 
-- Directs that event to the appropriate part of the addon
-- ================================
function WebDKP_OnEvent()
	if(event=="CHAT_MSG_WHISPER") then
		WebDKP_CHAT_MSG_WHISPER();
	elseif(event=="CHAT_MSG_PARTY" or event=="CHAT_MSG_RAID" or event=="CHAT_MSG_RAID_LEADER" or event=="CHAT_MSG_RAID_WARNING") then
		WebDKP_CHAT_MSG_PARTY_RAID();
	elseif(event=="PARTY_MEMBERS_CHANGED") then
		WebDKP_PARTY_MEMBERS_CHANGED();
	elseif(event=="RAID_ROSTER_UPDATE") then
		WebDKP_RAID_ROSTER_UPDATE();
	elseif(event=="ADDON_LOADED") then
		WebDKP_ADDON_LOADED();
	elseif(event=="CHAT_MSG_LOOT") then
		WebDKP_Loot_Taken();
	elseif(event=="ADDON_ACTION_FORBIDDEN") then
		WebDKP_Print(arg1.."  "..arg2);
	end
end

-- ================================
-- Invoked when addon finishes loading data from the saved variables file. 
-- Should parse the players options and update the gui.
-- ================================
function WebDKP_ADDON_LOADED()
	if( WebDKP_DkpTable == nil) then
		WebDKP_DkpTable = {};
	end
	
	--load up the last loot table that was being viewed
	WebDKP_Frame.selectedTableid = WebDKP_Options["SelectedTableId"];

	WebDKP_Options_Init(); -- load up the options to the options gui
	
	WebDKP_UpdateTableToShow(); --update who is in the table
	WebDKP_UpdateTable();       --update the gui
	
	-- set the mini map position
	WebDKP_MinimapButton_SetPositionAngle(WebDKP_Options["MiniMapButtonAngle"]);

end





-- ================================
-- Called on shutdown. Does nothing
-- ================================
function WebDKP_OnDisable()
    
end


---------------------------------------------------
-- EVENT HANDLERS (Party changed / gui toggled / etc.)
---------------------------------------------------

-- ================================
-- Called by slash command. Toggles gui. 
-- ================================
function WebDKP_ToggleGUI()
	-- self:Print("Should toggle gui now...")
	WebDKP_Refresh()
	if ( WebDKP_Frame:IsShown() ) then
		WebDKP_Frame:Hide();
	else
		WebDKP_Frame:Show();	
		WebDKP_Tables_DropDown_OnLoad();
	end
	
	-- WebDKP_Bid_ToggleUI();
	
end

-- ================================
-- Handles the master loot list being opened 
-- ================================
function WebDKP_OPEN_MASTER_LOOT_LIST()
    -- we don't do anything here because the addon should be
    -- usable by people who are not the master looter. 
    -- If someone wants to tweak this, however, this would be
    -- the area to start. 
end

-- ================================
-- Called when the party / raid configuration changes. 
-- Causes the list of current group memebers to be refreshed
-- so that filters will be ok
-- ================================
function WebDKP_PARTY_MEMBERS_CHANGED()
	WebDKP_UpdatePlayersInGroup();
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
end
function WebDKP_RAID_ROSTER_UPDATE()
	WebDKP_UpdatePlayersInGroup();
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
end

-- ================================
-- Handles an incoming whisper. Directs it to the modules
-- who are interested in it. 
-- ================================
function WebDKP_CHAT_MSG_WHISPER()
	WebDKP_WhisperDKP_Event();
	WebDKP_Bid_Event();
end

-- ================================
-- Event handler for all party and raid
-- chat messages. 
-- ================================
function WebDKP_CHAT_MSG_PARTY_RAID()
	WebDKP_Bid_Event();
end

---------------------------------------------------
-- GUI EVENT HANDLERS
-- (Handle events raised by the gui and direct
--  events to the other parts of the addon)
---------------------------------------------------
-- ================================
-- Called by the refresh button. Refreshes the people displayed 
-- in your party. 
-- ================================
function WebDKP_Refresh()
	WebDKP_UpdatePlayersInGroup();
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
end

-- ================================
-- Called when a player clicks on different tabs. 
-- Causes certain frames to be hidden and the appropriate
-- frame to be displayed
-- ================================
function WebDKP_Tab_OnClick()
	if ( this:GetID() == 1 ) then
		getglobal("WebDKP_FiltersFrame"):Show();
		getglobal("WebDKP_AwardDKP_Frame"):Hide();
		getglobal("WebDKP_AwardItem_Frame"):Hide();
	elseif ( this:GetID() == 2 ) then
		getglobal("WebDKP_FiltersFrame"):Hide();
		getglobal("WebDKP_AwardDKP_Frame"):Show();
		getglobal("WebDKP_AwardItem_Frame"):Hide();
	elseif (this:GetID() == 3 ) then
		getglobal("WebDKP_FiltersFrame"):Hide();
		getglobal("WebDKP_AwardDKP_Frame"):Hide();
		getglobal("WebDKP_AwardItem_Frame"):Show();
	elseif (this:GetID() == 4 ) then
		getglobal("WebDKP_FiltersFrame"):Hide();
		getglobal("WebDKP_AwardDKP_Frame"):Hide();
		getglobal("WebDKP_AwardItem_Frame"):Hide();
	end 
	PlaySound("igCharacterInfoTab");
end

-- ================================
-- Selects all players in the dkp table and updates 
-- table display
-- ================================
function WebDKP_SelectAll()
	local tableid = WebDKP_GetTableid();
	for k, v in pairs(WebDKP_DkpTable) do
		if ( type(v) == "table" ) then
			local playerName = k; 
			local playerClass = v["class"];
			local playerDkp = v["dkp"..tableid];
			if ( playerDkp == nil ) then 
				v["dkp"..tableid] = 0;
				playerDkp = 0;
			end
			local playerTier = floor((playerDkp-1)/WebDKP_TierInterval);
			if (WebDKP_ShouldDisplay(playerName, playerClass, playerDkp, playerTier)) then
				WebDKP_DkpTable[playerName]["Selected"] = true;
			else
				WebDKP_DkpTable[playerName]["Selected"] = false;
			end
		end
	end
	WebDKP_UpdateTable();
end

-- ================================
-- Deselect all players and update table display
-- ================================
function WebDKP_UnselectAll()
	for k, v in pairs(WebDKP_DkpTable) do
		if ( type(v) == "table" ) then
			local playerName = k; 
			WebDKP_DkpTable[playerName]["Selected"] = false;
		end
	end
	WebDKP_UpdateTable();
end

---------------------------------------------------
-- FILTERS
-- The following methods are all related to filters and filter groups as 
-- seen on the filters tab. 
-- A filter is an individual class that affects what people are displayed in the table
-- (Example: Hunter, Mage, Warrior)
-- A filter group is a general category that is composed up of other filters (Example: Caster, Melee, etc)
-- The following methods must handle the user checking or unchecking class filters as well as filter 
-- groups. 
---------------------------------------------------

-- ================================
-- Checks whether any of the filter groups (Caster, Melee, etc.) 
-- should be either checked or unchecked based on the current state of the
-- checked classes. Example - Casters should only be checked if druid, mage, etc are
-- currently on. This method should be called whenever one of the _class_ filters change
-- ================================
function WebDKP_UpdateFilterGroupsCheckedState() 
	-- run through each of the filter groups
	for key, value in pairs(WebDKP_FilterGroups) do
		if ( value ~= nil ) then
			
			local checkbox = getglobal("WebDKP_FiltersFrameClass"..key);
			if (checkbox ~= nil ) then
				-- if all its filter are on, go ahead and check it, otherwise uncheck it
				local allFiltersOn = WebDKP_AllFiltersOn(value);
				if ( allFiltersOn == true ) then
					checkbox:SetChecked(1);
				else
					checkbox:SetChecked(0);
				end
			end
		end
	end
end

-- ================================
-- Runs through the list of all currently checked off _filter groups_
-- and makes sure all of the ones that are checked have their appropriate
-- classes displayed. This is called whenever a user unchecks on of the other
-- group filters to make sure that it doesn't interfere with other group filters that
-- might be checked
-- ================================
function WebDKP_ReinforceCheckedFilterGroups()
	-- run through each of the filter groups
	for key, value in pairs(WebDKP_FilterGroups) do
		if ( value ~= nil ) then
			local checkbox = getglobal("WebDKP_FiltersFrameClass"..key);
			if (checkbox ~= nil ) then
				local checked = checkbox:GetChecked();
				if ( checked == 1 ) then
					WebDKP_SetFilterGroupState(value,1);
				end
			end
		end
	end
end

-- ================================
-- Called when the user clicks on a filter checkbox. 
-- Changes the filter setting and updates table
-- ================================
function WebDKP_ToggleFilter(filterName)
	WebDKP_Filters[filterName] = abs(WebDKP_Filters[filterName]-1);
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
	WebDKP_UpdateFilterGroupsCheckedState();
end

-- ================================
-- Called when user clicks on 'check all'
-- Sets all filters to on and updates table display
-- ================================
function WebDKP_CheckAllFilters()
	WebDKP_SetFilterState("Druid",1);
	WebDKP_SetFilterState("Hunter",1);
	WebDKP_SetFilterState("Mage",1);
	WebDKP_SetFilterState("Rogue",1);
	WebDKP_SetFilterState("Shaman",1);
	WebDKP_SetFilterState("Paladin",1);
	WebDKP_SetFilterState("Priest",1);
	WebDKP_SetFilterState("Warrior",1);
	WebDKP_SetFilterState("Warlock",1);
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
	WebDKP_UpdateFilterGroupsCheckedState();
end

-- ================================
-- Called when user clicks on 'uncheck all'
-- Sets all filters to off and updates table display
-- ================================
function WebDKP_UncheckAllFilters()
	WebDKP_SetFilterState("Druid",0);
	WebDKP_SetFilterState("Hunter",0);
	WebDKP_SetFilterState("Mage",0);
	WebDKP_SetFilterState("Rogue",0);
	WebDKP_SetFilterState("Shaman",0);
	WebDKP_SetFilterState("Paladin",0);
	WebDKP_SetFilterState("Priest",0);
	WebDKP_SetFilterState("Warrior",0);
	WebDKP_SetFilterState("Warlock",0);
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
	WebDKP_UpdateFilterGroupsCheckedState();
end

-- ================================
-- An event handler for clicking on the filter buttons that cover
-- groups of classes instead of one class in particular. (For example, Casters, Healers, etc).
-- When this is called it must toggle the entire group from either being on or off. 
-- GroupCheckboxName = the name of the group checkbox in the gui. (Example: "Casters" "Healers")
-- ================================
function WebDKP_ToggleFilterGroup(groupCheckboxName) 
	local filters = WebDKP_FilterGroups[groupCheckboxName]; -- get what filters this group is tied to
	-- look at its checkbox to determine if we are toggling on or off
	local checkbox = getglobal("WebDKP_FiltersFrameClass"..groupCheckboxName);
	local checked = checkbox:GetChecked();
	if ( checked == 1 ) then
		WebDKP_SetFilterGroupState(filters, 1);
	else
		WebDKP_SetFilterGroupState(filters, 0);
	end
	--update the table to show the new changes
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
	-- update what filter groups are checked as a result of these changes
	WebDKP_ReinforceCheckedFilterGroups();
	--WebDKP_UpdateFilterGroupsCheckedState();
end

-- ================================
-- A helper method that returns true if all of the passed filters are currently
-- on. Filters parameter takes the form of a string with all the class filter names
-- combined. Example ("Druid Hunter Mage")
-- ================================
function WebDKP_AllFiltersOn(filters) 
	-- find out what filters were passed by doing string searches
	local filter = {};  
	filter["Druid"] = string.find(string.lower(filters), "druid");
	filter["Hunter"] = string.find(string.lower(filters), "hunter");
	filter["Mage"]= string.find(string.lower(filters), "mage");
	filter["Rogue"] = string.find(string.lower(filters), "rogue");
	filter["Shaman"] = string.find(string.lower(filters), "shaman");
	filter["Paladin"] = string.find(string.lower(filters), "paladin");
	filter["Priest"] = string.find(string.lower(filters), "priest");
	filter["Warrior"] = string.find(string.lower(filters), "warrior");
	filter["Warlock"] = string.find(string.lower(filters), "warlock");
	-- run through all of these filters and see if they are all turned on
	local allTurnedOn = true; -- assume yes until proven otherwise.
	for key, value in pairs(filter) do
		if ( value ~= nil ) then
			if ( WebDKP_Filters[key] == 0 ) then
				allTurnedOn = false;
			end
		end
	end
	return allTurnedOn;
end

-- ================================
-- Updates the filter state for many filters at once.
-- Filters is a simple string that contains all the classes to set to the new
-- state. (Example:  HunterMageRogue) while newState specifies whether to check 
-- or uncheck that filter (1 = on, 0 = off)
-- ================================
function WebDKP_SetFilterGroupState(filters,newState)
	-- find out what filters were passed by doing string searches
	local filter = {};  
	filter["Druid"] = string.find(string.lower(filters), "druid");
	filter["Hunter"] = string.find(string.lower(filters), "hunter");
	filter["Mage"]= string.find(string.lower(filters), "mage");
	filter["Rogue"] = string.find(string.lower(filters), "rogue");
	filter["Shaman"] = string.find(string.lower(filters), "shaman");
	filter["Paladin"] = string.find(string.lower(filters), "paladin");
	filter["Priest"] = string.find(string.lower(filters), "priest");
	filter["Warrior"] = string.find(string.lower(filters), "warrior");
	filter["Warlock"] = string.find(string.lower(filters), "warlock");
	-- for any of the filters passed, set their new state
	for key, value in pairs(filter) do
		if ( value ~= nil ) then
			WebDKP_SetFilterState(key, newState);
		end
	end
end

-- ================================
-- Small helper method for filters - updates
-- checkbox state and updates filter setting in data structure
-- ================================
function WebDKP_SetFilterState(filter,newState)
	local checkBox = getglobal("WebDKP_FiltersFrameClass"..filter);
	checkBox:SetChecked(newState);
	WebDKP_Filters[filter] = newState;
end




---------------------------------------------------
-- TABLE GUI EVENTS
-- The following methods are related to GUI events generated by the dkp table. 
-- This includes mouse overs for the rows, selecting players, and sorting columns.
---------------------------------------------------

-- ================================
-- Called when a player clicks on a column header on the table
-- Changes the sorting options / asc&desc. 
-- Causes the table display to be refreshed afterwards
-- so the player instantly sees changes
-- ================================
function WebDPK2_SortBy(id)
	if ( WebDKP_LogSort["curr"] == id ) then
		WebDKP_LogSort["way"] = abs(WebDKP_LogSort["way"]-1);		-- toggles between 1 and 0
	else
		WebDKP_LogSort["curr"] = id;
		if( id == 1) then
			WebDKP_LogSort["way"] = 0;
		elseif ( id == 2 ) then
			WebDKP_LogSort["way"] = 0;
		elseif ( id == 3 ) then
			WebDKP_LogSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
		else
			WebDKP_LogSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
		end
		
	end
	-- update table so we can see sorting changes
	WebDKP_UpdateTable();
end

-- ================================
-- Called when mouse goes over a dkp line entry. 
-- If that player is not selected causes that row
-- to become 'highlighted'
-- ================================
function WebDKP_HandleMouseOver()
	local playerName = getglobal(this:GetName().."Name"):GetText();
	if( not WebDKP_DkpTable[playerName]["Selected"] ) then
		getglobal(this:GetName() .. "Background"):SetVertexColor(0.2, 0.2, 0.7, 0.5);
	end
end

-- ================================
-- Called when a mouse leaes a dkp line entry. 
-- If that player is not selected, causes that row
-- to return to normal (none highlighted)
-- ================================
function WebDKP_HandleMouseLeave()
	local playerName = getglobal(this:GetName().."Name"):GetText();
	if( not WebDKP_DkpTable[playerName]["Selected"] ) then
		getglobal(this:GetName() .. "Background"):SetVertexColor(0, 0, 0, 0);
	end
end

-- ================================
-- Called when the user clicks on a player entry. Causes 
-- that entry to either become selected or normal
-- and updates the dkp table with the change
-- ================================
function WebDKP_SelectPlayerToggle()
	local playerName = getglobal(this:GetName().."Name"):GetText();
	if( WebDKP_DkpTable[playerName]["Selected"] ) then
		WebDKP_DkpTable[playerName]["Selected"] = false;
		getglobal(this:GetName() .. "Background"):SetVertexColor(0.2, 0.2, 0.7, 0.5);
	else
		WebDKP_DkpTable[playerName]["Selected"] = true;
		getglobal(this:GetName() .. "Background"):SetVertexColor(0.1, 0.1, 0.9, 0.8);
	end
end


---------------------------------------------------
-- MULTIPLE TABLES DROP DOWN
-- The following methods are related to multiple tables drop down
-- that allows users to select which table they want to work with 
-- (Only exists if the user has created multiple tables on WebDkp.com)
---------------------------------------------------

-- ================================
-- Invoked when the gui loads up the drop down list of 
-- available dkp tables. 
-- ================================
function WebDKP_Tables_DropDown_OnLoad()
	UIDropDownMenu_Initialize(WebDKP_Tables_DropDown, WebDKP_Tables_DropDown_Init);
	
	local numTables = WebDKP_GetTableSize(WebDKP_Tables)
	if ( WebDKP_Tables == nil or numTables==0 or numTables==1) then
		WebDKP_Tables_DropDown:Hide();
	else
		WebDKP_Tables_DropDown:Show();
	end
end
-- ================================
-- Invoked when the drop down list of available tables
-- needs to be redrawn. Populates it with data 
-- from the tables data structure and sets up an 
-- event handler
-- ================================
function WebDKP_Tables_DropDown_Init()
	if( WebDKP_Frame.selectedTableid == nil ) then
		WebDKP_Frame.selectedTableid = 1;
	end
	local info;
	local selected = "";
	if ( WebDKP_Tables ~= nil and next(WebDKP_Tables)~=nil ) then
		for key, entry in pairs(WebDKP_Tables) do
			if ( type(entry) == "table" ) then
				info = { };
				info.text = key;
				info.value = entry["id"]; 
				info.func = WebDKP_Tables_DropDown_OnClick;
				if ( entry["id"] == WebDKP_Frame.selectedTableid ) then
					info.checked = ( entry["id"] == WebDKP_Frame.selectedTableid );
					selected = info.text;
				end
				UIDropDownMenu_AddButton(info);
			end
		end
	end
	UIDropDownMenu_SetSelectedName(WebDKP_Tables_DropDown, selected );
	UIDropDownMenu_SetWidth(200, WebDKP_Tables_DropDown);
end

-- ================================
-- Called when the user switches between
-- a different dkp table.
-- ================================
function WebDKP_Tables_DropDown_OnClick()
	WebDKP_Frame.selectedTableid = this.value;
	WebDKP_Options["SelectedTableId"] = this.value; 
	WebDKP_Tables_DropDown_Init();
	WebDKP_UpdateTableToShow(); --update who is in the table
	WebDKP_UpdateTable();       --update the gui
end




---------------------------------------------------
-- MINIMAP SCROLLING CODE
-- The following code handles the minimap icon that can be dragged. 
-- Code is based off of examples from Outfitter and the WoWWiki
---------------------------------------------------

-- ================================
-- Called when the user presses the mouse button down on the
-- mini map button. Remembers that position in case they
-- attempt to start dragging
-- ================================
function WebDKP_MinimapButton_MouseDown()
	-- Remember where the cursor was in case the user drags
	
	local	vCursorX, vCursorY = GetCursorPosition();
	
	vCursorX = vCursorX / this:GetEffectiveScale();
	vCursorY = vCursorY / this:GetEffectiveScale();
	
	WebDKP_MinimapButton.CursorStartX = vCursorX;
	WebDKP_MinimapButton.CursorStartY = vCursorY;
	
	local	vCenterX, vCenterY = WebDKP_MinimapButton:GetCenter();
	local	vMinimapCenterX, vMinimapCenterY = Minimap:GetCenter();
	
	WebDKP_MinimapButton.CenterStartX = vCenterX - vMinimapCenterX;
	WebDKP_MinimapButton.CenterStartY = vCenterY - vMinimapCenterY;
end

-- ================================
-- Called when the user starts to drag. Shows a frame that is registered
-- to recieve on update signals, we can then have its event handler
-- check to see the current mouse position and update the mini map button
-- correctly
-- ================================
function WebDKP_MinimapButton_DragStart()
	WebDKP_MinimapButton.IsDragging = true;
	WebDKP_UpdateFrame:Show();
end

-- ================================
-- Users stops dragging. Ends the timer
-- ================================
function WebDKP_MinimapButton_DragEnd()
	WebDKP_MinimapButton.IsDragging = false;
	WebDKP_UpdateFrame:Hide();
end

-- ================================
-- Updates the position of the mini map button. Should be called
-- via the on update method of the update frame
-- ================================
function WebDKP_MinimapButton_UpdateDragPosition()
	-- Remember where the cursor was in case the user drags
	local	vCursorX, vCursorY = GetCursorPosition();
	
	vCursorX = vCursorX / this:GetEffectiveScale();
	vCursorY = vCursorY / this:GetEffectiveScale();
	
	local	vCursorDeltaX = vCursorX - WebDKP_MinimapButton.CursorStartX;
	local	vCursorDeltaY = vCursorY - WebDKP_MinimapButton.CursorStartY;
	
	--
	
	local	vCenterX = WebDKP_MinimapButton.CenterStartX + vCursorDeltaX;
	local	vCenterY = WebDKP_MinimapButton.CenterStartY + vCursorDeltaY;
	
	-- Calculate the angle
	
	local	vAngle = math.atan2(vCenterX, vCenterY);
	
	-- Set the new position
	
	WebDKP_MinimapButton_SetPositionAngle(vAngle);
end

-- ================================
-- Helper method. Helps restrict a given angle from occuring within a restricted angle
-- range. Returns where the angle should be pushed to - before or after the resitricted
-- range. Used to block the minimap button from appearing behind/above the default ui buttons
-- ================================
function WebDKP_RestrictAngle(pAngle, pRestrictStart, pRestrictEnd)
	if ( pAngle == nil ) then
		return pRestrictStart;
	end
	if ( pRestrictStart == nil or pRestrictStart == nil) then
		return pAngle;
	end

	if pAngle <= pRestrictStart
	or pAngle >= pRestrictEnd then
		return pAngle;
	end
	
	local	vDistance = (pAngle - pRestrictStart) / (pRestrictEnd - pRestrictStart);
	
	if vDistance > 0.5 then
		return pRestrictEnd;
	else
		return pRestrictStart;
	end
end

-- ================================
-- Sets the position of the mini map button based on the passed angle. 
-- Restricts the button from appear over any of the default ui buttons. 
-- ================================
function WebDKP_MinimapButton_SetPositionAngle(pAngle)
	local	vAngle = pAngle;
	
	-- Restrict the angle from going over the date/time icon or the zoom in/out icons
	
	local	vRestrictedStartAngle = nil;
	local	vRestrictedEndAngle = nil;
	
	if GameTimeFrame:IsVisible() then
		if MinimapZoomIn:IsVisible()
		or MinimapZoomOut:IsVisible() then
			vAngle = WebDKP_RestrictAngle(vAngle, 0.4302272732931596, 2.930420793963121);
		else
			vAngle = WebDKP_RestrictAngle(vAngle, 0.4302272732931596, 1.720531504573905);
		end
		
	elseif MinimapZoomIn:IsVisible()
	or MinimapZoomOut:IsVisible() then
		vAngle = WebDKP_RestrictAngle(vAngle, 1.720531504573905, 2.930420793963121);
	end
	
	-- Restrict it from the tracking icon area
	
	vAngle = WebDKP_RestrictAngle(vAngle, -1.290357134304173, -0.4918423429923585);
	
	--
	
	local	vRadius = 80;
	
	vCenterX = math.sin(vAngle) * vRadius;
	vCenterY = math.cos(vAngle) * vRadius;
	
	WebDKP_MinimapButton:SetPoint("CENTER", "Minimap", "CENTER", vCenterX - 1, vCenterY - 1);
	
	WebDKP_Options["MiniMapButtonAngle"] = vAngle;
	--gOutfitter_Settings.Options.MinimapButtonAngle = vAngle;
end

-- ================================
-- Event handler for the update frame. Updates the minimap button
-- if it is currently being dragged. 
-- ================================
function WebDKP_OnUpdate(elapsed)
	if WebDKP_MinimapButton.IsDragging then
		WebDKP_MinimapButton_UpdateDragPosition();
	end
end


-- ================================
-- Initializes the minimap drop down
-- ================================
function WebDKP_MinimapDropDown_OnLoad()
	UIDropDownMenu_SetAnchor(-2, -20, this, "TOPRIGHT", this:GetName(), "TOPLEFT");
	UIDropDownMenu_Initialize(this, WebDKP_MinimapDropDown_Initialize);
end

-- ================================
-- Adds buttons to the minimap drop down
-- ================================
function WebDKP_MinimapDropDown_Initialize()
	WebDKP_Add_MinimapDropDownItem("DKP Table",WebDKP_ToggleGUI);
	WebDKP_Add_MinimapDropDownItem("Bidding",WebDKP_Bid_ToggleUI);
	WebDKP_Add_MinimapDropDownItem("Timed Awards",WebDKP_TimedAward_ToggleUI);
	WebDKP_Add_MinimapDropDownItem("Options",WebDKP_Options_ToggleUI);
	WebDKP_Add_MinimapDropDownItem("Help",WebDKP_Help_ToggleGUI);
end

-- ================================
-- Helper method that adds individual entries into the minimap drop down
-- menu.
-- ================================
function WebDKP_Add_MinimapDropDownItem(text, eventHandler)
	local info = { };
	info.text = text;
	info.value = text; 
	info.owner = this;
	info.func = eventHandler;
	UIDropDownMenu_AddButton(info);
end


-- ================================
-- Helper method. Called whenever a player clicks on item text. 
-- Should autofill this item name into any appropriate gui edit box. 
-- ================================
function WebDKP_ItemChatClick(link, text, button)
	
	-- do a search for 'player'. If it can be found... this is a player link, not an item link. It can be ignored
	local idx = strfind(text, "player");
	
	if( idx == nil ) then
	
		-- check to see if the bidding frame wants to do anything with the information
		WebDKP_Bid_ItemChatClick(link, text, button);
		
		-- put the item text into the award editbox as long as the table frame is visible
		if ( IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then
			
			-- WebDKP_Print("modifier was down");
		
			local _,itemName,_ = WebDKP_GetItemInfo(link); 
			WebDKP_AwardItem_FrameItemName:SetText(itemName);
		end
	end
end

-- ================================
-- Helper method. Called whenever a player clicks on item boxs (from loot window, etc)
-- Should autofill this item name into any appropriate gui edit box. 
-- ================================
function WebDKP_HandleModifiedItemClick(item) 
	
	
	WebDKP_Bid_ItemChatClick(item, nil, nil);
	
	if ( IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) then
		local _,itemName,_ = WebDKP_GetItemInfo(item); 
	
		WebDKP_AwardItem_FrameItemName:SetText(itemName);
	end

end


