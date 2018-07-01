local name, addon = ...;
local T = true;
local F = false;
local _ = false;



--[[----------------------------------------------------------------------------
	SpellType - Enumeration of specialization ids for each healing spec; 
				and a "Shared" type for spells used by all healing specializations (Trinkets, etc.)
------------------------------------------------------------------------------]]
local SpellType = {
	DRUID = 105,
	SHAMAN = 264,
	HPRIEST = 257,
	PALADIN = 65, 
	MONK = 270,
	-- Disc 256
	SHARED = 1,
	IGNORED = -1
}


			

--[[----------------------------------------------------------------------------
	Spells - stored spell data. Used by the parsers/decomp methods.
------------------------------------------------------------------------------]]
local Spells = {};



--[[----------------------------------------------------------------------------
	createSpellInfo - helper function for setting up spell information
------------------------------------------------------------------------------]]
local function createSpellInfo(id, spellType, isIntScaled, isCritScaled, isHasteHPMScaled, isHasteHPCTScaled, isVersScaled, isMasteryScaled, isLeechScaled)
	Spells[id] = {
		spellID = id,
		spellType = spellType,
		int = isIntScaled,
		crt = isCritScaled,
		hstHPM = isHasteHPMScaled,
		hstHPCT = isHasteHPCTScaled,
		vrs = isVersScaled,
		mst = isMasteryScaled,
		lee = isLeechScaled,
		cd = false,
		filler = false,
		manaCost = -1,
		hstHPMPeriodic = false
	}
end

local function setRaidCooldown(id)
	Spells[id].cd = true;
end

local function setHasteHpmOnlyOnPeriodic(id)
	Spells[id].hstHPMPeriodic=true;
end

local function setFillerSpell(id,manaCost)
	Spells[id].filler = true;
	Spells[id].manaCost = manaCost;
end

--[[----------------------------------------------------------------------------
	DiscoverIgnoredSpell - when we encounter an unknown healing event, print a message
------------------------------------------------------------------------------]]
function addon:DiscoverIgnoredSpell(spellID)
	createSpellInfo(spellID,SpellType.IGNORED);
	if ( self:isBFA() ) then
		print("[HealerStatWeights]: Discovered SpellID \"" .. spellID .. "\" not in database. Tell the author!" );
	end
end



--[[----------------------------------------------------------------------------
	Get - Get current spell info
------------------------------------------------------------------------------]]
function Spells:Get(id)
	return self[id and tonumber(id)];
end 



--[[----------------------------------------------------------------------------
	Resto Druid
------------------------------------------------------------------------------]]
addon.Druid = {};
addon.Druid.TranquilityHeal = 740;
addon.Druid.TranquilityHoT = 157982;
addon.Druid.Rejuvenation = 774;
addon.Druid.Germination = 155777;
addon.Druid.LifebloomHoT = 33763;
addon.Druid.LifebloomHeal = 33778;
addon.Druid.Regrowth = 8936;
addon.Druid.WildGrowth = 48438;
addon.Druid.Dreamwalker = 189853;
addon.Druid.NaturesEssence = 189800;
addon.Druid.Effloresence = 145205;
addon.Druid.Swiftmend = 18562;
addon.Druid.HealingTouch = 5185;
addon.Druid.LivingSeed = 48500;
addon.Druid.FrenziedRegen = 22842;
addon.Druid.SpringBlossoms = 207386;
addon.Druid.Cultivation = 200389;
addon.Druid.CenarionWard = 102352;
addon.Druid.Renewal = 108238;
addon.Druid.DreamerHoT = 253432; -- t21
addon.Druid.AbundanceBuff = 207383;

--																I C H H V M L
createSpellInfo(addon.Druid.TranquilityHeal,SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.TranquilityHoT,	SpellType.DRUID,	T,T,T,T,T,T,T);
createSpellInfo(addon.Druid.Rejuvenation,	SpellType.DRUID,	T,T,T,T,T,T,T);
createSpellInfo(addon.Druid.Germination,	SpellType.DRUID,	T,T,T,T,T,T,T);
createSpellInfo(addon.Druid.LifebloomHoT,	SpellType.DRUID,	T,T,T,T,T,T,T);
createSpellInfo(addon.Druid.LifebloomHeal,	SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.Regrowth,		SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.WildGrowth,		SpellType.DRUID,	T,T,T,T,T,T,T);
createSpellInfo(addon.Druid.Dreamwalker,	SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.NaturesEssence,	SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.Effloresence,	SpellType.DRUID,	T,T,T,T,T,T,T);
createSpellInfo(addon.Druid.Swiftmend,		SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.HealingTouch,	SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.LivingSeed,		SpellType.DRUID,	T,T,_,T,T,T,T);
createSpellInfo(addon.Druid.FrenziedRegen,	SpellType.DRUID,	_,_,_,T,_,T,_);

