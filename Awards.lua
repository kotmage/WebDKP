------------------------------------------------------------------------
-- AWARDS	
------------------------------------------------------------------------
-- This file contains methods related to awarding/deducting DKP and 
-- items. It also contains methods for appending this data to the log file. 
------------------------------------------------------------------------


-- ================================
-- Called when user clicks on the 'award item' box. 
-- Gets the first selected player in the list, and the
-- contents of the award item edit boxes. Uses this to 
-- display a short blirb to the screen then recordes 
-- the changes
-- ================================
function WebDKP_AwardItem_Event()
	local name, class, guild;
	local cost = WebDKP_AwardItem_FrameItemCost:GetText();
	local item = WebDKP_AwardItem_FrameItemName:GetText();
	if ( item == nil or item=="" ) then
		WebDKP_Print("You must enter an item name.");
		PlaySound("igQuestFailed");
		return;
	end
	cost = tonumber(cost);
	
	if ( cost == nil or cost=="") then
		WebDKP_Print("You must enter a valid cost for the item.");
		PlaySound("igQuestFailed");
		return;
	end

	cost = WebDKP_ROUND(cost,2);

	local points = cost * -1;
	local player = WebDKP_GetSelectedPlayers(1);
	
	if ( player == nil or player == "") then
		WebDKP_Print("No player was selected to award. Award NOT made.");
		PlaySound("igQuestFailed");
	else
		WebDKP_AddDKP(points, item, "true", player)
		WebDKP_AnnounceAwardItem(points, item, player[0]["name"]);

		-- Update the table so we can see the new dkp status
		WebDKP_UpdateTableToShow();
		WebDKP_UpdateTable();
	end
end

-- ================================
-- Called when user clicks on 'award dkp' on the award 
-- dkp tab. Gets data from the award dkp edit boxes. 
-- Uses this to display a little blirb, then recodes
-- this information for all players currently selected
-- (note, if player is hidden due to filter, they are automattically
-- deselected)
-- ================================
function WebDKP_AwardDKP_Event()
	local name, class, guild;
	local points = WebDKP_AwardDKP_FramePoints:GetText();
	local reason = WebDKP_AwardDKP_FrameReason:GetText();

	points = tonumber(points);
	if ( points == nil or points=="") then
		WebDKP_Print("You must enter DKP points to award.");
		PlaySound("igQuestFailed");
		return;
	end
	
	points = WebDKP_ROUND(points,2);
	local players = WebDKP_GetSelectedPlayers(0);
	
	if ( players == nil ) then
		WebDKP_Print("No players were selected. Award NOT made.");
		PlaySound("igQuestFailed");
	else 
		WebDKP_AddDKP(points, reason, "false", players)
		WebDKP_AnnounceAward(points,reason);

		-- Update the table so we can see the new dkp status
		WebDKP_UpdateTableToShow();
		WebDKP_UpdateTable();
	end
end



-- ================================
-- Adds the specified dkp / reason to all selected players
-- If this is an item award, it is only awarded to the first player
-- If it is an item award and zero-sum is used, an automatted
-- zero sum award is also given
-- ================================
function WebDKP_AddDKP(points, reason, forItem, players)
	local date  = date("%Y-%m-%d %H:%M:%S");
	local location = GetZoneText();
	local tableid = WebDKP_GetTableid();
	local awardedBy = UnitName("player");
	
	if (not WebDKP_Log) then
		WebDKP_Log = {};
	end
	--next, make sure this player is in the log
	if (not WebDKP_Log[reason.." "..date]) then
		WebDKP_Log[reason.." "..date] = {};
	end
	
	WebDKP_Log["Version"] = 2;
	WebDKP_Log[reason.." "..date]["reason"] = reason;
	WebDKP_Log[reason.." "..date]["date"] = date;
	WebDKP_Log[reason.." "..date]["foritem"] = forItem;
	WebDKP_Log[reason.." "..date]["zone"] = location;
	WebDKP_Log[reason.." "..date]["tableid"] = tableid;
	WebDKP_Log[reason.." "..date]["awardedby"] = awardedBy;
	WebDKP_Log[reason.." "..date]["points"] = points;
	
	if (not WebDKP_Log[reason.." "..date]["awarded"]) then
		WebDKP_Log[reason.." "..date]["awarded"] = {};
	end
	
	
	for k, v in pairs(players) do
		if ( type(v) == "table" ) then
			name = v["name"]; 
			class = v["class"];
			guild = WebDKP_GetGuildName(name);
			WebDKP_AddDKPToTable(name, class, points);
			--add them to the log entry
			WebDKP_Log[reason.." "..date]["awarded"][name] = {};
			WebDKP_Log[reason.." "..date]["awarded"][name]["name"]=name;
			WebDKP_Log[reason.." "..date]["awarded"][name]["guild"]=guild;
			WebDKP_Log[reason.." "..date]["awarded"][name]["class"]=class;
			
			-- If awarding an item, only 1 person should be recorded as having recieved it
			if ( forItem == "true" ) then
				break;
			end
		end
	end
	
	-- if this is an item award and we are using zero-sum dkp, we need to give automated
	-- zero sum awards too
	if ( WebDKP_WebOptions["ZeroSumEnabled"]==1 and forItem=="true") then
		WebDKP_AwardZeroSum(points, reason, date);
	end
	
	
