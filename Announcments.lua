------------------------------------------------------------------------
-- ANNOUNCMENETS	
------------------------------------------------------------------------
-- Contains methods related to the raid announcemenets in game whenever
-- DKP is awarded. 
------------------------------------------------------------------------



-- The following are award strings that the addon uses. If you wish to modify what the addon says for
-- awards you just need to edit these strings. 
-- Do display a new line in your message use \n. 

WebDKP_ItemAward =			"WebDKP: $player awarded $item for: $cost dkp.";

WebDKP_ItemAwardZeroSum =	"WebDKP: $dkp awarded to all players for ZeroSum";

WebDKP_DkpAwardAll =		"WebDKP: $dkp dkp given to all players for: $reason.";

WebDKP_DkpAwardSome =		"WebDKP: $dkp dkp given to selected players for: $reason. \nRecieving players have all be whispered.";

WebDKP_BidStart =			"WebDKP: Bidding has started on $item! $time " ..
							"$startingBid"..
							"$instructions";

WebDKP_BidEnd =				"WebDKP: Bidding has ended for $item";

WebDKP_TimedAward =			"WebDKP: $minutes Minute Timed Award of $dkp dkp Given";

-- ================================
-- Returns the location where notifications should be sent to. 
-- "Raid" or "Party". If player is in neither a raid or a party, returns
-- "None"
-- ================================
function WebDKP_GetTellLocation()
	
	local numberInRaid = GetNumRaidMembers();
	local numberInParty = GetNumPartyMembers();
	
	if( numberInRaid > 0 ) then
		return "RAID";
	elseif (numberInParty > 0 ) then
		return "PARTY";
	else
		return "NONE";
	end
end

-- ================================
-- Makes an announcement that a user has recieved an item. 
-- ================================
function WebDKP_AnnounceAwardItem(cost, item, player)
	local tellLocation = WebDKP_GetTellLocation();
	cost = cost * -1;
	
	-- Announce the item
	-- (convert the item to a link)
	local _,_,link = WebDKP_GetItemInfo(item);
	local toSay =	string.gsub(WebDKP_ItemAward, "$player", player);
	toSay =	string.gsub(toSay, "$item", link);
	toSay =	string.gsub(toSay, "$cost", cost);
	
	WebDKP_SendAnnouncement(toSay,tellLocation);
	
	
	-- If using Zero Sum announce the zero sum award
	if ( WebDKP_WebOptions["ZeroSumEnabled"]==1) then
		local numPlayers = WebDKP_GetTableSize(WebDKP_PlayersInGroup);
		if ( numPlayers ~= 0 ) then 
			local toAward = (cost) / numPlayers;
			toAward = WebDKP_ROUND(toAward, 2 );
			local toSay =	string.gsub(WebDKP_ItemAwardZeroSum, "$dkp", toAward);
			WebDKP_SendAnnouncement(toSay, tellLocation);
		end
	end

end

-- ================================
-- Makes an announcement that the raid (or a set of users) has recieved dkp
-- ================================
function WebDKP_AnnounceAward(dkp, reason)
	local tellLocation = WebDKP_GetTellLocation();
	local allGroupSelected = WebDKP_AllGroupSelected();

	-- Everyone recieved the award
	if ( allGroupSelected == true ) then
	
		-- Announce the award
		local toSay =	string.gsub(WebDKP_DkpAwardAll, "$dkp", dkp);
		toSay =	string.gsub(toSay, "$reason", reason);
		WebDKP_SendAnnouncement(toSay,tellLocation);
	
	
	-- Only some people recieved the award
	else
		
		
		-- Announce the award
	
		local toSay =	string.gsub(WebDKP_DkpAwardSome, "$dkp", dkp);
		toSay =	string.gsub(toSay, "$reason", reason);
		WebDKP_SendAnnouncement(toSay,tellLocation);
		
		-- now increment through the selected players and announce them
	
		for key_name, v in pairs(WebDKP_DkpTable) do
			if ( type(v) == "table" ) then
				if( v["Selected"] ) then
					--WebDKP_SendAnnouncement(key_name,tellLocation);
					WebDKP_SendWhisper(key_name,"You have been awarded "..dkp.." dkp");
				end
			end
		end
	end
