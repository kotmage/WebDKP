------------------------------------------------------------------------
-- TimedAward	
------------------------------------------------------------------------
-- Contains methods related to timed awards and the timed awards gui frame. 
-- TimedAwards provide a method to automatically award dkp at certain timed
-- intervals. Players can either set an award to continouously be made or 
-- for a 1 time award to be done after so many minutes.
--
-- Note, values for this module are contained in the WebDKP_Options datastructure. 
-- Important ones: "TimedAwardInProgress" and "TimedAwardTimer"
------------------------------------------------------------------------

-- ================================
-- Toggles displaying the timed award panel
-- ================================
function WebDKP_TimedAward_ToggleUI()
	if ( WebDKP_TimedAwardFrame:IsShown() ) then
		WebDKP_TimedAwardFrame:Hide();
	else
		WebDKP_TimedAwardFrame:Show();
		local time = WebDKP_TimedAwardFrameTime:GetText();
		if(time == nil or time == "") then
			WebDKP_TimedAwardFrameTime:SetText("5");
		end
		local dkp = WebDKP_TimedAwardFrameDkp:GetText();
		if(dkp == nil or dkp == "") then
			WebDKP_TimedAwardFrameDkp:SetText("0");
		end
	end
end


-- ================================
-- Toggles displaying mini timer
-- ================================
function WebDKP_TimedAward_ToggleMiniTimer()
	if ( WebDKP_TimedAward_MiniFrame:IsShown() ) then
		WebDKP_TimedAward_MiniFrame:Hide();
		WebDKP_Options["TimedAwardMiniTimer"] = 0;
	else
		WebDKP_TimedAward_MiniFrame:Show();
		WebDKP_Options["TimedAwardMiniTimer"] = 1;
	end
end

-- ================================
-- Shows the Bid UI
-- ================================
function WebDKP_TimedAward_ShowUI()
	WebDKP_TimedAwardFrame:Show();
	local time = WebDKP_TimedAwardFrameTime:GetText();
	if(time == nil or time == "") then
		WebDKP_TimedAwardFrameTime:SetText("0");
	end
	local dkp = WebDKP_TimedAwardFrameDkp:GetText();
	if(dkp == nil or dkp == "") then
		WebDKP_TimedAwardFrameTime:SetText("0");
	end
end

-- ================================
-- Hides the Bid UI
-- ================================
function WebDKP_TimedAward_HideUI()
	WebDKP_TimedAwardFrame:Hide();
end

-- ================================
-- Triggers The Timer to Start / Stop
-- ================================
function WebDKP_TimedAward_ToggleTimer()
	if ( WebDKP_Options["TimedAwardInProgress"] == true ) then			--Stop the timer
		WebDKP_Options["TimedAwardInProgress"] = false;
		WebDKP_TimedAwardFrameStartStopButton:SetText("Start");
		WebDKP_TimedAward_UpdateFrame:Hide();
		WebDKP_TimedAward_UpdateText();

	else
		WebDKP_Options["TimedAwardInProgress"] = true;			--Start the timer
		
		if ( WebDKP_Options["TimedAwardTimer"] == 0 ) then
			local time = WebDKP_TimedAwardFrameTime:GetText();
			if(time == nil or time == "") then
				time = 5;
			end
			WebDKP_Options["TimedAwardTimer"] = time * 60;
		end
		
		WebDKP_TimedAwardFrameStartStopButton:SetText("Stop");
		WebDKP_TimedAward_UpdateFrame:Show();
		WebDKP_TimedAward_UpdateText();
	end
end

-- ================================
-- Resets the timer to start counting from scartch again
-- ================================
function WebDKP_TimedAward_ResetTimer()
	local time = WebDKP_TimedAwardFrameTime:GetText();
	if(time == nil or time == "") then
		time = 5;
	end
	WebDKP_Options["TimedAwardTimer"] = time * 60;
	WebDKP_TimedAward_UpdateText();
end


-- ================================
-- Event handler for the bidding update frame. The update frame is visible (and calling this method)
-- when a timer value was specified. The addon countdowns until 0 - and when it reaches 0 it stops
-- the current bid
-- ================================
function WebDKP_TimedAward_OnUpdate(elapsed)	
	this.TimeSinceLastUpdate = this.TimeSinceLastUpdate + elapsed; 	

	if (this.TimeSinceLastUpdate > 1.0) then
		this.TimeSinceLastUpdate = 0;
		-- decrement the count down
		WebDKP_Options["TimedAwardTimer"] = WebDKP_Options["TimedAwardTimer"] - 1;
		
		WebDKP_TimedAward_UpdateText();
		
		--update the gui
		
		if ( WebDKP_Options["TimedAwardTimer"] <= 0 ) then			-- countdown reached 0
			WebDKP_TimedAward_PerformAward();

			-- if we are set to repeat the awards, go ahead and start the timer again
			if ( WebDKP_Options["TimedAwardRepeat"] == 1 ) then
				
				WebDKP_TimedAward_ResetTimer();
			else
				-- it was a one time award, stop everything so we don't start going into negative numbers
				WebDKP_Options["TimedAwardInProgress"] = false;
				WebDKP_TimedAwardFrameStartStopButton:SetText("Start");
				WebDKP_TimedAward_UpdateFrame:Hide();
			end
		end
	end
end

-- ================================
-- Updates the timer gui to show how many minutes / seconds are left
-- ================================
function WebDKP_TimedAward_UpdateText()
	
	local toDisplay = "";
	local minutes = floor(WebDKP_Options["TimedAwardTimer"] / 60);
	local seconds = WebDKP_Options["TimedAwardTimer"] - floor(WebDKP_Options["TimedAwardTimer"] / 60) * 60; 
		-- MOD modulo doesn't work, replaced with its Lua definition a % b == a - math.floor(a/b)*b
	
	if ( minutes > 0 ) then
		toDisplay = toDisplay..minutes..":";
	end
	if ( seconds < 10 ) then
		seconds = "0"..seconds;
	end
	toDisplay = toDisplay..seconds;
	
	WebDKP_TimedAwardFrameTimeLeft:SetText("Time Left: "..toDisplay);
	WebDKP_TimedAward_MiniFrameTimeLeft:SetText(toDisplay);
	
end


-- ================================
-- Performs an automatted award by awarding everyone in the current group the 
-- amount of dkp specified in the timed award gui box. Should be 
-- called when the auto timer finishes
-- ================================
function WebDKP_TimedAward_PerformAward() 

	PlaySound("QUESTCOMPLETED");

	WebDKP_UpdatePlayersInGroup();
	local dkp = WebDKP_TimedAwardFrameDkp:GetText();
	if(dkp == nil or dkp == "") then
		dkp = 0;
	end
	
	WebDKP_AddDKP(dkp, "AutoAward", false , WebDKP_PlayersInGroup);
	
	WebDKP_AnnounceTimedAward( WebDKP_TimedAwardFrameTime:GetText(), dkp ); 
	
	WebDKP_Refresh()
	
end