createSpellInfo(addon.Druid.SpringBlossoms,	SpellType.DRUID,	T,T,T,_,T,T,T);
createSpellInfo(addon.Druid.Cultivation,	SpellType.DRUID,	T,T,T,_,T,T,T);
createSpellInfo(addon.Druid.CenarionWard,	SpellType.DRUID,	T,T,T,T,T,T,T);
createSpellInfo(addon.Druid.Renewal,		SpellType.DRUID,	_,_,_,T,_,_,_);
createSpellInfo(addon.Druid.DreamerHoT,		SpellType.DRUID,	T,T,T,_,T,T,T);

addon.BuffTracker:Track(addon.Druid.AbundanceBuff)

setRaidCooldown(addon.Druid.TranquilityHeal);
setRaidCooldown(addon.Druid.TranquilityHoT);

setHasteHpmOnlyOnPeriodic(addon.Druid.Regrowth);

setFillerSpell(addon.Druid.Rejuvenation, 0.22);
setFillerSpell(addon.Druid.Germination,  0.22);




--[[----------------------------------------------------------------------------
	Resto Shaman
------------------------------------------------------------------------------]]
addon.Shaman = {};
addon.Shaman.HealingWave = 77472;
addon.Shaman.Downpour = 252159;
addon.Shaman.GiftOfTheQueen = 207778;
addon.Shaman.GiftOfTheQueen2 = 255227;
addon.Shaman.Riptide = 61295;
addon.Shaman.Rainfall = 252154; --t21
addon.Shaman.ChainHeal = 1064;
addon.Shaman.HealingTide = 114942;
addon.Shaman.HealingSurge = 8004;
addon.Shaman.HealingStream = 52042;
addon.Shaman.HealingRain = 73921;
addon.Shaman.CloudburstHeal = 157503;
addon.Shaman.Undulation = 200071;
addon.Shaman.UnleashLife = 73685;
addon.Shaman.WellSpring = 197997;
addon.Shaman.SpiritLink = 98021;
addon.Shaman.Ascendance = 114083;
-- Nature's Guardian
-- Earth Shield

addon.Shaman.CloudburstBuff = 157504;
addon.Shaman.TidalWavesBuff = 53390;
addon.Shaman.AscendanceBuff = 114052;
addon.Shaman.Resurgence = 101033;

addon.BuffTracker:Track(addon.Shaman.TidalWavesBuff);



--																	I C H H V M L
createSpellInfo(addon.Shaman.HealingWave,		SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.Downpour,			SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.GiftOfTheQueen,	SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.GiftOfTheQueen2,	SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.Riptide,			SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.Rainfall,			SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.ChainHeal, 		SpellType.SHAMAN,	T,T,_,T,T,T,T);	
createSpellInfo(addon.Shaman.HealingTide, 		SpellType.SHAMAN,	T,T,T,T,T,T,T);
createSpellInfo(addon.Shaman.HealingSurge,  	SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.HealingStream, 	SpellType.SHAMAN,	T,T,T,T,T,T,T);
createSpellInfo(addon.Shaman.HealingRain, 		SpellType.SHAMAN,	T,T,T,T,T,T,T);
createSpellInfo(addon.Shaman.CloudburstHeal, 	SpellType.SHAMAN,	T,T,_,T,T,T,_); --handled via special case

createSpellInfo(addon.Shaman.Undulation,	 	SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.UnleashLife,		SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.WellSpring,		SpellType.SHAMAN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Shaman.SpiritLink,		SpellType.IGNORED);	
createSpellInfo(addon.Shaman.Ascendance,		SpellType.SHAMAN,	T,T,_,T,T,T,_);

setRaidCooldown(addon.Shaman.HealingTide);

setHasteHpmOnlyOnPeriodic(addon.Shaman.Riptide);

setFillerSpell(addon.Shaman.HealingWave,0.018);
setFillerSpell(addon.Shaman.HealingSurge,0.04);
setFillerSpell(addon.Shaman.ChainHeal,0.05);



