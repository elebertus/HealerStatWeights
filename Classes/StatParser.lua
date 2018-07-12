local name, addon = ...;



--[[----------------------------------------------------------------------------
	Stat conversion factors (data taken from simc)
	https://github.com/simulationcraft/simc/blob/bfa-dev/engine/dbc/generated/sc_scale_data.inc
------------------------------------------------------------------------------]]
local hst_cnv = {
																	16.64378375,	
    19.0820391,		21.87749023,	25.08246504,	28.7569573,		32.96974967,	
    37.79970119,	43.33722349,	49.6859732,		56.96479225,	68	 
};
	
local crt_cnv = {
																	17.62282985,  
    20.20451199,	23.16440142,	26.55790416,	30.44854303,	34.90914671,	
    40.02321302,	45.88647194,	52.60867751,	60.31566238,	72
};

local mst_cnv = {
																	17.62282985, 
    20.20451199,	23.16440142,	26.55790416,	30.44854303,	34.90914671,	
    40.02321302,	45.88647194,	52.60867751,	60.31566238,	72
};

local vrs_cnv = {
																	20.80472968, 
    23.85254888,	27.34686278,	31.35308129,	35.94619663,	41.21218708,
    47.24962648,	54.17152937,	62.1074665,		71.20599031,	85
};

local lee_cnv = {
																	9.790461028,
    11.22472888,	12.8691119,		14.7543912,		16.91585724,	19.39397039,
    22.23511835,	25.49248441,	29.22704306,	33.50870132,	40
};

local mna_cnv = {
									4000,
    6351,	7270,	8253,	9307,	10437,	
    11650,	12949,	14341,	15774,	20000
};

function addon:SetupConversionFactors()
	addon.IntConv		= 1.05; --int to SP conversion factor
	
	local mastery_factor = 1;
	
	if ( self:IsRestoDruid() ) then
		mastery_factor = 5/3;
	elseif ( self:IsRestoShaman() ) then
		mastery_factor = 1/3;
	elseif ( self:IsHolyPriest() ) then
		mastery_factor = 4/5;
	elseif ( self:IsHolyPaladin() ) then
		mastery_factor = 2/3;
	elseif ( self:IsMistweaverMonk() ) then
		mastery_factor = 1/3;
	end
	
	if ( addon:isBFA() ) then
		local level = UnitLevel("Player");
		
		addon.CritConv 		= crt_cnv[level-110+1]*100;
		addon.HasteConv 	= hst_cnv[level-110+1]*100;
		addon.VersConv 		= vrs_cnv[level-110+1]*100;
		addon.MasteryConv 	= mst_cnv[level-110+1]*100 * mastery_factor;
		addon.LeechConv		= lee_cnv[level-110+1]*100;
		addon.ManaPool 		= mna_cnv[level-110+1]*5;
	else
		addon.CritConv 		= 40000;
		addon.HasteConv 	= 37500;
		addon.VersConv 		= 47500;
		addon.MasteryConv	= 40000 * mastery_factor;
		addon.LeechConv 	= 23000;
		addon.ManaPool		= 220000*5;
	end
end



--[[----------------------------------------------------------------------------
	UpdatePlayerStats - Update stats for current player.
------------------------------------------------------------------------------]]
function addon:UpdatePlayerStats()
	self.ply_sp  = GetSpellBonusDamage(4);
    self.ply_crt = GetCritChance() / 100;
	self.ply_hst = UnitSpellHaste("Player") / 100;
	self.ply_vrs = (GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)) / 100;
	self.ply_mst = GetMasteryEffect() / 100;
	self.ply_lee = GetLifesteal() / 100;
    
	local race = UnitRace("Player");
	self.ply_crtbonus = 1;
	if ( race == "Tauren") then
		self.ply_crtbonus = self.ply_crtbonus * 1.04; --yes 1.04, not 1.02
    end
	if ( IsEquippedItem("Drape of Shame") ) then 
		self.ply_crtbonus = self.ply_crtbonus * 1.05;
    end
end



