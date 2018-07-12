local name, addon = ...;
addon.inCombat=false;
addon.currentSegment=0;




--[[----------------------------------------------------------------------------
	Combat Start
------------------------------------------------------------------------------]]
function addon.hsw:PLAYER_REGEN_DISABLED()
	addon:StartFight(nil);
end



--[[----------------------------------------------------------------------------
	Combat End
------------------------------------------------------------------------------]]
function addon.hsw:PLAYER_REGEN_ENABLED()
	addon:EndFight();
end



--[[----------------------------------------------------------------------------
	Encounter start
------------------------------------------------------------------------------]]
function addon.hsw:ENCOUNTER_START(eventName,encounterId,encounterName)
	addon:StartFight(encounterName);
end



--[[----------------------------------------------------------------------------
	Spec Changed
------------------------------------------------------------------------------]]
function addon.hsw:PLAYER_SPECIALIZATION_CHANGED()
	addon:AdjustVisibility();
end



--[[----------------------------------------------------------------------------
	PLAYER_ENTERING_WORLD
------------------------------------------------------------------------------]]
function addon.hsw:PLAYER_ENTERING_WORLD()
	addon:SetupConversionFactors();
	addon:SetupFrame();
	addon:AdjustVisibility();
end



--[[----------------------------------------------------------------------------
	COMBAT_RATING_UPDATE
------------------------------------------------------------------------------]]
function addon.hsw:COMBAT_RATING_UPDATE()
	addon:UpdatePlayerStats();
end



--[[----------------------------------------------------------------------------
	GROUP_ROSTER_UPDATE
------------------------------------------------------------------------------]]
function addon.hsw:GROUP_ROSTER_UPDATE()
	if ( addon.inCombat ) then --update unitmanager if someone leaves/joins group midcombat.
		addon.UnitManager:Cache(); 
	end
end



--[[----------------------------------------------------------------------------
	COMBAT_LOG_EVENT_UNFILTERED
------------------------------------------------------------------------------]]
local summons = {};

