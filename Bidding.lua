------------------------------------------------------------------------
-- BIDDING	
------------------------------------------------------------------------
-- Contains methods related to bidding and the bidding gui.
------------------------------------------------------------------------


local WebDKP_BidList = {	};					-- Will hold the bids placed during run time
local WebDKP_bidInProgress = false;			-- Bid in progress?
WebDKP_bidItem = "";						-- Item name being bid on
local WebDKP_bidCountdown = 0;				-- How many seconds until bid ends on its own
local WebDKP_startingBid = 0 ;				-- the default starting bid if something cannot be found in the loot table (NOT the current starting bid which is read from the gui)
WebDKP_lastBidItem = "";					-- The last item that was bidded on and actually awarded. Flagged so that auto fill will not to show a popup when it is given out

-- Data structure for sorting the table 
WebDKP_BidSort = {
	["curr"] = 2,				-- the column to sort
	["way"] = 1					-- Desc
};

-- ================================
-- Toggles displaying the bidding panel
-- ================================
function WebDKP_Bid_ToggleUI()
	if ( WebDKP_BidFrame:IsShown() ) then
		WebDKP_BidFrame:Hide();
	else
		WebDKP_BidFrame:Show();
		local time = WebDKP_BidFrameTime:GetText();
		if(time == nil or time == "") then
			WebDKP_BidFrameTime:SetText("0");
		end
		local startingBid = WebDKP_BidFrameStartingBid:GetText();
		if(startingBid == nil or startingBid == "") then
			WebDKP_BidFrameStartingBid:SetText("0");
		end
	end
end

-- ================================
-- Shows the Bid UI
-- ================================
function WebDKP_Bid_ShowUI()
	WebDKP_BidFrame:Show();
	local time = WebDKP_BidFrameTime:GetText();
	if(time == nil or time == "") then
		WebDKP_BidFrameTime:SetText("0");
	end
	local startingBid = WebDKP_BidFrameStartingBid:GetText();
	if(startingBid == nil or startingBid == "") then
		WebDKP_BidFrameStartingBid:SetText("0");
	end
end

-- ================================
-- Hides the Bid UI
-- ================================
function WebDKP_Bid_HideUI()
	WebDKP_BidFrame:Hide();
end

-- ================================
-- Called when mouse goes over a dkp line entry. 
-- If that player is not selected causes that row
-- to become 'highlighted'
-- ================================
function WebDKP_Bid_HandleMouseOver()
	local playerName = getglobal(this:GetName().."Name"):GetText();
	local playerBid = getglobal(this:GetName().."Bid"):GetText();
	local selected = WebDKP_Bid_IsSelected(playerName, playerBid);
	
	if( not selected ) then
		getglobal(this:GetName() .. "Background"):SetVertexColor(0.2, 0.2, 0.7, 0.5);
	end
end

-- ================================
-- Called when a mouse leaes a dkp line entry. 
-- If that player is not selected, causes that row
-- to return to normal (none highlighted)
-- ================================
function WebDKP_Bid_HandleMouseLeave()
	local playerName = getglobal(this:GetName().."Name"):GetText();
	local playerBid = getglobal(this:GetName().."Bid"):GetText();
	local selected = WebDKP_Bid_IsSelected(playerName, playerBid);
	if( not selected ) then
		getglobal(this:GetName() .. "Background"):SetVertexColor(0, 0, 0, 0);
	end
end

-- ================================
-- Called when the user clicks on a player entry. Causes 
-- that entry to either become selected or normal
-- and updates the dkp table with the change
-- ================================
function WebDKP_Bid_SelectPlayerToggle()
	local playerName = getglobal(this:GetName().."Name"):GetText();
	local playerBid = getglobal(this:GetName().."Bid"):GetText() + 0 ;
	
	
	-- we need to search through the table and figure out which one was selected
	-- an entry is considered a unique name / bid pair
	-- once we find an entry we can toggle its selection state
	for key, v in pairs(WebDKP_BidList) do
		if ( type(v) == "table" ) then
			if( v["Name"] ~= nil and v["Bid"] ~= nil ) then
				if ( v["Name"] == playerName and v["Bid"] == playerBid ) then 
					if (v["Selected"] == true) then
						v["Selected"] = false;
						getglobal(this:GetName() .. "Background"):SetVertexColor(0.2, 0.2, 0.7, 0.5);
					else
						-- deselect all the others on the table
						WebDKP_Bid_DeselectAll();
						
						v["Selected"] = true;
						getglobal(this:GetName() .. "Background"):SetVertexColor(0.1, 0.1, 0.9, 0.8);
					end
				end
			end
		end
	end
	
	
	WebDKP_Bid_UpdateTable();
