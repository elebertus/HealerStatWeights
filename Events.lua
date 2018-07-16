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
					  ts,ev,_,sourceGUID, _, _, _, destGUID, destName, _, _, spellID,_, _, amount, overhealing, absorbed, critFlag, arg19, _, _, arg22 = CombatLogGetCurrentEventInfo();
		else	  
			        _,ts,ev,_,sourceGUID, _, _, _, destGUID, destName, _, _, spellID,_, _, amount, overhealing, absorbed, critFlag, arg19, _, _, arg22 = unpack({...});
		end
				
		--Track healing amount of mana spent on casting filler spells (for mp5 calculation)
		if ( sourceGUID == UnitGUID("Player") ) then
			if ( ev == "SPELL_CAST_SUCCESS" ) then
				local spellInfo = addon.Spells:Get(spellID);
				if ( spellInfo and spellInfo.filler) then
					local cur_seg = addon.SegmentManager:Get(0);
					local ttl_seg = addon.SegmentManager:Get("Total");
					
					local cost = spellInfo.manaCost;
					if ( spellInfo.manaCostAdjustmentMultiplier ) then
						cost = cost * spellInfo.manaCostAdjustmentMultiplier();
					end
					
					if ( cur_seg ) then
						cur_seg:IncFillerCasts(cost,spellInfo.manaCostAdjustmentMultiplier);
					end
					
					if ( ttl_seg ) then
						ttl_seg:IncFillerCasts(cost,spellInfo.manaCostAdjustmentMultiplier);
					end
					
					if spellInfo.spellID == addon.DiscPriest.SmiteCast then
						addon.DiscPriest:SmiteCastCounter();
					end
				end
			end
		
			--track summons (totems) spawned
			if ( ev == "SPELL_SUMMON" ) then
				summons[destGUID] = true;
			end
		
			if ( spellID == addon.Shaman.Resurgence ) then --shaman resurgence
				if ( ev == "SPELL_ENERGIZE" ) then
					local cur_seg = addon.SegmentManager:Get(0);
					local ttl_seg = addon.SegmentManager:Get("Total");
					cur_seg:IncManaRestore(amount);
					ttl_seg:IncManaRestore(amount);
				end
			elseif ( addon.BeaconBuffs[spellID] ) then --paladin beacon
				if ( ev == "SPELL_AURA_APPLIED") then
					addon.BeaconCount = addon.BeaconCount + 1;
					addon.BeaconUnits[destGUID]=true;	
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.BeaconCount = addon.BeaconCount - 1;
					addon.BeaconUnits[destGUID]=false;
				end
			elseif ( spellID == addon.HolyPriest.EchoOfLight ) then --holy priest mastery (echo of light) 
				if ( ev == "SPELL_AURA_APPLIED" ) then
					addon.HolyPriest.EOLTracker:Apply(destGUID);
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.HolyPriest.EOLTracker:Remove(destGUID);
				elseif ( ev == "SPELL_AURA_REFRESH" ) then
					addon.HolyPriest.EOLTracker:Refresh(destGUID);
				end
			elseif ( spellID == addon.DiscPriest.AtonementBuff ) then -- Disc atonement tracking
				if ( ev == "SPELL_AURA_APPLIED" ) then
					addon.DiscPriest.AtonementTracker:ApplyOrRefresh(destGUID);
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.DiscPriest.AtonementTracker:Remove(destGUID);
				elseif ( ev == "SPELL_AURA_REFRESH" ) then
					addon.DiscPriest.AtonementTracker:ApplyOrRefresh(destGUID);
				end
			elseif ( spellID == addon.DiscPriest.LuminousBarrierAbsorb ) then --Luminous Barrier Tracking
				if ( ev == "SPELL_AURA_APPLIED" ) then
					addon.DiscPriest.LBTracker:Apply(destGUID,overhealing);
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.DiscPriest.LBTracker:Remove(destGUID,overhealing);
				end
			elseif ( spellID == addon.DiscPriest.PowerWordShield ) then -- Disc PW:S tracking (part 1 of 2)
				if ( ev == "SPELL_AURA_APPLIED" ) then
					addon.DiscPriest.PWSTracker:ApplyOrRefresh(destGUID,overhealing); --16th arg is amount
				elseif ( ev == "SPELL_AURA_REMOVED" ) then
					addon.DiscPriest.PWSTracker:Remove(destGUID,overhealing); --16th arg is amount
				elseif ( ev == "SPELL_AURA_REFRESH" ) then
					addon.DiscPriest.PWSTracker:ApplyOrRefresh(destGUID,overhealing); --16th arg is amount
				end
			end
		end
		
		--disc PW:S tracking (part 2 of 2)
		if ( ev == "SPELL_ABSORBED" ) then
			local abs_srcGUID, abs_spellID, abs_amount;
			
			if ( type(spellID) == "number" ) then
				--absorbtion came from spellcast. srcguid arg15, spellid arg19, amt arg22
				abs_srcGUID = amount;
				abs_spellID = arg19;
				abs_amount = arg22;
			else
				--absorption from non-spellcast. srcguid arg12, spellid arg16, amt arg19
				abs_srcGUID = spellID;
				abs_spellID = overhealing;
				abs_amount = arg19;
			end
	
			if ( abs_srcGUID == UnitGUID("Player") or summons[abs_srcGUID] ) then
				if (abs_spellID == addon.DiscPriest.PowerWordShield ) then 
					addon.DiscPriest.PWSTracker:Absorb(destGUID,abs_amount);
				elseif ( abs_spellID == addon.DiscPriest.SmiteAbsorb ) then
					addon.DiscPriest:AbsorbSmite(destGUID,abs_amount);
				elseif ( abs_spellID == addon.Shaman.EarthenWallTotem ) then
					addon.Shaman:AbsorbEarthenWallTotem(destGUID,abs_amount);
				end				
			end	
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
				addon.StatParser:DecompDamageDone(amount,spellID);	
			end
		end
	
		if ( ev == "SWING_DAMAGE" ) then
			if ( summons[sourceGUID] ) then --shadowfiend/mindbender
				addon.StatParser:DecompDamageDone(spellID,addon.DiscPriest.PetAttack); --13th arg = amount
			end
		end
	
		--redirect spell events to the stat parsers.
		if ( ev == "SPELL_PERIODIC_DAMAGE" or ev == "SPELL_DAMAGE" ) then 
			if ( destGUID == UnitGUID("Player") ) then
				addon.StatParser:DecompDamageTaken(amount);
			end
		elseif ( ev == "SPELL_HEAL" or ev == "SPELL_PERIODIC_HEAL"  ) then
			if ( (sourceGUID == UnitGUID("Player")) or summons[sourceGUID] ) then
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

