------------------------------------------------------------------------
-- AUTO FILL Tasks
------------------------------------------------------------------------
-- This file contains methods related to auto filling in information in your dkp
-- form when items drop
------------------------------------------------------------------------

-- pop up here isn't used any more. New rules in 2.0 prevent popups from being used at all unless I build them from scratch
StaticPopupDialogs["WEBDKP_AUTOAWARD_MOREINFO"] = {
	text = "Award ", --%s %s
	button1 = "Yes",
	button2 = "No",
	--OnShow = function()
		-- getglobal(this:GetName().."EditBox"):SetText("");
		-- notice: "this" is the StaticPopup, normaly its "StaticPopup1"
	--end,
	--OnAccept = function()
		-- local cost = getglobal(this:GetParent():GetName().."EditBox"):GetText();
		--WebDKP_AutoAward(cost);
	--end,
	timeout = 30,
	whileDead = 1,
	hideOnEscape = 1,
	hasEditBox = 1
};

-- ================================
-- Helper structure that maps rarity of an item back to its rank
-- ================================
WebDKP_RarityTable = {
	[0] = -1,
	[1] = 0,
	[2] = 1,
	[3] = 2,
	[4] = 3,
	[5] = 4
};

-- ================================
-- An event that is triggered when loot is taken. If auto fill 
-- is enabled, this must check to see:
-- 1 - what item dropped and fill it in the item input
-- 2 - see what player got the item and select them
-- 3 - see if the item is in the loot table, and enter the cost if it is
-- 4 - if auto award is enabled it should award the item
-- ================================
function WebDKP_Loot_Taken()
	if ( WebDKP_Options["AutofillEnabled"] == 0 ) then
		return;
	end
	--1 Find out what item was dropped
	local sPlayer, sLink;
	local iStart, iEnd, sPlayerName, sItem = string.find(arg1, "([^%s]+) receives loot: (.+)%.");
	if ( sPlayerName ) then
		sPlayer = sPlayerName;
		sLink = sItem;
	else
		local iStart, iEnd, sItem = string.find(arg1, "You receive loot: (.+)%.");
		if ( sItem ) then
			sPlayer = UnitName("player");
			sLink = sItem;
		end
	end
	if ( sLink and sPlayer ) then
		--Get details about the item
		local sRarity, sName, sItem = WebDKP_GetItemInfo(sLink);
		
		-- if this is in our ignore list, we can skip it
		if ( WebDKP_ShouldIgnoreItem(sName) )  then
			return;
		end
		
		-- if this is the item that was last bid off/awarded, we can skip autofilling it
		if ( sName == WebDKP_lastBidItem or sName == WebDKP_bidItem) then 
			WebDKP_lastBidItem = "";
			return;
		end
		local rarity = WebDKP_RarityTable[sRarity];
		local cost = nil; 
		
		-- if this item isn't past the autofill rarity threshold in the options, skip it
		if( rarity < WebDKP_Options["AutofillThreshold"] ) then
			return;
		end
		
		--display the item name in the form
		WebDKP_AwardItem_FrameItemName:SetText(sName);
		
		-- see if we can determine the cost while we are at it...
		if ( WebDKP_Loot ~= nil ) then
			cost = WebDKP_Loot[sName];
			if ( cost ~= nil ) then 
				WebDKP_AwardItem_FrameItemCost:SetText(cost);
			else
				WebDKP_AwardItem_FrameItemCost:SetText("");
			end
		end
		--select the player
		WebDKP_SelectPlayerOnly(sPlayer);
		
		-- if we are set to auto award items, go ahead and display the popup
		if (WebDKP_Options["AutoAwardEnabled"] == 1) then
			--PlaySound("QUESTADDED");
			-- If we know the cost, prefill it in the form. 
			-- If not, show an input for them to enter something.
			if ( cost ~= nil ) then
				WebDKP_ShowAwardFrame("Award "..sPlayer.." "..sLink.." for "..cost.." DKP? \r\n (Enter DKP below, positive numbers only)",cost);
				WebDKP_AwardFrameCost:SetText(cost);
			else
				WebDKP_ShowAwardFrame("Award "..sPlayer.." "..sLink.."? \r\n (Enter DKP below, positive numbers only)",nil);
				--PlaySound("igQuestFailed");
			end
		end
	end
end


function WebDKP_ShowAwardFrame(title, cost)
	PlaySound("igMainMenuOpen");
	WebDKP_AwardFrame:Show();
	
	WebDKP_AwardFrameTitle:SetText(title);
	if(cost ~= nil) then
		WebDKP_AwardFrameCost:SetText(cost);
	else
		WebDKP_AwardFrameCost:SetText("");
	end
end

-- ================================
-- Callback function from clicking 'yes' on the autoaward dialog box
-- ================================
function WebDKP_AutoAward(cost)
	WebDKP_AwardItem_FrameItemCost:SetText(cost);
	WebDKP_AwardItem_Event();
end

-- ================================
-- Event handler for entering a name in the award item field
-- Will automattically fill in the cost if the cost is available in the players toot table
-- ================================
function WebDKP_AutoFillCost()
	if ( WebDKP_Options["AutofillEnabled"] == 0 ) then
		return;
	end
	local sName = WebDKP_AwardItem_FrameItemName:GetText();
	
	-- see if we can determine the cost while we are at it...
	if ( WebDKP_Loot ~= nil and sName ~= nil) then
		local cost = WebDKP_Loot[sName];
		if ( cost ~= nil ) then 
			WebDKP_AwardItem_FrameItemCost:SetText(cost);
		end
	end
end


-- ================================
-- Event handler for entering a name in the award dkp reason field
-- Will automattically fill in the cost if the cost is available in the players toot table
-- ================================
function WebDKP_AutoFillDKP()
	if ( WebDKP_Options["AutofillEnabled"] == 0 ) then
		return;
	end
	local sName = WebDKP_AwardDKP_FrameReason:GetText();
	
	-- see if we can determine the cost while we are at it...
	if ( WebDKP_Loot ~= nil and sName ~= nil) then
		local cost = WebDKP_Loot[sName];
		if ( cost ~= nil ) then 
			WebDKP_AwardDKP_FramePoints:SetText(cost);
		end
	end
end