end

-- ================================
-- Returns true if the given player name / bid value is selected
-- in the bid list table. false otherwise. 
-- ================================
function WebDKP_Bid_IsSelected(playerName, playerBid)
	playerBid = playerBid + 0 ; 
	for key, v in pairs(WebDKP_BidList) do
		if ( type(v) == "table" ) then
			if( v["Name"] ~= nil and v["Bid"] ~= nil ) then
				if ( v["Name"] == playerName and v["Bid"] == playerBid ) then 
					return v["Selected"];
				end
			end
		end
	end
	return false;
end

-- ================================
-- Deselects all entries in the table
-- ================================
function WebDKP_Bid_DeselectAll()
	for key, v in pairs(WebDKP_BidList) do
		if ( type(v) == "table" ) then
			if( v["Name"] ~= nil and v["Bid"] ~= nil ) then
				v["Selected"] = false;
			end
		end
	end
end

-- ================================
-- Called when a player clicks on a column header on the table
-- Changes the sorting options / asc&desc. 
-- Causes the table display to be refreshed afterwards
-- to player instantly sees changes
-- ================================
function WebDKP_Bid_SortBy(id)
	if ( WebDKP_BidSort["curr"] == id ) then
		WebDKP_BidSort["way"] = abs(WebDKP_BidSort["way"]-1);
	else
		WebDKP_BidSort["curr"] = id;
		if( id == 1) then
			WebDKP_BidSort["way"] = 0;
		elseif ( id == 2 ) then
			WebDKP_BidSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
		elseif ( id == 3 ) then
			WebDKP_BidSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
		else
			WebDKP_BidSort["way"] = 1; --columns with numbers need to be sorted different first in order to get DESC right
		end
		
	end
	-- update table so we can see sorting changes
	WebDKP_Bid_UpdateTable();
end



-- ================================
-- Rerenders the sorted table to the screen. This is called 
-- on a few instances - when the scroll frame throws an 
-- event or when bids are placed or when a bid ends. 
-- General structure:
-- First runs through the table to display and puts the data
-- into a temp array to work with
-- Then uses sorting options to sort the temp array
-- Calculates the offset of the table to determine
-- what information needs to be displayed and in what lines 
-- of the table it should be displayed
-- ================================
function WebDKP_Bid_UpdateTable()
	-- Copy data to the temporary array
	local entries = { };
	for key_name, v in pairs(WebDKP_BidList) do
		if ( type(v) == "table" ) then
			if( v["Name"] ~= nil and v["Bid"] ~= nil and v["DKP"] ~=nil and v["Post"] ~=nil) then
				
				tinsert(entries,{v["Name"],v["Bid"],v["DKP"],v["Post"],v["Date"]}); -- copies over name, bid, dkp, dkp-bid
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
				if ( WebDKP_BidSort["way"] == 1 ) then
					if ( a1[WebDKP_BidSort["curr"]] == a2[WebDKP_BidSort["curr"]] ) then
						return a1[1] > a2[1];
					else
						return a1[WebDKP_BidSort["curr"]] > a2[WebDKP_BidSort["curr"]];
					end
				else
					if ( a1[WebDKP_BidSort["curr"]] == a2[WebDKP_BidSort["curr"]] ) then
						return a1[1] < a2[1];
					else
						return a1[WebDKP_BidSort["curr"]] < a2[WebDKP_BidSort["curr"]];
					end
				end
			end
		end
	);
	
	local numEntries = getn(entries);
	local offset = FauxScrollFrame_GetOffset(WebDKP_BidFrameScrollFrame);
	FauxScrollFrame_Update(WebDKP_BidFrameScrollFrame, numEntries, 13, 13);
	
	-- Run through the table lines and put the appropriate information into each line
	for i=1, 13, 1 do
		local line = getglobal("WebDKP_BidFrameLine" .. i);
		local nameText = getglobal("WebDKP_BidFrameLine" .. i .. "Name");
		local bidText = getglobal("WebDKP_BidFrameLine" .. i .. "Bid");
		local dkpText = getglobal("WebDKP_BidFrameLine" .. i .. "DKP");
		local postBidText = getglobal("WebDKP_BidFrameLine" .. i .. "Post");
		local index = i + FauxScrollFrame_GetOffset(WebDKP_BidFrameScrollFrame); 
		
		if ( index <= numEntries) then
			local playerName = entries[index][1];
			local date = entries[index][5];
			line:Show();
			nameText:SetText(entries[index][1]);
			bidText:SetText(entries[index][2]);
			dkpText:SetText(entries[index][3]);
			postBidText:SetText(entries[index][4]);
			-- kill the background of this line if it is not selected
			if( WebDKP_BidList[playerName..date] and (not WebDKP_BidList[playerName..date]["Selected"]) ) then
				getglobal("WebDKP_BidFrameLine" .. i .. "Background"):SetVertexColor(0, 0, 0, 0);
			else
				getglobal("WebDKP_BidFrameLine" .. i .. "Background"):SetVertexColor(0.1, 0.1, 0.9, 0.8);
			end
		else
			-- if the line isn't in use, hide it so we dont' have mouse overs
			line:Hide();
		end
	end
