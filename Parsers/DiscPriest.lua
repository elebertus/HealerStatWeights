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
	if ( spellInfo.spellID == addon.DiscPriest.AtonementHeal1 or spellInfo.spellID == addon.DiscPriest.AtonementHeal2 ) then
		local event = atonementQueue:MatchHeal();
		
		if ( event and event.data ) then
			local cur_seg = addon.SegmentManager:Get(0);
			local ttl_seg = addon.SegmentManager:Get("Total");
			local fillerAlreadyAllocated = false;
			if ( event.data.spellID == addon.DiscPriest.SmiteCast ) then
				--add healing to smite bucket
				cur_seg:IncSmiteAtonementHealing(heal);
				ttl_seg:IncSmiteAtonementHealing(heal);
				
				--add healing to filler spells bucket
				addon.StatParser:IncFillerHealing(heal);
				fillerAlreadyAllocated=true;
			end
			
			if ( not fillerAlreadyAllocated and addon.DiscPriest.AtonementTracker:UnitHasAtonementFromPWS(destUnit) ) then
				--add non-smite atonement healing on PWS atonements to filler healing
				addon.StatParser:IncFillerHealing(heal);
			end
			
			print(spellInfo.spellID,event.data.spellID,event.data.hstHPM);
			addon.StatParser:Allocate(ev,event.data,heal,overhealing,destUnit,f,event.SP,event.C,addon.ply_crtbonus,event.H,event.V,event.M,nil,event.L);
		end
		return true; --skip normal computation of healing event
	end
	return false;
end



--[[----------------------------------------------------------------------------
	Luminous Barrier tracking
------------------------------------------------------------------------------]]
local LBTracker = {};
function LBTracker:Apply(destGUID,amount)
	local u = addon.UnitManager:Find(destGUID);
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
		self[u].SP = addon.ply_sp;
		self[u].C = addon.ply_crt;
		self[u].CB = addon.ply_crtbonus;
		self[u].H = addon.ply_hst;
		self[u].M = addon.ply_mst;
		self[u].V = addon.ply_vrs;
		self[u].I = addon.ply_sp;
		self[u].ts = GetTime();
	end
end

function LBTracker:Remove(destGUID,amount)
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		if ( self[u] ) then
			if ( amount == 0 ) then
				local t = self[u];
				if ( t ) then
					local spellInfo = addon.Spells:Get(addon.DiscPriest.LuminousBarrierAbsorb);
					local originalHeal = t.original;
					local f = addon.StatParser:GetParserForCurrentSpec();
					local ME = t.masteryFlag and 1 or 0;
					
					if ( spellInfo and originalHeal and originalHeal>0 and f ) then
						addon.StatParser:IncHealing(originalHeal,spellInfo.filler,true);
						addon.StatParser:Allocate("SPELL_ABSORBED",spellInfo,originalHeal,0,u,f,t.SP,t.C,t.CB,t.H,t.V,t.M,ME,0);
					end
				end
			end
			self[u] = nil;
		end
	end
end

local function hasLB(unit)
	for i=1,40,1 do
		local _,p,id,amt;
		
		if ( addon:isBFA() ) then
			  _,_,_,_,_,_,p,_,_,id,_,_,_,_,_,amt = UnitAura(unit,i);
		else
			_,_,_,_,_,_,_,p,_,_,id,_,_,_,_,_,amt = UnitAura(unit,i);
		end
		
		if ( not id ) then
			break;
		elseif (p == "player" and id == addon.DiscPriest.LuminousBarrierAbsorb ) then
			return amt;
		end
	end
	
	return false;
end

function LBTracker:EncounterStart()
	for guid,u in pairs(addon.UnitManager.units) do
		if ( u ) then
			local amount = hasLB(u);
			if ( amount and amount > 0 ) then
				self:ApplyOrRefresh(guid,amount);
			end
		end
	end
end
addon.DiscPriest.LBTracker = LBTracker;



