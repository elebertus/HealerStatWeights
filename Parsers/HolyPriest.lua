local name, addon = ...;



function addon:IsHolyPriest()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.HPRIEST);
end

--[[----------------------------------------------------------------------------
	Echo of Light Tracker
		Tracks a weighted average of stat percentages contributing to an echo
		of light tick.
------------------------------------------------------------------------------]]
local EOLTracker = {};
local ticks_on_initial_application = 2;
local ticks_on_refresh = 3;

local function weighted_avg(stat1,w1,stat2,w2)
	return (stat1*w1+stat2*w2)/(w1+w2);
end

local function hasEcho(unit) --return amount per tick of EoL or nil
	for i=1,40,1 do
		local _,p,id,amt;
		
		if ( addon:isBFA() ) then
			  _,_,_,_,_,_,p,_,_,id,_,_,_,_,_,amt = UnitAura(unit,i);
		else
			_,_,_,_,_,_,_,p,_,_,id,_,_,_,_,_,amt = UnitAura(unit,i);
		end
		
		if ( not id ) then
			break;
		elseif (p == "player" and id == addon.HolyPriest.EchoOfLight ) then
			return amt;
		end
	end
	
	return false;
end

function EOLTracker:Apply(destGUID)
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		local amount = hasEcho(u) or 0;
		self[u] = {
			current = amount*ticks_on_initial_application,
			SP = addon.ply_sp,
			C = addon.ply_crt,
			CB = addon.ply_crtbonus,
			H = addon.ply_hst,
			M = addon.ply_mst,
			V = addon.ply_vrs
		};
	end
end

function EOLTracker:Refresh(destGUID)
	local u = addon.UnitManager:Find(destGUID);
	if ( u ) then
		local amount = hasEcho(u) or 0;
		if not self[u] then
			self[u] = {
				current = amount*ticks_on_refresh,
				SP = addon.ply_sp,
				C = addon.ply_crt,
				CB = addon.ply_crtbonus,
				H = addon.ply_hst,
				M = addon.ply_mst,
				V = addon.ply_vrs
			};
		else
			local after = math.max(0,ticks_on_refresh*amount-self[u].current);
			local before = ticks_on_refresh*amount-after;
		
			self[u].current = ticks_on_refresh*amount;
			self[u].SP = weighted_avg(self[u].SP,before,addon.ply_sp,after);
			self[u].C = weighted_avg(self[u].C,before,addon.ply_crt,after);
			self[u].CB = weighted_avg(self[u].CB,before,addon.ply_crtbonus,after);
			self[u].H = weighted_avg(self[u].H,before,addon.ply_hst,after);
			self[u].M = weighted_avg(self[u].M,before,addon.ply_mst,after);
			self[u].V = weighted_avg(self[u].V,before,addon.ply_vrs,after);	
		end
	end
end

function EOLTracker:Remove(destGUID)
	local u = addon.UnitManager:Find(destGUID);
	if ( u and self[u] ) then
		self[u] = nil;
	end
end

function EOLTracker:HealedUnit(u,amount)
	if ( u and self[u] ) then
		self[u].current = math.max(0,self[u].current-amount);
	end
end

function EOLTracker:Get(u)
	if ( u ) then
		return self[u];
	end
	return nil;
end

function EOLTracker:EncounterStart()
	for guid,u in pairs(addon.UnitManager.units) do
		if ( u ) then
			local amount = hasEcho(u);
			if ( amount and amount > 0 ) then
				self:Apply(guid,amount);
			end
		end
	end
end



--[[----------------------------------------------------------------------------
	Holy Priest Heal Event
		- Use echo of light tracker to correctly allocate echo of light stat contributions
------------------------------------------------------------------------------]]
local function _HealEvent(ev,spellInfo,heal,overhealing,destUnit,f)
	if ( spellInfo.spellID == addon.HolyPriest.EchoOfLight ) then
		addon.HolyPriest.EOLTracker:HealedUnit(destUnit,heal+overhealing);
		local t = addon.HolyPriest.EOLTracker:Get(destUnit);
		if ( t ) then
			addon.StatParser:Allocate(ev,spellInfo,heal,overhealing,destUnit,f,t.SP,t.C,t.CB,t.H,t.V,t.M,nil,0);
			return true; --skip default allocation
		end 
	end
	return false;
end




--[[----------------------------------------------------------------------------
	Holy Priest Mastery
		- calculated from echo of light healing
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M)
	if ( spellInfo.spellID == addon.HolyPriest.EchoOfLight ) then --echo of light healing
		if ( M == 0 ) then
			return 0;
		end
		return heal / M / addon.MasteryConv; --divide by M instead of (1+M)
	end
	return 0;
end



addon.HolyPriest.EOLTracker = EOLTracker;
addon.StatParser:Create(addon.SpellType.HPRIEST,nil,nil,nil,nil,_Mastery,nil,_HealEvent,nil);