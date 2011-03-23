------------------------------------------------------------------------
-- GROUP FUNCTIONS
------------------------------------------------------------------------
-- This file contains methods related to working with the dkp table
-- and the current group. 
-- Contained in here are methods to:
-- *	Scan your group to find out what players are currently in it
-- *	Update the 'table to show' which determines the dkp table to show based on members
--		of your group, the current dkp table, and any filters that are selected
-- *	Update the gui with the table to show
------------------------------------------------------------------------

-- ================================
-- Rerenders the table to the screen. This is called 
-- on a few instances - when the scroll frame throws an 
-- event or when filters are applied or when group
-- memebers change. 
-- General structure:
-- First runs through the table to display and puts the data
-- into a temp array to work with
-- Then uses sorting options to sort the temp array
-- Calculates the offset of the table to determine
-- what information needs to be displayed and in what lines 
-- of the table it should be displayed
-- ================================
function WebDKP_UpdateTable()
	--self:Print("Scroll method called");
	-- Copy data to the temporary array
	local entries = { };
	for k, v in pairs(WebDKP_DkpTableToShow) do
		if ( type(v) == "table" ) then
			if( v[1] ~= nil and v[2] ~= nil and v[3] ~=nil and v[4] ~=nil) then
				tinsert(entries,{v[1],v[2],v[3],v[4]}); -- copies over name, class, dkp, tier
			end
		end
	end
	
	-- SORT
	table.sort(
		entries,
		function(a1, a2)
			if ( a1 and a2 ) then
				if ( a1 == nil ) then
					return 1>0;
				elseif (a2 == nil) then
					return 1<0;
				end
				if ( WebDKP_LogSort["way"] == 1 ) then
					if ( a1[WebDKP_LogSort["curr"]] == a2[WebDKP_LogSort["curr"]] ) then
						return a1[1] > a2[1];
					else
						return a1[WebDKP_LogSort["curr"]] > a2[WebDKP_LogSort["curr"]];
					end
				else
					if ( a1[WebDKP_LogSort["curr"]] == a2[WebDKP_LogSort["curr"]] ) then
						return a1[1] < a2[1];
					else
						return a1[WebDKP_LogSort["curr"]] < a2[WebDKP_LogSort["curr"]];
					end
				end
			end
		end
	);
	
	local numEntries = getn(entries);
	local offset = FauxScrollFrame_GetOffset(WebDKP_FrameScrollFrame);
	FauxScrollFrame_Update(WebDKP_FrameScrollFrame, numEntries, 20, 20);
	
	-- Run through the table lines and put the appropriate information into each line
	for i=1, 20, 1 do
		local line = getglobal("WebDKP_FrameLine" .. i);
		local nameText = getglobal("WebDKP_FrameLine" .. i .. "Name");
		local classText = getglobal("WebDKP_FrameLine" .. i .. "Class");
		local dkpText = getglobal("WebDKP_FrameLine" .. i .. "DKP");
		local tierText = getglobal("WebDKP_FrameLine" .. i .. "Tier");
		local index = i + FauxScrollFrame_GetOffset(WebDKP_FrameScrollFrame); 
		
		if ( index <= numEntries) then
			local playerName = entries[index][1];
			line:Show();
			nameText:SetText(entries[index][1]);
			classText:SetText(entries[index][2]);
			dkpText:SetText(entries[index][3]);
			tierText:SetText(entries[index][4]);
			-- kill the background of this line if it is not selected
			if( not WebDKP_DkpTable[playerName]["Selected"] ) then
				getglobal("WebDKP_FrameLine" .. i .. "Background"):SetVertexColor(0, 0, 0, 0);
			else
				getglobal("WebDKP_FrameLine" .. i .. "Background"):SetVertexColor(0.1, 0.1, 0.9, 0.8);
			end
		else
			-- if the line isn't in use, hide it so we dont' have mouse overs
			line:Hide();
		end
	end
end


