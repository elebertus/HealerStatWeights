local name, addon = ...;



function addon:IsDiscPriest()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.DPRIEST);
end

atonementQueue = addon.Queue.CreateSpellQueue(nil);





--[[----------------------------------------------------------------------------
	Disc Priest BFA Mastery
		- Calculated on targets with atonement
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M)
	return 0;
end

--handle PWS?


--handle damage which generates atonement
local function _DamageEvent(spellInfo,amount)
	if ( spellInfo.transfersToAtonement ) then
		local numAtonement = addon.AtonementCount;
		atonementQueue:Enqueue(numAtonement,spellInfo);
	end
end

--handle atonement healing
local function _HealEvent(ev,spellInfo,heal,overhealing,destUnit,f)
	if ( spellInfo.spellID == addon.DiscPriest.AtonementHeal ) then
		local event = atonementQueue:MatchHeal();
		
		if ( event and event.data ) then
			local cur_seg = addon.SegmentManager:Get(0);
			local ttl_seg = addon.SegmentManager:Get("Total");
			local fillerAlreadyAllocated = false;
			if ( event.data.spellID == addon.DiscPriest.SmiteDamage ) then
				--add healing to smite bucket
				cur_seg:IncBucket("smiteHealing",heal);
				ttl_seg:IncBucket("smiteHealing",heal);
				
				--add healing to filler spells bucket
				cur_seg:IncFillerHealing(heal);
				ttl_seg:IncFillerHealing(heal);
				fillerAlreadyAllocated=true;
			end
			
			local atonementInfo = addon.AtonementTracker:Get(destUnit);
			if ( atonementInfo and atonementInfo.sourceID == addon.DiscPriest.PWS_Buff and not fillerAlreadyAllocated) then
				--add non-smite atonement healing on PWS buffs to filler spells bucket
				cur_seg:IncFillerHealing(heal);
				ttl_seg:IncFillerHealing(heal);
			end
			
			if ( overhealing == 0 ) then
				local _I,_C,_Hhpm,_Hhpct,_M,_V,_L = 0,0,0,0,0,0,0;
				
				_I 	 			= addon.BaseParsers.Intellect(ev,spellInfo,heal,destUnit,event.SP,f);
				_C				= addon.BaseParsers.CriticalStrike(ev,spellInfo,heal,destUnit,event.C,addon.ply_crtbonus,f) ;
				_Hhpm,_Hhpct	= addon.BaseParsers.Haste(ev,spellInfo,heal,destUnit,event.H,f);
				_M	 			= _Mastery(ev,spellInfo,heal,destUnit,event.M,event.ME);
				_V	 			= addon.BaseParsers.Versatility(ev,spellInfo,heal,destUnit,event.V,f);
				_L	 			= addon.BaseParsers.Leech(ev,spellInfo,heal,destUnit,event.L,f);

				--Add derivatives to current & total segments
				if ( cur_seg ) then
					cur_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
				end
				if ( ttl_seg ) then
					ttl_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
				end
				
				addon:UpdateDisplayStats();
			end
		end
		return true; --skip normal computation of healing event
	end
	return false;
end



addon.StatParser:Create(addon.SpellType.DPRIEST,nil,nil,nil,nil,_Mastery,nil,_HealEvent,_DamageEvent);