end

-- ================================
-- Announces that bidding has started. 
-- Accepts item name and the time (in seconds) that bidding
-- will go for
-- ================================
function WebDKP_AnnounceBidStart(item, time, startingBid) 
	local tellLocation = WebDKP_GetTellLocation();
	if(time == 0 or time == nil or time =="" or time=="0") then
		time = "";
	else
		time = "("..time.."s)";
	end
	
	local instructions; 
	if ( WebDKP_Options["BidFixedBidding"] == 1 ) then
		instructions =	"To place a bid say !need in a raid/party/whisper. "
	else
		instructions =	"Chcete-li nabidnout DKP za item napiste bid <value> do chatu raid/party "..
						"(pro priklad: bid 250)";
	end
	
	
	local startingBidText = ""; 
	if ( startingBid > 0 ) then
		startingBidText =	"Bidding starts at "..startingBid.." dkp. ";
	end
	
	local toSay =	string.gsub(WebDKP_BidStart, "$item", item);
	toSay =	string.gsub(toSay, "$time", time);
	toSay =	string.gsub(toSay, "$startingBid", startingBidText);
	toSay =	string.gsub(toSay, "$instructions", instructions);
	WebDKP_SendAnnouncement(toSay,tellLocation);
end

-- ================================
-- Announces that bidding has finished
-- Accepts itemname, name of highest bidder, bid dkp
-- ================================
function WebDKP_AnnounceBidEnd(item, name, dkp)
	

	if(name == nil or name == "") then
		name = "noone";
		dkp = 0;
	end
	--convert the item to a link
	local _,_,link = WebDKP_GetItemInfo(item);
	local tellLocation = WebDKP_GetTellLocation();
	local toSay =	string.gsub(WebDKP_BidEnd, "$item", link);
	toSay =	string.gsub(toSay, "$name", name);
	toSay =	string.gsub(toSay, "$dkp", dkp);
	WebDKP_SendAnnouncement(toSay,tellLocation);
end

-- ================================
-- Announces that an automatted timed award has just been given
-- Minutes = # of minutes that the timer is on
-- Dkp = How much dkp was just given
-- ================================
function WebDKP_AnnounceTimedAward(minutes, dkp) 
	local tellLocation = WebDKP_GetTellLocation();
	local toSay =	string.gsub(WebDKP_TimedAward, "$minutes", minutes);
	toSay =	string.gsub(toSay, "$dkp", dkp);
	WebDKP_SendAnnouncement(toSay,tellLocation);
end

-- ================================
-- Sends out an announcent to the screen. 
-- Possible locations are:
-- "RAID", "PARTY", "GUILD", or "NONE"
-- If "NONE" is selected it will output to the players console.
-- This method will also look for line breaks in 'toSay'. If a \n is seen 
-- in the text, the text will be divided into seperate messages at that point. 
-- Example: Hello \n there!
--			Zedd: Hello
--			Zedd: there!
-- ================================
function WebDKP_SendAnnouncement(toSay, location)
	if ( location == "NONE" ) then
		WebDKP_Print(toSay);
	else
		local newLineLoc = string.find(toSay,"\n");
		local tempToSay;
		local breaker = 0 ; 
		--WebDKP_Print("New line loc: "..newLineLoc);
		while (newLineLoc  ~= nil ) do 
			tempToSay = string.sub(toSay,0,newLineLoc-1);
			SendChatMessage(tempToSay,location);
			--trim to say of what we just said
			toSay = string.sub(toSay,newLineLoc+1,string.len(toSay));
			-- get the start of the next new line
			newLineLoc = string.find(toSay,"\n");
		end
		-- finish saying what is left
		SendChatMessage(toSay,location);
	end
end

-- ================================
-- Sends an announcement to the default location
-- ================================
function WebDKP_SendAnnouncementDefault(toSay)
	local tellLocation = WebDKP_GetTellLocation();
	WebDKP_SendAnnouncement(toSay, tellLocation);
end