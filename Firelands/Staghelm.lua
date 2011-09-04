--------------------------------------------------------------------------------
-- Module Declaration
--

local mod = BigWigs:NewBoss("Majordomo Staghelm", 800, 197)
if not mod then return end
mod:RegisterEnableMob(52571)

--------------------------------------------------------------------------------
-- Locales
--

local leapingFlames, flameScythe = (GetSpellInfo(98476)), (GetSpellInfo(100213))
-- got data up to 15 stacks, after 11 its 3.7
local specialCD = {17.5, 13.4, 10.9, 8.6, 7.4, 7.3, 6.1, 6.1, 4.9, 4.9, 4.9}
local specialCounter = 1
local form = "cat"
local seedTimer = nil

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.seed_explosion = "You explode soon!"
	L.seed_bar = "You explode!"
	L.adrenaline_message = "Adrenaline x%d!"
	L.leap_say = "Leap on ME!"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		98379, 100213,
		{98374, "PROXIMITY"}, {98476, "FLASHSHAKE", "ICON", "SAY"},
		{98450, "FLASHSHAKE", "PROXIMITY"}, 98451,
		97238, "berserk", "bosskill"
	}, {
		[98379] = 98379,
		[98374] = 98374,
		[98450] = "ej:2922",
		[97238] = "general"
	}
end

function mod:OnBossEnable()
	self:Log("SPELL_AURA_APPLIED", "Adrenaline", 97238)
	self:Log("SPELL_AURA_APPLIED_DOSE", "Adrenaline", 97238)
	self:Log("SPELL_AURA_APPLIED", "CatForm", 98374)
	self:Log("SPELL_AURA_APPLIED", "ScorpionForm", 98379)
	self:Log("SPELL_CAST_SUCCESS", "LeapingFlames", 98476, 100206)
	self:Log("SPELL_CAST_START", "RecklessLeap", 99629)
	self:Log("SPELL_AURA_APPLIED", "SearingSeeds", 98450)
	self:Log("SPELL_AURA_REMOVED", "SearingSeedsRemoved", 98450)
	self:Log("SPELL_CAST_START", "BurningOrbs", 98451)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Win", 52571)
end

function mod:OnEngage(diff)
	self:Berserk(600) -- assumed
	specialCounter = 1
	form = "cat"
	seedTimer = nil
end

--------------------------------------------------------------------------------
-- Event Handlers
--

function mod:Adrenaline(_, spellId, _, _, spellName, stack)
	self:Message(97238, L["adrenaline_message"]:format(stack or 1), "Attention", spellId)
	 -- this is power based, not time. Power regen is affected by adrenaline
	 -- adrenaline gets stacked every special
	specialCounter = specialCounter + 1
	if form == "cat" then
		self:Bar(98476, leapingFlames, specialCD[specialCounter] or 3.7, 98476)
	elseif form == "scorpion" then
		self:Bar(100213, flameScythe, specialCD[specialCounter] or 3.7, 100213)
	end
end

do
	local prev, fired, timer = 0, 0, nil
	local function checkTarget()
		fired = fired + 1
		local player = UnitName("boss1target")
		if player and not UnitDetailedThreatSituation("boss1target", "boss1") then
			mod:CancelTimer(timer, true)
			timer = nil
			if UnitIsUnit("player", "boss1target") then
				mod:Say(98476, L["leap_say"])
				mod:FlashShake(98476)
			end
			mod:TargetMessage(98476, leapingFlames, player, "Urgent", 98476, "Long")
			mod:PrimaryIcon(98476, player)
			return
		end
		if fired > 18 then
			mod:CancelTimer(timer, true)
			timer = nil
		end
	end
	function mod:LeapingFlames()
		local t = GetTime() --Throttle as it's sometimes casted twice in the log
		if t-prev > 2 then
			prev, fired = t, 0
			fired = 0
			if not timer then
				timer = self:ScheduleRepeatingTimer(checkTarget, 0.05)
			end
		end
	end
end

do
	local function checkTarget(guid)
		for i=1, GetNumRaidMembers() do
			local leapTarget = ("%s%d%s"):format("raid", i, "target")
			if UnitGUID(leapTarget) == guid and UnitIsUnit("player", leapTarget.."target") then
				mod:Say(98476, L["leap_say"])
				mod:FlashShake(98476)
				break
			end
		end
	end
	function mod:RecklessLeap(...)
		local sGUID = select(11, ...)
		--3sec cast so we have room to balance accuracy vs reaction time
		self:ScheduleTimer(checkTarget, 0.6, sGUID)
	end
end

function mod:CatForm(_, spellId, _, _, spellName)
	form = "cat"
	self:Message(98374, spellName, "Important", spellId, "Alert")
	if not seedTimer then
		--Don't open if already opened from seed
		self:OpenProximity(10, 98374)
	end
	specialCounter = 1
	self:Bar(98476, leapingFlames, specialCD[specialCounter], 98476)
end

function mod:ScorpionForm(_, spellId, _, _, spellName)
	form = "scorpion"
	self:Message(98379, spellName, "Important", spellId, "Alert")
	self:CloseProximity(98374)
	specialCounter = 1
	self:Bar(100213, flameScythe, specialCD[specialCounter], 100213)
end

function mod:SearingSeedsRemoved(player)
	if not UnitIsUnit(player, "player") then return end
	self:SendMessage("BigWigs_StopBar", self, L["seed_bar"])
	if form == "cat" then
		self:OpenProximity(10, 98374)
	else
		self:CloseProximity(98450)
	end
	self:CancelTimer(seedTimer, true)
	seedTimer = nil
end

function mod:BurningOrbs(_, spellId, _, _, spellName)
	self:Bar(98451, spellName, 64, spellId)
end

do
	local function searingSeed()
		mod:LocalMessage(98450, L["seed_explosion"], "Personal", 98450, "Alarm")
		mod:FlashShake(98450)
		mod:OpenProximity(12, 98450)
	end

	function mod:SearingSeeds(player, spellId, _, _, spellName)
		self:SendMessage("BigWigs_StopBar", self, leapingFlames)
		if not UnitIsUnit(player, "player") then return end
		local remaining = (select(7, UnitDebuff("player", spellName))) - GetTime()
		self:Bar(98450, L["seed_bar"], remaining, spellId)
		if remaining < 5 then
			searingSeed()
		else
			seedTimer = self:ScheduleTimer(searingSeed, remaining - 5)
		end
	end
end