function addon.hsw:COMBAT_LOG_EVENT_UNFILTERED(...)
	if ( addon.inCombat ) then
		if ( addon:isBFA() ) then
					  ts,ev,_,sourceGUID, _, _, _, destGUID, destName, _, _, spellID,_, _, amount, overhealing, absorbed, critFlag, pws_id, _, _, pws_abs = CombatLogGetCurrentEventInfo();
		else	  
			        _,ts,ev,_,sourceGUID, _, _, _, destGUID, destName, _, _, spellID,_, _, amount, overhealing, absorbed, critFlag, pws_id, _, _, pws_abs = unpack({...});
		end
			
		
		--Track healing amount of mana spent on casting filler spells (for mp5 calculation)
		if ( sourceGUID == UnitGUID("Player") ) then
			if ( ev == "SPELL_CAST_SUCCESS" ) then
				local spellInfo = addon.Spells:Get(spellID);
				if ( spellInfo and spellInfo.filler) then
					local cur_seg = addon.SegmentManager:Get(0);
					local ttl_seg = addon.SegmentManager:Get("Total");
					
					if ( cur_seg ) then
						cur_seg:IncFillerCasts(spellInfo.manaCost);
					end
					
					if ( ttl_seg ) then
						ttl_seg:IncFillerCasts(spellInfo.manaCost);
					end
				end
			end
		
			--track summons (totems) spawned
			if ( ev == "SPELL_SUMMON" ) then
				summons[destGUID] = true;
			end
		
			--Track mana gained by resurgence
			if ( spellID == addon.Shaman.Resurgence ) then
				if ( ev == "SPELL_ENERGIZE" ) then
					local cur_seg = addon.SegmentManager:Get(0);
					local ttl_seg = addon.SegmentManager:Get("Total");
					cur_seg:IncManaRestore(amount);
					ttl_seg:IncManaRestore(amount);
				end
			end
		
			--paladin beacon tracking
			if ( addon.BeaconBuffs[spellID] ) then
				if ( ev == "SPELL_AURA_APPLIED") then
					addon.BeaconCount = addon.BeaconCount + 1;
					addon.BeaconUnits[destGUID]=true;	
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.BeaconCount = addon.BeaconCount - 1;
					addon.BeaconUnits[destGUID]=false;
				end
			end
			
			-- Disc atonement tracking
			if ( spellID == addon.DiscPriest.AtonementBuff ) then
				if ( ev == "SPELL_AURA_APPLIED" ) then
					addon.DiscPriest.AtonementTracker:ApplyOrRefresh(destGUID);
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.DiscPriest.AtonementTracker:Remove(destGUID);
				elseif ( ev == "SPELL_AURA_REFRESHED" ) then
					addon.DiscPriest.AtonementTracker:ApplyOrRefresh(destGUID);
				end
			end		
			
			-- Disc PW:S tracking (part 1 of 2)
			if ( spellID == addon.DiscPriest.PowerWordShield ) then
				if ( ev == "SPELL_AURA_APPLIED" ) then
					addon.DiscPriest.PWSTracker:ApplyOrRefresh(destGUID,overhealing); --16th arg is amount
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.DiscPriest.PWSTracker:Remove(destGUID,overhealing); --16th arg is amount
				elseif ( ev == "SPELL_AURA_REFRESHED" ) then
					addon.DiscPriest.PWSTracker:ApplyOrRefresh(destGUID,overhealing); --16th arg is amount
				end
			end	
		end
		
		--disc PW:S tracking (part 2 of 2)
		if ( ev == "SPELL_AURA_ABSORBED" and amount == UnitGUID("Player") and pws_id == adon.DiscPriest.PowerWordShield ) then
			addon.DiscPriest.PWSTracker:Absorb(destGUID,pws_abs);
		end
		
		if ( ev == "SPELL_DAMAGE" or ev == "SPELL_PERIODIC_DAMAGE" ) then
			--set current segment name (if not already set)
			local segment = addon.SegmentManager:Get(0);
			if ( not segment.nameSet ) then
				destGUID = string.lower(destGUID);
				if ( not destGUID:find("player") and not destGUID:find("pet") ) then
					addon.SegmentManager:SetCurrentId(destName);
				end
			end
			
			--redirect event to the stat parser
			if (sourceGUID == UnitGUID("Player")) then 
				addon.StatParser:DecompDamageDone(amount);
			end
		end
	
		--redirect spell events to the stat parsers.
		if ( ev == "SPELL_PERIODIC_DAMAGE" or ev == "SPELL_DAMAGE" ) then 
			if ( destGUID == UnitGUID("Player") ) then
				addon.StatParser:DecompDamageTaken(amount);
			end
		elseif ( ev == "SPELL_HEAL" or ev == "SPELL_PERIODIC_HEAL"  ) then
			if ( (sourceGUID == UnitGUID("Player")) or summons[sourceGUID] ) then
				print("we got there.",ev,spellID);
				addon.StatParser:DecompHealingForCurrentSpec(ev,destGUID,spellID,critFlag,amount-overhealing,overhealing);
			end
		end
	end
end



--[[----------------------------------------------------------------------------
	Unit Events
------------------------------------------------------------------------------]]
local function UnitEventHandler(_,e,...)
	if ( e == "UNIT_AURA" ) then
		addon.BuffTracker:UpdatePlayerBuffs();
	elseif ( e == "UNIT_STATS") then
		addon:UpdatePlayerStats();
	elseif ( e == "UNIT_SPELLCAST_START" ) then
		addon.CastTracker:StartCast(...);
	elseif ( e == "UNIT_SPELLCAST_SUCCEEDED" ) then
		addon.CastTracker:FinishCast(...);
	end
end



function addon:SetupUnitEvents()
	self.frame:RegisterUnitEvent("UNIT_AURA","Player");
	self.frame:RegisterUnitEvent("UNIT_STATS","Player");
	self.frame:RegisterUnitEvent("UNIT_SPELLCAST_START","Player");
	self.frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","Player");
	self.frame:SetScript("OnEvent",UnitEventHandler);
end



--[[----------------------------------------------------------------------------
	Events
------------------------------------------------------------------------------]]
addon.hsw:RegisterEvent("PLAYER_REGEN_DISABLED")
addon.hsw:RegisterEvent("PLAYER_REGEN_ENABLED")
addon.hsw:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
addon.hsw:RegisterEvent("PLAYER_ENTERING_WORLD")
addon.hsw:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon.hsw:RegisterEvent("ENCOUNTER_START");
addon.hsw:RegisterEvent("COMBAT_RATING_UPDATE");
addon.hsw:RegisterEvent("GROUP_ROSTER_UPDATE");

