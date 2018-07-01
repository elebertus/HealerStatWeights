local name, addon = ...;



--[[----------------------------------------------------------------------------
	Segment Class - Stores stat allocations
------------------------------------------------------------------------------]]
local Segment = {};



--[[----------------------------------------------------------------------------
	Helper Functions
------------------------------------------------------------------------------]]
--Create and return an empty stat table
local function getStatTable() 
	local t = {};
	t.int = 0;
	t.crit = 0;
	t.haste_hpm = 0;
	t.haste_hpct = 0;
	t.vers = 0;
	t.vers_dr = 0;
	t.mast = 0;
	t.leech = 0;
	return t;
end

--shallow table copy
local function copy(t) 
	local new_t = {};
	local mt = getmetatable(t);
	for k,v in pairs(t) do new_t[k] = v; end
	setmetatable(new_t,mt);
	return new_t;
end



--[[----------------------------------------------------------------------------
	Segment.Create - Create a new Segment object with the given id/name
------------------------------------------------------------------------------]]
function Segment.Create(id) 
	local self = copy(Segment);
	self.t = getStatTable();
	self.id = id;
	self.nameSet = false;
	self.totalHealing = 0;
	self.fillerHealing = 0;
	self.fillerCasts = 0;
	self.fillerInt = 0;
	self.fillerManaSpent = 0; 
	self.totalDuration = 0;
	self.manaRestore = 0;
	self.startTime = GetTime();
	return self;
end



--[[----------------------------------------------------------------------------
	GetMP5 - MP5 estimation, normalized to int value
------------------------------------------------------------------------------]]
function Segment:GetMP5()
	if ( self.fillerManaSpent == 0 or self.fillerCasts == 0 ) then
		return 0;
	end
	
	local duration = self:GetDuration();
	if ( duration == 0 ) then
		return 0;
	end
	
	local int = self.fillerInt / self.fillerCasts;
	local fillerHPM = self.fillerHealing / (self.fillerManaSpent*addon.ManaPool);
	local HPS = self.totalHealing / duration;

	return int * (fillerHPM/5) / (HPS);
end



--[[----------------------------------------------------------------------------
	GetManaRestoreValue - Get the estimated value of the restored mana on this segment
------------------------------------------------------------------------------]]
function Segment:GetManaRestoreValue()
	local denom = self.fillerManaSpent*addon.ManaPool;
	
	if ( denom == 0 ) then
		return 0;
	end
	
	local fillerHPM = self.fillerHealing / denom;
	return fillerHPM * self.manaRestore;
end



--[[----------------------------------------------------------------------------
	AllocateHeal - increment cumulative healing totals for the given stats
------------------------------------------------------------------------------]]
function Segment:AllocateHeal(int,crit,haste_hpm,haste_hpct,vers,mast,leech)
	self.t.int		 	= self.t.int		 + int;
	self.t.crit			= self.t.crit	 	 + crit;
	self.t.haste_hpm	= self.t.haste_hpm	 + haste_hpm;
	self.t.haste_hpct	= self.t.haste_hpct  + haste_hpct;
	self.t.vers 	 	= self.t.vers		 + vers;
	self.t.vers_dr  	= self.t.vers_dr	 + vers;
	self.t.mast 	 	= self.t.mast		 + mast;
	self.t.leech 	 	= self.t.leech	 	 + leech;
end



--[[----------------------------------------------------------------------------
	GetDuration - get the length of this segment in seconds
------------------------------------------------------------------------------]]
function Segment:GetDuration()
	local d = self.totalDuration;
	if ( self.startTime >= 0 ) then
		d = d + (GetTime() - self.startTime);
	end
	return d;
end



--[[----------------------------------------------------------------------------
	End - the segment is no longer live, duration is fixed.
------------------------------------------------------------------------------]]
function Segment:End()
	self.totalDuration = self.totalDuration + (GetTime() - self.startTime);
	self.startTime = -1;
end


--[[----------------------------------------------------------------------------
	AllocateDamage - increment cumulative damage totals for the given stats
------------------------------------------------------------------------------]]
--[[
function Segment:AllocateDamage(int,crit,haste,vers,mast)
	self.t.int		 	= self.t.int		 + int;
	self.t.crit			= self.t.crit		 + crit;
	self.t.haste_hpct	= self.t.haste_hpct  + haste;
	self.t.vers 	 	= self.t.vers		 + vers;
	self.t.mast 	 	= self.t.mast		 + mast;
end
]]



--[[----------------------------------------------------------------------------
	AllocateHealDR - increment cumulative heal DR totals for the given stats
------------------------------------------------------------------------------]]
function Segment:AllocateHealDR(versatilityDR)
	self.t.vers_dr		= self.t.vers_dr	+ versatilityDR;
end



--[[----------------------------------------------------------------------------
	Debug - print internal values of this segment to chat
------------------------------------------------------------------------------]]
function Segment:Debug()
	for k,v in pairs(self.t) do
		if ( type(v) ~= "function" and type(v) ~= "table" ) then
			print(k,"=",v)
		end
	end

	for k,v in pairs(self) do
		if ( type(v) ~= "function" and type(v) ~= "table" ) then
			print(k,"=",v)
		end
	end
	local mp5 = self:GetMP5();
	local duration = self:GetDuration();
	print("mp5",mp5);
	print("duration",duration);
end

addon.Segment = Segment;