--[[----------------------------------------------------------------------------
Basic Stat Derivative Calculations
------------------------------------------------------------------------------]]
--Int
local function _Intellect(ev,s,heal,destUnit,SP,f)
	if ( f and f.Intellect ) then
		return f.Intellect(ev,s,heal,destUnit,SP);
	end
	
	if ( s.int ) then
		return (heal / SP) * addon.IntConv;
	end
	
	return 0;
end

--Crit
--CB is a bonus to critical strike healing (Drape of Shame, Tauren Racial, etc)
local function _CriticalStrike(ev,s,heal,destUnit,C,CB,f)
	if ( f and f.CriticalStrike ) then
		return f.CriticalStrike(ev,s,heal,destUnit,C,CB);
	end
	
	C = math.min(C,1.00); --clamp crit chance at 100%
	
	if ( s.crt ) then
		return heal*CB / (1+C*CB) / addon.CritConv;
	end
	
	return 0;
end

--Haste (returns hpm and hpct values)
local function _Haste(ev,s,heal,destUnit,H,f)
	if ( f and f.Haste ) then
		return f.Haste(ev,s,heal,destUnit,H);
	end
	
	local canHPM = s.hstHPM or (s.hstHPMPeriodic and ev == "SPELL_PERIODIC_HEAL");
	local canHPCT2 = canHPM and s.hstHPCT;
	local canHPCT1 = canHPM or s.hstHPCT;
	
	local hpm = 0;
	local hpct = 0;
	
	if ( canHPM ) then
		hpm = heal / (1+H) / addon.HasteConv;
	end
	
	if (canHPCT2) then
		hpct = 2*heal / (1+H) / addon.HasteConv;
	elseif (canHPCT1) then
		hpct = heal / (1+H) / addon.HasteConv;
	end
	
	return hpm,hpct;
end

--Vers
local function _Versatility(ev,s,heal,destUnit,V,f)
	if ( f and f.Versatility ) then
		return f.Versatility(ev,s,heal,destUnit,V);
	end
	
	if ( s.vrs ) then
		return heal / (1+V) / addon.VersConv;
	end
	
	return 0;
end

--Mastery
local function _Mastery(ev,s,heal,destUnit,M,ME,f)
	if ( f and f.Mastery ) then
		return f.Mastery(ev,s,heal,destUnit,M,ME)
	end
	
	if ( s.mst ) then
		return heal / ( 1+M ) / addon.MasteryConv; 
	end
	
	return 0;
end

--Leech
local function _Leech(ev,s,heal,destUnit,L,f)
	if ( f and f.Leech ) then
		return f.Leech(ev,s,heal,destUnit,L);
	end
	
	if s.lee and (UnitHealth("Player")+(heal*L)) < UnitHealthMax("Player") then
		return heal / (1+L) / addon.LeechConv;
	end
	
	return 0;
end

local BaseParsers = {
	Intellect = _Intellect,
	CriticalStrike = _CriticalStrike,
	Haste = _Haste,
	Versatility = _Versatility,
	Mastery = _Mastery,
	Leech = _Leech
}



--[[----------------------------------------------------------------------------
	StatParser - Create & Get combat log parsers for each spec
------------------------------------------------------------------------------]]
local StatParser = {};



--[[----------------------------------------------------------------------------
	Create - add a new stat parser to be used by the addon.
------------------------------------------------------------------------------]]
function StatParser:Create(id,func_I,func_C,func_H,func_V,func_M,func_L,func_HealEvent,func_DamageEvent)
	self[id] = {};
	if ( func_HealEvent ) then self[id].HealEvent = func_HealEvent; end
	if ( func_DamageEvent ) then self[id].DamageEvent = func_DamageEvent; end
	if ( func_I ) then self[id].Intellect = func_I; end
	if ( func_C ) then self[id].CriticalStrike = func_C; end
	if ( func_H ) then self[id].Haste = func_H; end
	if ( func_V ) then self[id].Versatility = func_V; end
	if ( func_M ) then self[id].Mastery = func_M; end
	if ( func_L ) then self[id].Leech = func_L; end