end

-- ================================
-- Handles chat messages directed towards bidding. This includes
-- placing a bid and remotly starting / stopping a bid.
-- ================================
function WebDKP_Bid_Event()
	local name = arg2;
	local trigger = arg1;
	if(WebDKP_IsBidChat(name,trigger)) then
		local cmd, subcmd = WebDKP_GetCmd(trigger);
		cmd, subcmd = WebDKP_GetCommaCmd(subcmd);

	
		-- SOMEONE HAS PLACED A BID
		if(string.find(string.lower(trigger), "bid")==1 ) then	
			if(WebDKP_bidInProgress == false) then
				WebDKP_SendWhisper(name,"There is no bid in progress");
			elseif(cmd == "") then
				WebDKP_SendWhisper(name,"You did not specify a bid amount - bid not accepted");
			elseif((cmd+0) < WebDKP_GetStartingBid() ) then
				WebDKP_SendWhisper(name,"Bid not accepted. The minimum bid is "..WebDKP_GetStartingBid());
			else
				WebDKP_Bid_HandleBid(name,cmd);
				--WebDKP_SendWhisper(name,"Bid for "..cmd.." dkp accepted");
			end	
			
		-- THEY WANT THE BIDDING TO START
		elseif(string.find(string.lower(trigger), "!startbid")==1 ) then
		
			if (WebDKP_bidInProgress == true ) then
				WebDKP_SendWhisper(name,"There is already a bid in progress - you can't start another bid until the first one is finished");
			elseif ( cmd == "" or cmd == nil) then
				WebDKP_SendWhisper(name,"You must specify an item to bid on. Example: !startbid [Giantstalker's Helm]");
			else	
				WebDKP_Bid_StartBid(cmd,subcmd);
				WebDKP_BidFrameBidButton:SetText("Stop Bidding");
			end
				
		-- THEY WANT THE BIDDING TO STOP	
		elseif(string.find(string.lower(trigger), "!stopbid")==1 ) then
			if (WebDKP_bidInProgress == false ) then
				WebDKP_SendWhisper(name,"There is no bid in progress for you to cancel");
			else
				WebDKP_Bid_StopBid();
				WebDKP_BidFrameBidButton:SetText("Start the Bidding!");
			end
		-- SOMEONE NEEDS AN ITEM (FOR FIXED BIDDING ONLY - BIDS ALL THEY HAVE)
		elseif(string.find(string.lower(trigger), "!need")==1 and WebDKP_Options["BidFixedBidding"]==1) then
			local dkp = WebDKP_GetDKP(name); -- bid all their dkp. in a fixed bid they will only be charged the cost from the loot table - this is just for ordering
			WebDKP_Bid_HandleBid(name, dkp); 
			
		end
	end
end

