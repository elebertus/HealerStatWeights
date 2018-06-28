local name, addon = ...;
local T = true;
local F = false;



--[[----------------------------------------------------------------------------
	Vars for common spellIds (put ids here if you will use them in other files)
------------------------------------------------------------------------------]]
addon.VelensId = 235966;



--[[----------------------------------------------------------------------------
	SpellType - Enumeration of specialization ids for each healing spec; 
				and a "Shared" type for spells used by all healing specializations (Trinkets, etc.)
------------------------------------------------------------------------------]]
local SpellType = {
	DRUID = 105,
	SHAMAN = 264,
	HPRIEST = 257,
	PALADIN = 65, 
	-- Mistweaver 270
	-- Disc 256
	SHARED = 1
}



--[[----------------------------------------------------------------------------
	Spells - stored spell data. Used by the parsers/decomp methods.
------------------------------------------------------------------------------]]
local Spells = {};



--[[----------------------------------------------------------------------------
	createSpellInfo - helper function for setting up spell information
------------------------------------------------------------------------------]]
local function createSpellInfo(id, spellType, isIntScaled, isCritScaled, isHasteHPMScaled, isHasteHPCTScaled, isVersScaled, isMasteryScaled, isLeechScaled, isRaidCD, IsHasteHPMScaledOnPeriodic, isFiller, manaCost)
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
		cd = isRaidCD,
		filler = isFiller,
		manaCost = manaCost or -1,
		hstHPMPeriodic = IsHasteHPMScaledOnPeriodic
	}
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
--											I C H H V M L 1 2 3 4
createSpellInfo(740,	SpellType.DRUID,	T,T,F,T,T,T,T,T,F,F);		--Tranquility
createSpellInfo(157982,	SpellType.DRUID,	T,T,T,T,T,T,T,T,F,F);		--Tranquility HOT (BFA)
createSpellInfo(774,	SpellType.DRUID,	T,T,T,T,T,T,T,F,F,T, 0.02);	--Rejuvenation
createSpellInfo(155777,	SpellType.DRUID,	T,T,T,T,T,T,T,F,F,T, 0.02);	--Germination
createSpellInfo(33763,	SpellType.DRUID,	T,T,T,T,T,T,T,F,F,F);		--Lifebloom (HoT)
createSpellInfo(33778,	SpellType.DRUID,	T,T,F,T,T,T,T,F,F,F);		--Lifebloom (Bloom)
createSpellInfo(8936,	SpellType.DRUID,	T,T,F,T,T,T,T,F,T,F);		--Regrowth
createSpellInfo(48438,	SpellType.DRUID,	T,T,T,T,T,T,T,F,F,F);		--Wild Growth
createSpellInfo(189853,	SpellType.DRUID,	T,T,F,T,T,T,T,F,F,F);		--Wild Growth (Dreamwalker)
createSpellInfo(189800,	SpellType.DRUID,	T,T,F,T,T,T,T,F,F,F);		--Wild Growth (Nature's Essence)
createSpellInfo(145205,	SpellType.DRUID,	T,T,T,T,T,T,T,F,F,F);		--Effloresence
createSpellInfo(18562,	SpellType.DRUID,	T,T,F,T,T,T,T,F,F,F);		--Swiftmend
createSpellInfo(5185,	SpellType.DRUID,	T,T,F,T,T,T,T,F,F,F);		--Healing Touch (Legion)
createSpellInfo(48500,	SpellType.DRUID,	T,T,F,T,T,T,T,F,F,F);		--Living Seed (Legion)
createSpellInfo(22842,	SpellType.DRUID,	F,F,F,T,F,T,F,F,F,F); 		--Frenzied Regen

createSpellInfo(207386,	SpellType.DRUID,	T,T,T,F,T,T,T,F,F,F);		--Spring Blossoms, indirect scaling with haste as a hot.
createSpellInfo(200389,	SpellType.DRUID,	T,T,T,F,T,T,T,F,F,F);		--Cultivation
createSpellInfo(102352,	SpellType.DRUID,	T,T,T,T,T,T,T,F,F,F);		--Cenarion Ward
createSpellInfo(108238,	SpellType.DRUID,	F,F,F,T,F,F,F,F,F,F);		--Renewal
createSpellInfo(253432,	SpellType.DRUID,	T,T,T,F,T,T,T,F,F,F);		--Dreamer (T21)



--[[----------------------------------------------------------------------------
	Resto Shaman
------------------------------------------------------------------------------]]
addon.ShamanResurgence = 101033;

--											I C H H V M L 1 2 3 4
createSpellInfo(77472,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,T, 0.018);--Healing Wave
createSpellInfo(252159,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--Downpour
createSpellInfo(207778,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--Gift of the Queen
createSpellInfo(255227,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--Gift of the Queen (2)
createSpellInfo(61295,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,T,F);		--Riptide
createSpellInfo(252154,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--Rainfall
createSpellInfo(1064, 	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,T, 0.05);	--Chain Heal
createSpellInfo(114942, SpellType.SHAMAN,	T,T,T,T,T,T,T,T,F,F);		--Healing Tide Totem (Raid CD)
createSpellInfo(8004,  	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,T, 0.04);	--Healing Surge
createSpellInfo(52042, 	SpellType.SHAMAN,	T,T,T,T,T,T,T,F,F,F);		--Healing Stream Totem
createSpellInfo(73921, 	SpellType.SHAMAN,	T,T,T,T,T,T,T,F,F,F);		--Healing Rain
createSpellInfo(157503, SpellType.SHAMAN,	T,T,F,T,T,T,F,F,F,F);		--Cloudburst explosion (spell is handled as a special case in the shaman analyzer).

createSpellInfo(200071, SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--Undulation
createSpellInfo(73685,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--Unleash Life
createSpellInfo(197997,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--Wellspring

--todo Ascendance/AG
--createSpellInfo(114911,	SpellType.SHAMAN,	T,T,F,T,T,T,T,F,F,F);		--AG


--[[----------------------------------------------------------------------------
	Holy Priest
------------------------------------------------------------------------------]]
--											I C H H V M L 1 2 3 4
createSpellInfo(139,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,T,F);		--Renew
createSpellInfo(2050,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Serenity
createSpellInfo(596,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,T, 0.045);--Prayer of Healing
createSpellInfo(2060,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,T, 0.017);--Heal
createSpellInfo(2061,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,T, 0.028);--Flash Heal
createSpellInfo(32546,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Binding Heal
createSpellInfo(19236,	SpellType.HPRIEST,	F,T,F,T,T,F,T,F,F,F);		--Desperate Prayer
createSpellInfo(243241,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Cosmic Ripple
createSpellInfo(64844,	SpellType.HPRIEST,	T,T,F,T,T,F,T,T,F,F);		--Divine Hymn
createSpellInfo(34861,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Holy Word: Sanctify
createSpellInfo(208065,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Light of T'uure
createSpellInfo(33110,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Prayer of Mending

createSpellInfo(120692,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Halo
createSpellInfo(204883,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Circle of Healing
createSpellInfo(234946,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Trail of Light
createSpellInfo(110745,	SpellType.HPRIEST,	T,T,F,T,T,F,T,F,F,F);		--Divine Star
createSpellInfo(214121,	SpellType.HPRIEST,	T,T,T,T,T,F,T,F,F,F);		--Body and Mind

createSpellInfo(77489,	SpellType.HPRIEST,	T,T,F,T,T,T,T,F,F,F);		--Echo of Light




--[[----------------------------------------------------------------------------
	Holy Paladin
------------------------------------------------------------------------------]]
addon.PaladinBestowFaith = 223306;
addon.PaladinHolyLight = 82326;
addon.PaladinHolyShock = 25914;
addon.PaladinLightOfDawn = 225311;
addon.PaladinHolyPrism = 114871;
addon.PaladinTyrsDeliverance = 200654;
addon.PaladinArcingLight = 119952;
addon.PaladinFlashOfLight = 19750;
addon.PaladinLightOfTheMartyr = 183998;
addon.PaladinAuraOfMercy = 210291;
addon.PaladinAuraOfSacrifice = 210383;
addon.PaladinJudgementOfLight = 183811;
addon.BeaconOfLight = 53652

--																	I C H H V M L 1 2 3	
createSpellInfo(addon.BeaconOfLight,			SpellType.PALADIN,	T,T,F,T,T,T,F,F,F,F);		--Beacon Healing
createSpellInfo(addon.PaladinAuraOfSacrifice,	SpellType.PALADIN,	T,T,F,T,T,T,T,T,F,F);		--Aura of Sacrifice
createSpellInfo(addon.PaladinAuraOfMercy,		SpellType.PALADIN,	T,T,F,T,T,F,T,T,F,F);		--Aura of Mercy
createSpellInfo(addon.PaladinJudgementOfLight,	SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,F);		--Judgement of Light

createSpellInfo(addon.PaladinBestowFaith,		SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,F);		--Bestow Faith
createSpellInfo(addon.PaladinHolyLight,			SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,T, 0.024);--Holy Light
createSpellInfo(addon.PaladinHolyShock,			SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,F);		--Holy Shock
createSpellInfo(addon.PaladinLightOfDawn,		SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,F);		--Light of Dawn
createSpellInfo(addon.PaladinHolyPrism,			SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,F);		--Holy Prism
createSpellInfo(addon.PaladinTyrsDeliverance,	SpellType.PALADIN,	T,T,T,T,T,T,T,F,F,F);		--Tyr's Deliverance
createSpellInfo(addon.PaladinArcingLight,		SpellType.PALADIN,	T,T,T,T,T,T,T,F,F,F);		--Arcing Light
createSpellInfo(addon.PaladinFlashOfLight,		SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,T, 0.036);--Flash of Light
createSpellInfo(addon.PaladinLightOfTheMartyr,	SpellType.PALADIN,	T,T,F,T,T,T,T,F,F,T, 0.015);--Light of the Martyr

Spells[addon.PaladinBestowFaith].transfersToBeacon = true;
Spells[addon.PaladinHolyLight].transfersToBeacon = true;
Spells[addon.PaladinHolyShock].transfersToBeacon = true;
Spells[addon.PaladinLightOfDawn].transfersToBeacon = true;
Spells[addon.PaladinHolyPrism].transfersToBeacon = true;
Spells[addon.PaladinTyrsDeliverance].transfersToBeacon = true;
Spells[addon.PaladinArcingLight].transfersToBeacon = true;
Spells[addon.PaladinFlashOfLight].transfersToBeacon = true;
Spells[addon.PaladinLightOfTheMartyr].transfersToBeacon = true;



--[[----------------------------------------------------------------------------
	Shared Spells
------------------------------------------------------------------------------]]
--Trinkets									I C H H V M L 1 2 3  
createSpellInfo(253288,	SpellType.SHARED,	F,T,F,F,T,F,F,F,F,F);	--Highfather's Machinations Trinket
createSpellInfo(257442,	SpellType.SHARED,	F,T,T,F,T,F,F,F,F,F);	--Eonars trinket (Emerald Blossom)
createSpellInfo(257444,	SpellType.SHARED,	F,F,F,F,T,F,F,F,F,F);	--Eonars trinket (Verdant Embrace)
createSpellInfo(253277,	SpellType.SHARED,	F,F,F,F,T,F,F,F,F,F);	--Ishkar's Felshield Emmitter

--Enchants
createSpellInfo(228401, SpellType.SHARED,	T,T,T,F,T,F,T,F,F,F); 	--Mark of the Ancient Priestess

--NLC
createSpellInfo(252208,	SpellType.SHARED,	F,F,T,F,T,F,F,F,F,F);	--Refractive Shell
createSpellInfo(253111,	SpellType.SHARED,	F,F,T,F,T,F,F,F,F,F);	--Light's Embrace
createSpellInfo(253099,	SpellType.SHARED,	F,F,T,F,T,F,F,F,F,F);	--Infusion of Light
createSpellInfo(253070,	SpellType.SHARED,	F,F,T,F,T,F,F,F,F,F);	--Secure in the Light
createSpellInfo(252888,	SpellType.SHARED,	F,F,T,F,T,F,F,F,F,F);	--Chaotic Darkness
createSpellInfo(252875,	SpellType.SHARED,	F,F,T,F,T,F,F,F,F,F);	--Shadowbind
createSpellInfo(253070,	SpellType.SHARED,	F,F,T,F,T,F,F,F,F,F);	--Secure in the Light




--[[----------------------------------------------------------------------------
	Shared Buffs
------------------------------------------------------------------------------]]
addon.BuffTracker:Track(addon.VelensId) --velen's future sight

DBG=Spells;

addon.Spells = Spells;
addon.SpellType = SpellType;