end


--[[----------------------------------------------------------------------------
	GetParserForCurrentSpec
------------------------------------------------------------------------------]]
function StatParser:GetParserForCurrentSpec()
    local i = GetSpecialization();
	local specId = GetSpecializationInfo(i);
	return self[specId and tonumber(specId) or 0],specId;
end

function StatParser:IncFillerHealing(heal)
	local cur_seg = addon.SegmentManager:Get(0);
	local ttl_seg = addon.SegmentManager:Get("Total");
	if ( cur_seg ) then
		cur_seg:IncFillerHealing(heal);
	end
	if ( ttl_seg ) then
		ttl_seg:IncFillerHealing(heal);
	end
end

function StatParser:Allocate(ev,spellInfo,heal,overhealing,destUnit,f,SP,C,CB,H,V,M,ME,L)
	local cur_seg = addon.SegmentManager:Get(0);
	local ttl_seg = addon.SegmentManager:Get("Total");
	local OH = overhealing>0
	local _I,_C,_Hhpm,_Hhpct,_M,_V,_L = 0,0,0,0,0,0,0;
		
	if (not OH) then --allocate effective healing
		_I 	 			= _Intellect(ev,spellInfo,heal,destUnit,SP,f);
		_C				= _CriticalStrike(ev,spellInfo,heal,destUnit,C,CB,f) ;
		_Hhpm,_Hhpct	= _Haste(ev,spellInfo,heal,destUnit,H,f);
		_M	 			= _Mastery(ev,spellInfo,heal,destUnit,M,ME,f);
		_V	 			= _Versatility(ev,spellInfo,heal,destUnit,V,f);
		_L	 			= _Leech(ev,spellInfo,heal,destUnit,L,f);
	elseif ( addon.BuffTracker:Get(addon.VelensId) == 1 ) then --allow all normal healing, and 50% of overhealing to be counted
		heal = heal+overhealing*0.5;
		_I 	 			= _Intellect(ev,spellInfo,heal,destUnit,SP,f);
		_C				= _CriticalStrike(ev,spellInfo,heal,destUnit,C,CB,f);
		_Hhpm,_Hhpct	= _Haste(ev,spellInfo,heal,destUnit,H,f);
		_M	 			= _Mastery(ev,spellInfo,heal,destUnit,M,ME,f);
		_V	 			= _Versatility(ev,spellInfo,heal,destUnit,V,f);
		_L	 			= _Leech(ev,spellInfo,heal,destUnit,L,f);
	else --overhealing with no velens buff, so only possible to attribute leech
		_L	 			= _Leech(ev,spellInfo,heal,destUnit,L,f);
	end
						
	--Add derivatives to current & total segments
	if ( cur_seg ) then
		cur_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
	end
	if ( ttl_seg ) then
		ttl_seg:AllocateHeal(_I,_C,_Hhpm,_Hhpct,_V,_M,_L);
	end
	
	--update display to user
	addon:UpdateDisplayStats();
end


function StatParser:AllocateDamageLeech(ev,spellInfo,amount,L)
	local _L = _Leech(ev,spellInfo,amount,nil,L,nil);
	local cur_seg = addon.SegmentManager:Get(0);
	local ttl_seg = addon.SegmentManager:Get("Total");
	
	--Track healing amount of filler spells vs overall healing. (For mp5 calculations)
	if ( cur_seg ) then
		cur_seg:AllocateHeal(0,0,0,0,0,0,_L);
	end
	if ( ttl_seg ) then
		cur_seg:AllocateHeal(0,0,0,0,0,0,_L);
	end
	
end