--[[----------------------------------------------------------------------------
	Smite absorption tracking
------------------------------------------------------------------------------]]
function addon.DiscPriest:AbsorbSmite(destGUID,amount)
	local spellInfo = addon.Spells:Get(addon.DiscPriest.SmiteAbsorb);
	local u = addon.UnitManager:Find(destGUID);
	local f = addon.StatParser:GetParserForCurrentSpec();
	
	if ( spellInfo and u and f and amount and amount>0 ) then
		addon.StatParser:IncHealing(amount,true,true);
		addon.StatParser:Allocate("SPELL_ABSORBED",spellInfo,amount,0,u,f,addon.ply_sp,addon.ply_crt,addon.ply_crtbonus,addon.ply_hst,addon.ply_vrs,addon.ply_mst,0,0);
	end
end

function addon.DiscPriest:SmiteCastCounter()
	local cur_seg = addon.SegmentManager:Get(0);
	local ttl_seg = addon.SegmentManager:Get("Total");
	cur_seg:IncSmiteCasts();
	ttl_seg:IncSmiteCasts();
end



--[[----------------------------------------------------------------------------
	Power word: shield tracking
------------------------------------------------------------------------------]]
local PWSTracker = {};
function PWSTracker:ApplyOrRefresh(destGUID,amount)
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		if ( self[u] ) then
			self[u].original = math.max(amount-self[u].current,0); --its possible to remove shield by overwriting a crit shield. So we clamp at 0.
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
		self[u].SP = addon.ply_sp;
		self[u].C = addon.ply_crt;
		self[u].CB = addon.ply_crtbonus;
		self[u].M = addon.ply_mst;
		self[u].H = addon.ply_hst;
		self[u].V = addon.ply_vrs;
		self[u].I = addon.ply_sp;
		self[u].ts = GetTime();
	end
end

function PWSTracker:Absorb(destGUID,amount)
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		if ( self[u] ) then
			self[u].current = math.max(self[u].current - amount,0);
			addon.StatParser:IncHealing(amount,true,true);
		end
	end
end

function PWSTracker:Remove(destGUID,amount)
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		if ( self[u] ) then
			if ( amount == 0 ) then
				local t = self[u];
				if ( t ) then
					local spellInfo = addon.Spells:Get(addon.DiscPriest.PowerWordShield);
					local originalHeal = t.original;
					local f = addon.StatParser:GetParserForCurrentSpec();
					local ME = t.masteryFlag and 1 or 0;
					
					if ( spellInfo and originalHeal and originalHeal>0 and f ) then
						addon.StatParser:Allocate("SPELL_ABSORBED",spellInfo,originalHeal,0,u,f,t.SP,t.C,t.CB,t.H,t.V,t.M,ME,0);
					end
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
	for guid,u in pairs(addon.UnitManager.units) do
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
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		if ( not self[u] ) then
			self.count = self.count + 1;
		end
		self[u] = GetTime();
	end
end

function AtonementTracker:Remove(destGUID)
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		if ( self[u] ) then
			self.count = math.max(0,self.count - 1);
		end
		self[u] = nil
	end
end

local function hasAtonement(unit)
	for i=1,40,1 do
		local _,p,id;
		
		if ( addon:isBFA() ) then
			  _,_,_,_,_,_,p,_,_,id = UnitAura(unit,i);
		else
			_,_,_,_,_,_,_,p,_,_,id = UnitAura(unit,i);
		end
		
		if ( not id ) then
			break;
		elseif (p == "player" and id == addon.DiscPriest.AtonementBuff ) then
			return true;
		end
	end
	
	return false;
end

function AtonementTracker:EncounterStart()
	for guid,u in pairs(addon.UnitManager.units) do
		if ( u and hasAtonement(u) ) then
			self:ApplyOrRefresh(guid);
		end
	end
end

function AtonementTracker:UnitHasAtonement(unit)
	if ( self[unit] ) then
		return true;
	else
		return false;
	end
end

function AtonementTracker:UnitHasAtonementFromPWS(unit)
	if ( unit ) then
		local pws_tbl = addon.DiscPriest.PWSTracker[unit];
		if ( pws_tbl ) then
			local t1 = self[unit];
			local t2 = pws_tbl.ts;
			return addon.BuffTracker:CompareTimestamps(t1,t2,0.3333);
		end
	end
	
	return false;
end
addon.DiscPriest.AtonementTracker = AtonementTracker;



addon.StatParser:Create(addon.SpellType.DPRIEST,nil,nil,nil,nil,_Mastery,nil,_HealEvent,_DamageEvent);