-- ================================
-- Helper method that determines the table that should be shown. 
-- This runs through the dkp list and checks filters against each entry
-- If an entry passes it is moved to the table to show. If it doesn't pass
-- the test it is ignored. 
-- ================================
function WebDKP_UpdateTableToShow()
	local tableid = WebDKP_GetTableid();
	-- clear the old table
	WebDKP_DkpTableToShow = { };
	-- increment through the dkp table and move data over
	for k, v in pairs(WebDKP_DkpTable) do
		if ( type(v) == "table" ) then
			local playerName = k; 
			local playerClass = v["class"];
			local playerDkp = WebDKP_GetDKP(playerName, tableid);
			local playerTier = floor((playerDkp-1)/WebDKP_TierInterval);
			if( playerDkp == 0 ) then
				playerTier = 0;
			end
			-- if it should be displayed (passes filter) add it to the table
			if (WebDKP_ShouldDisplay(playerName, playerClass, playerDkp, playerTier)) then
				tinsert(WebDKP_DkpTableToShow,{playerName,playerClass,playerDkp,playerTier});
			else
				-- if it is not displayed, deselect it automatically for us
				WebDKP_DkpTable[playerName]["Selected"] = false;
			end
		end
	end
	-- now need to run through anyone else who is in our current raid / party
	-- They may not have dkp yet and may not be in our dkp table. Use this oppurtunity 
	-- to add them to the table with 0 points and add them to the to display table if appropriate
	-- table to be displayed
	for key, entry in pairs(WebDKP_PlayersInGroup) do
		if ( type(entry) == "table" ) then
			local playerName = entry["name"];
			-- is this a new person we havn't seen before?
			if ( WebDKP_DkpTable[playerName] == nil) then
				-- new person, they need to be added
				local playerClass = entry["class"];
				local playerDkp = 0;
				local playerTier = 0;
				WebDKP_MakeSureInTable(playerName, tableid, playerClass, playerDkp)
	
				-- do a final check to see if we should display (pass all filters, etc.)
				if (WebDKP_ShouldDisplay(playerName, playerClass, playerDkp, playerTier)) then
					tinsert(WebDKP_DkpTableToShow,{playerName,playerClass,playerDkp,playerTier});
				else
					WebDKP_DkpTable[playerName]["Selected"] = false;
				end
			end
		end
	end
end


-- ================================
-- Updates the list of players in our current group.
-- First attempts to get raid data. If user isn't in a raid
-- it checks party data. If user is not in a party there 
-- is no information to get
-- ================================
function WebDKP_UpdatePlayersInGroup()
	-- Updates the list of players currently in the group
	-- First attempts to get this data via a query to the raid. 
	-- If that failes it resorts to querying for party data
	local numberInRaid = GetNumRaidMembers();
	local numberInParty = GetNumPartyMembers();
	WebDKP_PlayersInGroup = {};
	-- Is a raid going?
	if ( numberInRaid > 0 ) then
		-- Yes! Load raid data...
		local name, class, guild;
		for i=1, numberInRaid do
			name, _, _, _, class, _, _, _ , _ = GetRaidRosterInfo(i);
			WebDKP_PlayersInGroup[i]=
			{
				["name"] = name,
				["class"] = class,
			};
		end
	-- Is a party going?
	elseif ( numberInRaid == 0 and numberInParty>0) then
		-- Yes! Load party data instead...
		local name, class, guild, playerHandle;
		for i=1, numberInParty do
			playerHandle = "party"..i;
			name = UnitName(playerHandle);
			class = UnitClass(playerHandle);
			WebDKP_PlayersInGroup[i]=
			{
				["name"] = name,
				["class"] = class,
			};
		end
		-- this doesn't load the current player, so we need to add them manually
		WebDKP_PlayersInGroup[numberInParty+1]=
		{
			["name"] = UnitName("player"),
			["class"] = UnitClass("player"),
		};
	end
	-- not in party or raid, don't need to load anything special
end


-- ================================
-- Returns true if everyone in the current group is selected. 
-- This is a helper method when displaying messages to chat. 
-- If everyone is selected you can just say "awarded points to everyone"
-- versus listing out everyone who was selected invidiually
-- ================================
function WebDKP_AllGroupSelected()
	-- First try running through the raid and see if they are all selected
	local name, class;
	local numberInRaid = GetNumRaidMembers();
	local numberInParty = GetNumPartyMembers();
	if(numberInRaid > 0 ) then
		for i=1, numberInRaid do
			name, _, _, _, _, _, _, _ , _ = GetRaidRosterInfo(i);
			if ( not WebDKP_DkpTable[name]["Selected"]) then
				return false;
			end
		end
		return true;
	elseif ( numberInParty > 0) then
		for i=1, numberInParty do
			playerHandle = "party"..i;
			name = UnitName(playerHandle);
			if ( not WebDKP_DkpTable[name]["Selected"]) then
				return false;
			end
		end
		--before we return true we also need to check the current player...
		if ( not WebDKP_DkpTable[UnitName("player")]["Selected"]) then
			return false;
		end
		return true;
	end
	-- entire group isn't selected, do things manually
	return false;
end


-- ================================
-- Helper method. Returns true if the current player should be displayed
-- on the table by checking it against current filters
-- ================================
function WebDKP_ShouldDisplay(name, class, dkp, tier)
	if (name == "Unknown") then
		return false;
	end
	if (WebDKP_Filters[class] == 0) then
		return false;
	end 
	if (WebDKP_Filters["Group"] == 1 and WebDKP_PlayerInGroup(name) == false) then
		return false
	end
	return true; 
end