--[[----------------------------------------------------------------------------
	DecompHealingForCurrentSpec
------------------------------------------------------------------------------]]
function StatParser:DecompHealingForCurrentSpec(ev,destGUID,spellID,critFlag,heal,overhealing)
	local f,specId = self:GetParserForCurrentSpec();
	
	--check if parser exist for current spec
	if ( f ) then 
		--check if spellInfo is valid for current spec.
		local spellInfo = addon.Spells:Get(spellID);
		if ( spellInfo and (spellInfo.spellType == specId or spellInfo.spellType == addon.SpellType.SHARED) ) then
			--make sure destGUID describes a valid unit (Exclude healing to pets/npcs)
			local destUnit = addon.UnitManager:Find(destGUID);
			if destUnit then 
				local exclude_cds = addon.hsw.db.global.excludeRaidHealingCooldowns	--filter out raid cooldowns if we are excluding them
				if ( not exclude_cds or (exclude_cds and not spellInfo.cd) ) then
					local OH = overhealing and overhealing>0;
					local cur_seg = addon.SegmentManager:Get(0);
					local ttl_seg = addon.SegmentManager:Get("Total");
					
					--Track healing amount of filler spells vs overall healing. (For mp5 calculations)
					if ( cur_seg ) then
						cur_seg:IncTotalHealing(heal)
						if ( spellInfo.filler ) then
							cur_seg:IncFillerHealing(heal);
						end
					end
					if ( ttl_seg ) then
						ttl_seg:IncTotalHealing(heal)
						if ( spellInfo.filler ) then
							ttl_seg:IncFillerHealing(heal);
						end
					end
					
					--Reduce crit heals down to the non-crit amount
					if ( critFlag ) then
						heal = heal / ( 1 + addon.ply_crtbonus );
						overhealing = OH and overhealing / ( 1 + addon.ply_crtbonus ) or 0;
					end

					--Allow the class parser to do pre-computations on this heal event
					local skipAllocate=false;
					if ( f.HealEvent ) then
						skipAllocate = f.HealEvent(ev,spellInfo,heal,overhealing,destUnit,f);
					end
										
					--Allocate healing derivatives for each stat
					if ( not skipAllocate ) then
						self:Allocate(ev,spellInfo,heal,overhealing,destUnit,f,addon.ply_sp,addon.ply_crt,addon.ply_crtbonus,addon.ply_hst,addon.ply_vrs,addon.ply_mst,nil,addon.ply_lee);
					end
				end
			end
		elseif ( not spellInfo ) then
			addon:DiscoverIgnoredSpell(spellID);
		end
	end
end



--[[----------------------------------------------------------------------------
	DecompDamageDone
------------------------------------------------------------------------------]]
function StatParser:DecompDamageDone(amt)
	local f = self[specId and tonumber(specId) or 0];
	
	--check if parser exist for current spec
	if ( f and f.DamageEvent ) then 
		--check if spellInfo is valid for current spec.
		local spellInfo = addon.Spells:Get(spellID);
		if ( spellInfo and (spellInfo.spellType == specId or spellInfo.spellType == addon.SpellType.SHARED) ) then
			f.DamageEvent(spellInfo,amt);
			
			self:AllocateDamageLeech("SPELL_DAMAGE",spellInfo,amt,addon.ply_lee);
		end
	end
end



--[[----------------------------------------------------------------------------
	DecompDamageTaken
------------------------------------------------------------------------------]]
function StatParser:DecompDamageTaken(amt)
	amt = amt or 0;
	amt = math.min(UnitHealthMax("Player"),amt);
	amt = amt / (addon.VersConv*2);
	
	--Add derivatives to current & total segments
	local cur_seg = addon.SegmentManager:Get(0);
	local ttl_seg = addon.SegmentManager:Get("Total");
	if ( cur_seg ) then
		cur_seg:AllocateHealDR(amt);
	end
	if ( ttl_seg ) then
		ttl_seg:AllocateHealDR(amt);
	end
end



--[[----------------------------------------------------------------------------
	IsCurrentSpecSupported - Check if current spec is supported 
------------------------------------------------------------------------------]]
function StatParser:IsCurrentSpecSupported()
	local f = self:GetParserForCurrentSpec();
	
	if ( f ) then
		return true;
	else
		return false;
	end
end


addon.BaseParsers = BaseParsers;
addon.StatParser = StatParser;