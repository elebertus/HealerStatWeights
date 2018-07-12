local name, addon = ...;



function addon:IsDiscPriest()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.DPRIEST);
end

atonementQueue = addon.Queue.CreateSpellQueue(nil);



--[[----------------------------------------------------------------------------
	Disc Priest Mastery
		- Calculated on targets with atonement
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M,ME)
	if spellInfo.mst then
		if (not ME) then
			if addon.DiscPriest.AtonementTracker:UnitHasAtonement(destUnit) then
				ME = 1;
			end
		end
		
		if (ME == 1) then
			return heal / (1+M) / addon.MasteryConv;
		end
	end
	return 0;
end



--[[----------------------------------------------------------------------------
	Disc Priest Damage Event
		- Generates atonement events in the atonement queue
------------------------------------------------------------------------------]]
local function _DamageEvent(spellInfo,amount)
	if ( spellInfo.transfersToAtonement ) then
		local numAtonement = addon.DiscPriest.AtonementTracker.count;
		atonementQueue:Enqueue(numAtonement,spellInfo);
	end
end



--[[----------------------------------------------------------------------------
	Disc Priest Heal Event
		- Match spells from atonement queue & Allocate
		- Smite atonement is added to haste HPC computation
------------------------------------------------------------------------------]]
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
				addon.StatParser:IncFillerHealing(heal);
				fillerAlreadyAllocated=true;
			end
			
			if ( not fillerAlreadyAllocated and addon.DiscPriest.AtonementTracker:UnitHasAtonementFromPWS(destUnit) ) then
				--add non-smite atonement healing on PWS atonements to filler healing
				addon.StatParser:IncFillerHealing(heal);
			end
			
			addon.StatParser:Allocate(ev,spellInfo,heal,overhealing,destUnit,f,event.SP,event.C,addon.ply_crtbonus,event.H,event.V,event.M,event.ME,event.L);
		end
		return true; --skip normal computation of healing event
	end
	return false;
end



--[[----------------------------------------------------------------------------
	Power word: shield tracking
------------------------------------------------------------------------------]]
local PWSTracker = {};
function PWSTracker:ApplyOrRefresh(destGUID,amount)
	local u = addon.UnitManager:Get(destGUID);
	if ( u ) then
		if ( self[u] ) then
			self[u].original = math.max(amount-self[u].original,0);
			self[u].current = amount;
		else
			self[u] = {
				original = amount,
				current = amount
			};
		end
		
		if ( addon.DiscPriest.AtonementTracker:UnitHasAtonement(u) ) then
			self[u].masteryFlag = true;
		end
		
		self[u].C = addon.ply_crt;
		self[u].M = addon.ply_mst;
		self[u].V = addon.ply_vrs;
		self[u].I = addon.ply_sp;
		self[u].ts = GetTime();
		
		local cur_seg = addon.SegmentManager:Get(0);
		local ttl_seg = addon.SegmentManager:Get("Total");
		local spellInfo = addon.Spells:Get(addon.DiscPriest.PowerWordShield);
		
		if ( cur_seg ) then
			cur_seg:IncFillerCasts(spellInfo.manaCost);
		end
		
		if ( ttl_seg ) then
			cur_seg:IncFillerCasts(spellInfo.manaCost);
		end
	end
end

function PWSTracker:Absorb(destGUID,amount)
	local u = addon.UnitManager:Get(destGUID);
	if ( u ) then
		if ( self[u] ) then
			self[u].current = math.max(self[u].current - amount,0);
			
			local cur_seg = addon.SegmentManager:Get(0);
			local ttl_seg = addon.SegmentManager:Get("Total");
			
			if ( cur_seg ) then
				cur_seg:IncFillerHealing(amount);
			end
			
			if ( ttl_seg ) then
				cur_seg:IncFillerHealing(amount);
			end
		end
	end
end

function PWSTracker:Remove(destGUID,amount)
	local u = addon.UnitManager:Get(destGUID);
	if ( u ) then
		if ( self[u] ) then
			if ( amount == 0 ) then
				local spellInfo = addon.Spells:Get(addon.DiscPriest.PowerWordShield);
				local t = self[u];
				local originalHeal = t.original;
				local unit = addon.UnitManager:Get(u);
				local f = addon.StatParser:GetParserForCurrentSpec();
				local ME = masteryFlag and 1 or 0;
				
				if ( spellInfo and originalHeal and originalHeal>0 and unit and f ) then
					addon.StatParser:Allocate("SPELL_ABSORBED",spellInfo,originalHeal,0,unit,f,t.SP,t.C,addon.ply_crtbonus,0,t.V,t.M,ME,0);
				end
			end
			self[u] = nil;
		end
	end
end

local function hasShield(unit)
	for i=1,40,1 do
		local _,p,id,amt;
		
		if ( addon:isBFA() ) then
			  _,_,_,_,_,_,p,_,_,id,_,_,_,_,_,amt = UnitAura(unit,i);
		else
			_,_,_,_,_,_,_,p,_,_,id,_,_,_,_,_,amt = UnitAura(unit,i);
		end
		
		if ( not id ) then
			break;
		elseif (p == "player" and id == addon.DiscPriest.PowerWordShield ) then
			return amt;
		end
	end
	
	return false;
end

function PWSTracker:EncounterStart()
	for guid,u in pairs(self.UnitManager.units) do
		if ( u ) then
			local amount = hasShield(u);
			if ( amount and amount > 0 ) then
				self:ApplyOrRefresh(guid,amount);
			end
		end
	end
end
addon.DiscPriest.PWSTracker = PWSTracker;



--[[----------------------------------------------------------------------------
	Atonement tracking
------------------------------------------------------------------------------]]
local AtonementTracker = {
	count=0
};

function AtonementTracker:ApplyOrRefresh(destGUID)
	local u = addon.UnitManager:Get(destGUID);
	if ( u ) then
		if ( not self[u] ) then
			self.count = self.count + 1;
		end
		self[u] = GetTime();
	end
end

function AtonementTracker:Remove(destGUID)
	local u = addon.UnitManager:Get(destGUID);
	if ( u ) then
		if ( not self[u] ) then
			self.count = math.max(0,self.count - 1);
		end
		self[u] = nil
	end
end

local function hasAtonement()
end

function AtonementTracker:EncounterStart()
	for guid,u in pairs(self.UnitManager.units) do
		if ( u and hasAtonement(u) ) then
			self:ApplyOrRefresh(guid);
		end
	end
end

function AtonementTracker:UnitHasAtonement(destUnit)
	if ( self[u] ) then
		return true;
	else
		return false;
	end
end

function AtonementTracker:UnitHasAtonementFromPWS(destUnit)
	if ( destUnit ) then
		local pws_tbl = addon.DiscPriest.PWSTracker[destUnit];
		if ( pws_tbl ) then
			local t1 = self[destUnit];
			local t2 = pws_tbl.ts;
			
			if (math.abs(t1-t2) < 0.333) then
				return true;
			end
		end
	end
	
	return false;
end

--[[
	local atonementInfo = addon.DiscPriest.AtonementTracker:Get(destUnit);
	if ( atonementInfo and atonementInfo.sourceID == addon.DiscPriest.PowerWordShield and not fillerAlreadyAllocated) then]]
};




addon.DiscPriest.AtonementTracker = AtonementTracker;



addon.StatParser:Create(addon.SpellType.DPRIEST,nil,nil,nil,nil,_Mastery,nil,_HealEvent,_DamageEvent);