end

function WebDKP_AddDKPToTable(name, class, points)
	-- if the 'combine alts w/ main' option is enabled, these points need to go to the 
	-- main instead of the alt
	if ( WebDKP_WebOptions["CombineAlts"] == 1 ) then
		name = WebDKP_GetMain(name);
	end

	local tableid = WebDKP_GetTableid();
	WebDKP_MakeSureInTable(name, tableid, class , 0);

	WebDKP_DkpTable[name]["dkp_"..tableid] = WebDKP_DkpTable[name]["dkp_"..tableid] + points;
end


-- ================================
-- Helper method for ZeroSum Award. Called when a player
-- is recieving an item and the guild is using zero sum. 
-- This method must run through everyone in the current
-- party and give them an award equal to, but opposite
-- the cost of the item just given. 
-- ================================
function WebDKP_AwardZeroSum(points, reason, date)
	local location = GetZoneText();
	local tableid = WebDKP_GetTableid();
	local awardedBy = UnitName("player");
	WebDKP_UpdatePlayersInGroup();
	
	local numPlayers = WebDKP_GetTableSize(WebDKP_PlayersInGroup);
	if ( numPlayers == 0 ) then
		return;
	end
	local toAward = (points * -1) / numPlayers;
	toAward = WebDKP_ROUND(toAward, 2 );
	reason = "ZeroSum: "..reason;
	
	if (not WebDKP_Log) then
		WebDKP_Log = {};
	end
	--next, make sure this player is in the log
	if (not WebDKP_Log[reason.." "..date]) then
		WebDKP_Log[reason.." "..date] = {};
	end
	
	WebDKP_Log[reason.." "..date]["reason"] = reason;
	WebDKP_Log[reason.." "..date]["date"] = date;
	WebDKP_Log[reason.." "..date]["foritem"] = forItem;
	WebDKP_Log[reason.." "..date]["zone"] = location;
	WebDKP_Log[reason.." "..date]["tableid"] = tableid;
	WebDKP_Log[reason.." "..date]["awardedby"] = awardedBy;
	WebDKP_Log[reason.." "..date]["points"] = toAward;
	WebDKP_Log[reason.." "..date]["awarded"] = {};
	
	for key, entry in pairs(WebDKP_PlayersInGroup) do
		if ( type(entry) == "table" ) then
			local playerName = entry["name"];
			local playerClass = entry["class"];
			local playerGuild = WebDKP_GetGuildName(playerName);
			WebDKP_MakeSureInTable(playerName, tableid, playerClass , 0);
	
			WebDKP_Log[reason.." "..date]["awarded"][playerName] = {};
			WebDKP_Log[reason.." "..date]["awarded"][playerName]["name"]=playerName;
			WebDKP_Log[reason.." "..date]["awarded"][playerName]["guild"]=playerGuild;
			WebDKP_Log[reason.." "..date]["awarded"][playerName]["class"]=playerClass;
			WebDKP_Print("Auto award "..playerName.." for "..toAward);
			
			WebDKP_AddDKPToTable(playerName, playerClass, toAward);
		end
	end
end



-- ================================
-- Returns a table of all the selected players from the main dkp table.
-- Limit specifiecs the maximum number players that should be returned. 
-- If limit = 0, there is no limit
-- ================================
function WebDKP_GetSelectedPlayers(limit) 
	local toReturn = {}; 
	local count = 0; 
	for key_name, v in pairs(WebDKP_DkpTable) do
		if ( type(v) == "table" ) then
			if( v["Selected"] ) then
				toReturn[count] = {
					["name"] = key_name,
					["class"] = v["class"],
				}
				count = count + 1; 
				if ( limit~=0 and count >= limit ) then
					return toReturn;
				end
			end		
		end
	end
	if ( count == 0 ) then
		return nil;
	else
		return toReturn;
	end
end