-- ================================
-- Gets the current starting bid from the gui
-- ================================
function WebDKP_GetStartingBid()
	local start = WebDKP_BidFrameStartingBid:GetText();
	if ( start == nil or start == "") then
		start = 0;
	end
	return start+0; -- add + 0 to convert it to an int
end

-- ================================
-- Returns true if the passed whisper is a chat message directed
-- towards web dkp bidding
-- ================================
function WebDKP_IsBidChat(name, trigger)
	if ( string.find(string.lower(trigger), "bid" )== 1 or
		 string.find(string.lower(trigger), "!startbid" ) == 1 or 
		 string.find(string.lower(trigger), "!stopbid" ) == 1 or
		 string.find(string.lower(trigger), "!need" ) == 1
		) then
        return true
    end
    return false
end

-- ================================
-- Triggers Bidding to Start
-- ================================
function WebDKP_Bid_StartBid(item, time)
	WebDKP_BidFrameBidButton:SetText("Stop Bidding");

	WebDKP_BidList = {};
	if (time == "" or time == nil or time=="0" or time==" ") then
		time = 0 ; 
	end
	
	local quality, itemName, itemLink = WebDKP_GetItemInfo(item);
	WebDKP_bidItem = itemName;
	WebDKP_BidFrameItem:SetText(itemName);
	WebDKP_BidFrameTime:SetText(time);
	WebDKP_Bid_ItemNameChanged();
	
	
	-- if the options ask for it, also make an announcement in a raid warning
	if ( WebDKP_Options["BidAnnounceRaid"] == 1 ) then
		WebDKP_SendAnnouncement("Bidding Has Started!", "RAID_WARNING");
	end	
	WebDKP_AnnounceBidStart(itemLink, time, WebDKP_GetStartingBid());
	
	WebDKP_bidInProgress = true;
	
	WebDKP_Bid_UpdateTable();
	WebDKP_Bid_ShowUI();
	
	if(time ~= 0 ) then 
		WebDKP_bidCountdown = time;
		WebDKP_Bid_UpdateFrame:Show();
	else
		WebDKP_Bid_UpdateFrame:Hide();
	end
	
	
end


-- ================================
-- Stops the current bidding
-- ================================
function WebDKP_Bid_StopBid()
	
	WebDKP_Bid_UpdateFrame:Hide();								-- stop any countdowns
	WebDKP_BidFrame_Countdown:SetText("");
	
	WebDKP_BidFrameBidButton:SetText("Start the Bidding!");		-- fix the button text
	local bidder, bid = WebDKP_Bid_GetHighestBid();				-- find highest bidder (not used any more)
	WebDKP_AnnounceBidEnd(WebDKP_bidItem, bidder, bid);			-- make the announcement
	WebDKP_bidInProgress = false;								
	WebDKP_Bid_ShowUI();										-- show the bid gui
	
end


-- ================================
-- Handles a bid placed by a player. 
-- ================================
function WebDKP_Bid_HandleBid(playerName, bidAmount)
	
	-- if a bid is not in progress ignore it
	if(WebDKP_bidInProgress) then 
		--load up some information about the player
		local dkp = WebDKP_GetDKP(playerName);			-- how much dkp do they have now
		local postDkp = dkp-bidAmount;					-- what they will have if they spend this
		bidAmount = bidAmount+0;						-- make sure bid amount is an int
		local date  = date("%Y-%m-%d %H:%M:%S");		-- record when this bid was placed
		
		-- check to see if we should reject this bid if it makes the user go into
		-- negative balance
		if ( postDkp < 0 and WebDKP_Options["BidAllowNegativeBids"] == 0 ) then
			WebDKP_SendWhisper(playerName,"Bid Rejected - you cannot bid more than you have.");
			WebDKP_SendWhisper(playerName,"Your maximum bid is "..dkp);
		else
			-- bid is ok, we can go ahead and record it
			WebDKP_BidList[playerName..date] = {			-- place their bid in the bid table (combine it with the date so 1 player can have multiple bids / unique indices in the table)
				["Name"] = playerName,
				["Bid"] = bidAmount,
				["DKP"] = dkp,
				["Post"] = postDkp,
				["Date"] = date,
			}
			
			if(WebDKP_BidList[playerName..date]["Selected"]==nil) then
				WebDKP_BidList[playerName..date]["Selected"] = false;
			end
			
			WebDKP_Bid_UpdateTable();
			
			WebDKP_SendWhisper(playerName,"Bid Recieved");
			
			-- if they bid too low we should tell them
			local highBidder, highBid = WebDKP_Bid_GetHighestBid();
			if ( highBidder == playerName and WebDKP_Options["BidNotifyLowBids"]==1) then
				WebDKP_SendWhisper(playerName,"You are the current high bidder");
			elseif (highBidder ~= playerName and WebDKP_Options["BidNotifyLowBids"]==1) then
				WebDKP_SendWhisper(playerName,"You are NOT the high bidder. The current high bid is  "..highBid.." dkp.");
			end
		
		end
	else
		WebDKP_SendWhisper(playerName,"No bid is in progress");
	end
