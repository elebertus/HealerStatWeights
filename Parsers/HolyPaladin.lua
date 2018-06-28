local name, addon = ...;



function addon:IsHolyPaladin()
    local i = GetSpecialization();
	local specId = i and GetSpecializationInfo(i);
	return specId and (tonumber(specId) == addon.SpellType.PALADIN);
end

--[[----------------------------------------------------------------------------
	Buff Tracking
------------------------------------------------------------------------------]]
local vindicator = 200376;
local avengingWrath = 31842;
local ruleOfLaw = 214202;
local holyShock = 20473;

addon.BuffTracker:Track(ruleOfLaw,nil,nil);  --ruleOfLaw
addon.BuffTracker:Track(vindicator,nil,nil);  --vindicator (+25% CE)
addon.BuffTracker:Track(avengingWrath,nil,nil);  --avenging wrath (+20% crit)



--[[----------------------------------------------------------------------------
	Beacon Tracking
------------------------------------------------------------------------------]]
addon.BeaconBuffs = {
	[156910]=true,
	[200025]=true,
	[53563]=true
};
addon.BeaconUnits = {};
addon.BeaconCount = 0;

local function hasBeacon(unit)
	for i=1,40,1 do
		local _,id;

		if ( addon:isBFA() ) then
			_,_,_,_,_,_,p,_,_,id = UnitAura(unit,i);
		else
			_,_,_,_,_,_,_,p,_,_,id = UnitAura(unit,i);
		end
		
		if ( not id ) then
			break;
		elseif (p == "player" and addon.BeaconBuffs[id]) then
			return true;
		end
	end
	
	return false;
end

function addon:CountBeaconsAtStartOfFight()
	addon.BeaconUnits = {};
	addon.BeaconCount = 0;
	
	for guid,u in pairs(self.UnitManager.units) do
		if ( u and hasBeacon(u) ) then
			addon.BeaconUnits[guid]=true;
			addon.BeaconCount = addon.BeaconCount + 1;
		end
	end
end



--[[----------------------------------------------------------------------------
	Holy Paladin Critical Strike
		- Crit chance modified by avenging wrath
		- Crit effect modified by vindicator
		- Crit chance doubled for holy shock
------------------------------------------------------------------------------]]
local function _CriticalStrike(ev,spellInfo,heal,destUnit,C,CB)		
	if ( addon.BuffTracker:Get(vindicator) > 0 ) then
		CB = CB * 1.25;
	end
	
	if ( addon.BuffTracker:Get(avengingWrath) > 0 ) then
		C = C + 0.20;
	end
	
	if ( spellInfo.spellID == holyShock) then --holy shock
		C = C * 2;
	end

	return addon.BaseParsers.CriticalStrike(ev,spellInfo,heal,destUnit,C,CB,nil);
end



--[[----------------------------------------------------------------------------
	getMasteryEffect - Holy paladin mastery scales based on distance to target unit
------------------------------------------------------------------------------]]
local function getMasteryEffect(destUnit)
	local distance = 60.0;
	
	if ( destUnit ) then
		if ( IsItemInRange(32321,destUnit) ) then
			distance = 10.0;
		elseif ( IsItemInRange(1251,destUnit) ) then
			distance = 12.5;
		elseif ( IsItemInRange(21519,destUnit) ) then
			distance = 17.5;
		elseif ( IsItemInRange(31463,destUnit) ) then
			distance = 22.5;
		elseif ( IsItemInRange(1180,destUnit) ) then
			distance = 27.5;
		elseif ( IsItemInRange(18904,destUnit) ) then
			distance = 32.5;
		elseif ( IsItemInRange(34471,destUnit) ) then
			distance = 37.5;
		elseif ( IsItemInRange(32698,destUnit) ) then
			distance = 42.5;
		elseif ( IsItemInRange(116139,destUnit) ) then
			distance = 47.5;
		elseif ( IsItemInRange(32825,destUnit) ) then
			distance = 55.0;
		else
			distance = 60.0;
		end
	end
	
	local lwr = 10;
	local upr = 40;
	
	if ( addon.BuffTracker:Get(ruleOfLaw) > 0 ) then
		lwr = lwr * 1.5;
		upr = upr * 1.5;
	end
	
	local ME;
	if ( distance >= upr ) then
		ME = 0;
	elseif ( distance <= lwr ) then
		ME = 1;
	else
		ME = (upr-distance)/(upr-lwr);
	end
	return ME;
end



--[[----------------------------------------------------------------------------
	Holy Paladin Mastery
		- Mastery effect is based on distance with target
		- use weighted average of feeder spells for cloudburst
------------------------------------------------------------------------------]]
local function _Mastery(ev,spellInfo,heal,destUnit,M,ME)
	if ( spellInfo.mst ) then
		if ( not ME ) then
			ME = getMasteryEffect(destUnit);
		end
		return ME*heal / (1+ME*M) / addon.MasteryConv;
	end
	
	return 0;
end



--[[----------------------------------------------------------------------------
	healEvent 
	- Track healing that feeds beacons
------------------------------------------------------------------------------]]
local Queue = {};
function Queue.Create()
	local t = {};
	t.front = 0;
	t.back = 0;
	t.Enqueue = function(self,event)
		self.front = self.front+1;
		self[self.front] = event;
	end;
	t.Dequeue = function(self)
		if ( self:Size() > 0 ) then
			self.back = self.back + 1;
			local event = self[self.back];
			--self[self.back] = nil;
			return event;
		end
	end;
	t.MatchHeal = function(self)
		local event = true;
		while ( self:Size() > 0 and event) do 
			event = self:Dequeue();
			if ( event ) then
				if ( math.abs(event.ts - GetTime()) <= 0.3333 ) then -- within 1/3 of a second
					return event;
				end
			end
		end
		return nil;
	end
	t.Size = function(self)
		return self.front - self.back;
	end
	return t;
end

local beaconHeals = Queue.Create();

--shallow table copy
local function copy(t) 
	local new_t = {};
	local mt = getmetatable(t);
	for k,v in pairs(t) do new_t[k] = v; end
	setmetatable(new_t,mt);
	return new_t;
end

local function _HealEvent(ev,spellInfo,heal,overhealing,destUnit,f)
	if ( spellInfo.transfersToBeacon ) then
		local numBeacons = addon.BeaconCount;
		if ( addon.BeaconUnits[UnitGUID(destUnit)] ) then
			numBeacons = math.max(numBeacons - 1,0);
		end
		
		local event = {
			ts = GetTime(),
			ME = getMasteryEffect(destUnit),
			C = addon.ply_crt,
			SP = addon.ply_sp,
			H = addon.ply_hst,
			M = addon.ply_mst,
			V = addon.ply_vrs,
			L = addon.ply_lee
		};
		
		for i=1,numBeacons,1 do
			beaconHeals:Enqueue(copy(event));
		end
	elseif (spellInfo.spellID == addon.BeaconOfLight) then
		local event = beaconHeals:MatchHeal();
		
		if ( event ) then
			if ( overhealing == 0 ) then
				local _I,_C,_Hhpm,_Hhpct,_M,_V,_L = 0,0,0,0,0,0,0;
				local cur_seg = addon.SegmentManager:Get(0);
				local ttl_seg = addon.SegmentManager:Get("Total");
				
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




addon.StatParser:Create(addon.SpellType.PALADIN,nil,_CriticalStrike,nil,nil,_Mastery,nil,_HealEvent);