--[[----------------------------------------------------------------------------
	Holy Priest
------------------------------------------------------------------------------]]
addon.HolyPriest = {};
addon.HolyPriest.Renew = 139;
addon.HolyPriest.Serenity = 2050;
addon.HolyPriest.PrayerOfHealing = 596;
addon.HolyPriest.Heal = 2060;
addon.HolyPriest.FlashHeal = 2061;
addon.HolyPriest.BindingHeal = 32546;
addon.HolyPriest.DesperatePrayer = 19236;
addon.HolyPriest.CosmicRipple = 243241;
addon.HolyPriest.DivineHymn = 64844;
addon.HolyPriest.Sanctify = 34861;
addon.HolyPriest.LightOfTuure = 208065;
addon.HolyPriest.PrayerOfMending = 33110;
addon.HolyPriest.Halo = 120692;
addon.HolyPriest.CircleOfHealing = 204883;
addon.HolyPriest.TrailOfLight = 234946;
addon.HolyPriest.DivineStar = 110745;
addon.HolyPriest.BodyAndMind = 214121;
addon.HolyPriest.EchoOfLight = 77489;
addon.HolyPriest.Salvation = 265202
--																		I C H H V M L
createSpellInfo(addon.HolyPriest.Renew,				SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.Serenity,			SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.PrayerOfHealing,	SpellType.HPRIEST,	T,T,_,T,T,_,T);
createSpellInfo(addon.HolyPriest.Heal,				SpellType.HPRIEST,	T,T,_,T,T,_,T);
createSpellInfo(addon.HolyPriest.FlashHeal,			SpellType.HPRIEST,	T,T,_,T,T,_,T);
createSpellInfo(addon.HolyPriest.BindingHeal,		SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.DesperatePrayer,	SpellType.HPRIEST,	F,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.CosmicRipple,		SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.DivineHymn,		SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.Salvation,			SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.Sanctify,			SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.LightOfTuure,		SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.PrayerOfMending,	SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.Halo,				SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.CircleOfHealing,	SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.TrailOfLight,		SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.DivineStar,		SpellType.HPRIEST,	T,T,_,T,T,_,T);		
createSpellInfo(addon.HolyPriest.BodyAndMind,		SpellType.HPRIEST,	T,T,T,T,T,_,T);		
createSpellInfo(addon.HolyPriest.EchoOfLight,		SpellType.HPRIEST,	T,T,_,T,T,T,T);	

setRaidCooldown(addon.HolyPriest.DivineHymn);
setRaidCooldown(addon.HolyPriest.Salvation);

setHasteHpmOnlyOnPeriodic(addon.HolyPriest.Renew);

setFillerSpell(addon.HolyPriest.Heal, 0.017);
setFillerSpell(addon.HolyPriest.FlashHeal, 0.028);
setFillerSpell(addon.HolyPriest.PrayerOfHealing,0.045);



--[[----------------------------------------------------------------------------
	Holy Paladin
------------------------------------------------------------------------------]]
addon.Paladin = {};
addon.Paladin.BestowFaith = 223306;
addon.Paladin.HolyLight = 82326;
addon.Paladin.HolyShock = 25914;
addon.Paladin.LightOfDawn = 225311;
addon.Paladin.HolyPrism = 114871;
addon.Paladin.TyrsDeliverance = 200654;
addon.Paladin.ArcingLight = 119952;
addon.Paladin.FlashOfLight = 19750;
addon.Paladin.LightOfTheMartyr = 183998;
addon.Paladin.AuraOfMercy = 210291;
addon.Paladin.AuraOfSacrifice = 210383;
addon.Paladin.JudgementOfLight = 183811;
addon.Paladin.BeaconOfLight = 53652
addon.Paladin.LayOnHands = 633;
addon.Paladin.AvengingCrusader = 216371;

--																	I C H H V M L
createSpellInfo(addon.Paladin.BeaconOfLight,	SpellType.PALADIN,	T,T,_,T,T,T,_);
createSpellInfo(addon.Paladin.AuraOfSacrifice,	SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.AuraOfMercy,		SpellType.PALADIN,	T,T,_,T,T,_,T);
createSpellInfo(addon.Paladin.JudgementOfLight,	SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.BestowFaith,		SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.HolyLight,		SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.HolyShock,		SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.LightOfDawn,		SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.HolyPrism,		SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.TyrsDeliverance,	SpellType.PALADIN,	T,T,T,T,T,T,T);
createSpellInfo(addon.Paladin.ArcingLight,		SpellType.PALADIN,	T,T,T,T,T,T,T);
createSpellInfo(addon.Paladin.FlashOfLight,		SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.LightOfTheMartyr,	SpellType.PALADIN,	T,T,_,T,T,T,T);
createSpellInfo(addon.Paladin.AvengingCrusader,	SpellType.PALADIN,	T,T,_,T,T,_,T);
createSpellInfo(addon.Paladin.LayOnHands, 		SpellType.IGNORED);

local function setTransfersToBeacon(id)
	Spells[id].transfersToBeacon=true;
end

setTransfersToBeacon(addon.Paladin.BestowFaith);
setTransfersToBeacon(addon.Paladin.HolyLight);
setTransfersToBeacon(addon.Paladin.HolyShock);
setTransfersToBeacon(addon.Paladin.LightOfDawn);
setTransfersToBeacon(addon.Paladin.HolyPrism);
setTransfersToBeacon(addon.Paladin.TyrsDeliverance);
setTransfersToBeacon(addon.Paladin.ArcingLight);
setTransfersToBeacon(addon.Paladin.FlashOfLight);
setTransfersToBeacon(addon.Paladin.LightOfTheMartyr);