end

-- ================================
-- Returns the highest bidder and what they bid. 
-- ================================
function WebDKP_Bid_GetHighestBid()
	local highestBidder = nil;
	local highestBid = 0; 

	for key_name, v in pairs(WebDKP_BidList) do
		if ( type(v) == "table" ) then
			if( v["Bid"] ~= nil ) then
				if (v["Bid"] > highestBid ) then
					highestBidder = v["Name"];
					highestBid = v["Bid"];
				end
			end
		end
	end
	return highestBidder, highestBid;
end

-- ================================
-- Method invoked when the user clicks the award button the on 
-- bid frame. Finds the first person who is selected
-- and awards them the item. 
-- ================================
function WebDKP_Bid_AwardSelected()
	-- find out who is selected
	local player, bid = WebDKP_Bid_GetSelected();
	local _,_,link = WebDKP_GetItemInfo(WebDKP_bidItem);
	
	-- if someone is selected, award them the item via the award class
	if ( player == nil ) then 
		WebDKP_Print("Nobody selected - no one awarded");
		PlaySound("igQuestFailed");
	else
		--since we are awarding, stop the bid
		if ( WebDKP_bidInProgress) then
			WebDKP_Bid_StopBid();
		end
		
		if ( WebDKP_Options["BidFixedBidding"] == 1 ) then
			bid = WebDKP_GetLootTableCost(WebDKP_bidItem);
		end
		
		-- check the options to see if we need to display a confirmation box
		if ( WebDKP_Options["BidConfirmPopup"] == 1 or bid == nil) then
			if ( WebDKP_Options["BidFixedBidding"] == 1 and bid == nil ) then
				WebDKP_Bid_ShowConfirmFrame("Award "..player.." "..link.."? |cFFFF0000(Item not in loot table)|r",0);
			elseif (WebDKP_Options["BidFixedBidding"] == 1 ) then
				WebDKP_Bid_ShowConfirmFrame("Award "..player.." "..link.." for "..bid.." dkp? (Fixed Cost From LootTable)",bid);
			else
				WebDKP_Bid_ShowConfirmFrame("Award "..player.." "..link.." for "..bid.." dkp?",bid);
			end
		else 
			WebDKP_Bid_AwardPerson(bid);
		end
	end
end

-- ================================
-- Event handler for the start / stop bid button. 
-- This button toggles between states when clicked. 
-- ================================
function WebDKP_Bid_ButtonHandler()

	if(WebDKP_bidInProgress) then
		WebDKP_Bid_StopBid();		
	else
		local item = WebDKP_BidFrameItem:GetText();
		local time = WebDKP_BidFrameTime:GetText();
		WebDKP_Bid_StartBid(item, time);
	end
end

-- ================================
-- Method invoked when the user clicks the award button the on 
-- bid frame. Finds the first person who is selected
-- and awards them the item. 
-- ================================
function WebDKP_Bid_GetSelected()
	for key_name, v in pairs(WebDKP_BidList) do
		if ( type(v) == "table" ) then
			if(  v["Selected"] == true) then
				return v["Name"], v["Bid"];
			end
		end
	end
	return nil, 0;
end