setRaidCooldown(addon.Paladin.AuraOfMercy);

setFillerSpell(addon.Paladin.HolyLight, 0.024);
setFillerSpell(addon.Paladin.FlashOfLight, 0.036);
setFillerSpell(addon.Paladin.LightOfTheMartyr, 0.015);






--[[----------------------------------------------------------------------------
	Mistweaver Monk
------------------------------------------------------------------------------]]
addon.Monk = {};
addon.Monk.RenewingMist = 119611;
addon.Monk.ChiBurst = 130654;
addon.Monk.GustOfMists = 191894;
addon.Monk.SoothingMist = 115175;
addon.Monk.EnvelopingMist = 124682;
addon.Monk.EssenceFont = 191840;
addon.Monk.HealingElixir = 122281;
addon.Monk.Revival = 115310;
addon.Monk.RJW = 162530;
addon.Monk.Vivify = 116670;
addon.Monk.CraneHeal = 198756;
addon.Monk.ChiWave = 132463;
addon.Monk.ZenPulse = 198487;
addon.Monk.TranquilMist = 253448; --T21
addon.Monk.ChiBolt = 253581; --T21
addon.Monk.LifeCocoon = 116849;
addon.Monk.EnvelopingMistTFT = 274062;

--																I C H H V M L
createSpellInfo(addon.Monk.RenewingMist,		SpellType.MONK,	T,T,T,T,T,_,T);
createSpellInfo(addon.Monk.RJW,					SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.EnvelopingMist,		SpellType.MONK,	T,T,T,T,T,_,T);
createSpellInfo(addon.Monk.EssenceFont,			SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.Vivify,				SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.Revival,				SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.CraneHeal,			SpellType.MONK,	T,_,_,T,T,_,T);
createSpellInfo(addon.Monk.SoothingMist,		SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.ChiBurst,			SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.ChiWave,				SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.ZenPulse,			SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.TranquilMist,		SpellType.MONK,	T,T,T,T,T,_,T);
createSpellInfo(addon.Monk.ChiBolt,				SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.LifeCocoon,			SpellType.MONK,	T,_,_,T,T,_,_);
createSpellInfo(addon.Monk.EnvelopingMistTFT,	SpellType.MONK,	T,T,_,T,T,_,T);
createSpellInfo(addon.Monk.HealingElixir,		SpellType.MONK,	_,_,_,T,_,_,_);
createSpellInfo(addon.Monk.GustOfMists,			SpellType.MONK,	T,T,_,T,T,T,T); --monk mastery

setRaidCooldown(addon.Monk.Revival);

setFillerSpell(addon.Monk.Vivify, 0.035);
setFillerSpell(addon.Monk.EnvelopingMist, 0.052);



--[[----------------------------------------------------------------------------
	Shared Spells
------------------------------------------------------------------------------]]
addon.Trinket = {};
addon.Trinket.HighfathersMachinations = 253288
addon.Trinket.EonarsEmeraldBlossom = 253288
addon.Trinket.EonarsVerdantEmbrace = 257444
addon.Trinket.IshkarFelshieldEmitter = 253277

addon.Enchant = {};
addon.Enchant.AncientPriestess = 228401;




--Trinkets																	I C H H V M L
createSpellInfo(addon.Trinket.HighfathersMachinations,	SpellType.SHARED,	_,T,_,_,T,_,_);	--Highfather's Machinations Trinket
createSpellInfo(addon.Trinket.EonarsEmeraldBlossom,		SpellType.SHARED,	_,T,T,_,T,_,_);	--Eonars trinket (Emerald Blossom)
createSpellInfo(addon.Trinket.EonarsVerdantEmbrace,		SpellType.SHARED,	_,_,_,_,T,_,_);	--Eonars trinket (Verdant Embrace)
createSpellInfo(addon.Trinket.IshkarFelshieldEmitter,	SpellType.SHARED,	_,_,_,_,T,_,_);	--Ishkar's Felshield Emmitter

--Enchants
createSpellInfo(addon.Enchant.AncientPriestess, 		SpellType.SHARED,	T,T,T,_,T,_,_);




--[[----------------------------------------------------------------------------
	Ignored Spells
------------------------------------------------------------------------------]]
createSpellInfo(143924, SpellType.IGNORED); --leech (calculated from other spells)
createSpellInfo(235967, SpellType.IGNORED); --velen's future sight (calculated from other spells)



--[[----------------------------------------------------------------------------
	Shared Buffs
------------------------------------------------------------------------------]]
addon.VelensId = 235966;
addon.BuffTracker:Track(addon.VelensId) --velen's future sight

addon.Spells = Spells;
addon.SpellType = SpellType;