-- ================================
-- Event handler for the bidding update frame. The update frame is visible (and calling this method)
-- when a timer value was specified. The addon countdowns until 0 - and when it reaches 0 it stops
-- the current bid
-- ================================
function WebDKP_Bid_OnUpdate(elapsed)	
	this.TimeSinceLastUpdate = this.TimeSinceLastUpdate + elapsed; 	

	if (this.TimeSinceLastUpdate > 1.0) then
		this.TimeSinceLastUpdate = 0;
		-- decrement the count down
		WebDKP_bidCountdown = WebDKP_bidCountdown - 1;
		--WebDKP_Print(WebDKP_bidCountdown);
		WebDKP_BidFrame_Countdown:SetText("Time Left: "..WebDKP_bidCountdown.."s");
		
		
		if ( WebDKP_bidCountdown == 30 ) then				-- 30 seconds left
			local _,_,link = WebDKP_GetItemInfo(WebDKP_bidItem); 
			WebDKP_SendAnnouncementDefault("30 seconds remain for bidding on "..link.."!");
		
		elseif ( WebDKP_bidCountdown == 10 ) then				-- 10 seconds left
			local _,_,link = WebDKP_GetItemInfo(WebDKP_bidItem); 
			WebDKP_SendAnnouncementDefault("10 seconds remain for bidding on "..link.."!");
			
		elseif ( WebDKP_bidCountdown <= 0 ) then			-- countdown reached 0

			-- stop the bidding!
			WebDKP_Bid_StopBid();
		end
	end
end

-- ================================
-- Invoked when a user uses shift/alt/ctrl+click to display item details.
-- As long as a bid is not in progress and the big gui is displayed, 
-- fill the item information into the form
-- ================================
function WebDKP_Bid_ItemChatClick(link, text, button)

	if ( IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() ) then 
		if ( WebDKP_BidFrame:IsShown() and WebDKP_bidInProgress == false ) then
			local _,itemName,_ = WebDKP_GetItemInfo(link); 
			WebDKP_BidFrameItem:SetText(itemName);
			
			-- fill in the starting bid if we can find it
			startingBid = WebDKP_GetLootTableCost(itemName);
			if ( startingBid ~= nil ) then
				WebDKP_BidFrameStartingBid:SetText(startingBid);
			else
				WebDKP_BidFrameStartingBid:SetText(WebDKP_startingBid);
			end
		end
	end
end

-- ================================
-- Called when the user enters a new item name in the item name textbox. 
-- Checks to see if it can autoload a new starting bid
-- ================================
function WebDKP_Bid_ItemNameChanged()
	local itemName = WebDKP_BidFrameItem:GetText();
	
	startingBid = WebDKP_GetLootTableCost(itemName);
	
	if ( startingBid ~= nil ) then
		WebDKP_BidFrameStartingBid:SetText(startingBid);
	else
		WebDKP_BidFrameStartingBid:SetText(WebDKP_startingBid);
	end
end

-- ================================
-- Invoked when a user uses shift+click to display item details. 
-- As long as a bid is not in progress and the big gui is displayed, 
-- fill the item information into the form
-- ================================
function WebDKP_Bid_ShowConfirmFrame(title, cost)
	PlaySound("igMainMenuOpen");
	WebDKP_BidConfirmFrame:Show();
	
	WebDKP_BidConfirmFrameTitle:SetText(title);
	if(cost ~= nil) then
		WebDKP_BidConfirmFrameCost:SetText(cost);
	else
		WebDKP_BidConfirmFrameCost:SetText(0);
	end
end

-- ================================
-- Awards the currently selected player the currently 
-- ================================
function WebDKP_Bid_AwardPerson(cost) 
	local player,_ = WebDKP_Bid_GetSelected();

	--See how many points the person will lose
	local points = cost * -1;
	--put this into a points table for the add dkp method
	local playerTable = { [0] = {
				["name"] = player,
				["class"] = WebDKP_GetPlayerClass(player),
			}};
	--award the item
	
	WebDKP_AddDKP(points, WebDKP_bidItem, "true", playerTable)
	WebDKP_AnnounceAwardItem(points, WebDKP_bidItem, player);
	
	-- Update the table so we can see the new dkp status
	WebDKP_UpdateTableToShow();
	WebDKP_UpdateTable();
	
	PlaySound("LOOTWINDOWCOINSOUND");
	
	WebDKP_Bid_HideUI();
	
	-- record this item as having been given in a bid
	WebDKP_lastBidItem = WebDKP_bidItem;
end