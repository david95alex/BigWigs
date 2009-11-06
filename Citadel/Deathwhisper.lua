if not QueryQuestsCompleted then return end
--------------------------------------------------------------------------------
-- Module declaration
--

local mod = BigWigs:NewBoss("Lady Deathwhisper", "Icecrown Citadel")
if not mod then return end
mod:RegisterEnableMob(36855)
mod.toggleOptions = {71289, 70842, 71001, "berserk", "bosskill"}

-- 71289 Dominate Mind
-- 71001 Death & Decay
-- 70842 Mana barrier
--------------------------------------------------------------------------------
-- Locals
--

local pName = UnitName("player")
local mindControlled = mod:NewTargetList()

--------------------------------------------------------------------------------
--  Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.dnd_message = "Death and Decay on YOU!"
	L.phase2_message = "Mana barrier gone - Phase 2!"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:OnBossEnable()
	--self:Log("SPELL_CAST_SUCCESS", "DnD_cast", 71001) --timer+cd?
	self:Log("SPELL_AURA_APPLIED", "DND", 71001)
	self:Log("SPELL_AURA_REMOVED", "Barrier", 70842)
	self:Log("SPELL_AURA_APPLIED", "DominateMind", 71289)
	self:Death("Win", 36855)

	self:RegisterEvent("PLAYER_REGEN_ENABLED", "CheckForWipe")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "CheckForEngage")
end

function mod:OnEngage()
	self:Berserk(600, true)
end


--------------------------------------------------------------------------------
-- Event handlers
--

function mod:DND(player, spellId)
	if player == pName then
		self:LocalMessage(71001, L["dnd_message"], "Personal", spellId, "Alarm")
	end
end

function mod:Barrier(_, spellId, _, _, spellName)
	self:Message(70842, L["phase2_message"], "Positive", spellId)
end

do
	local handle = nil
	local warned = nil
	local id, name = nil, nil
	local function mc()
		if not warned then
			mod:TargetMessage(71289, name, mindControlled, "Urgent", id)
		else
			warned = nil
			wipe(mindControlled)
		end
		handle = nil
	end
	function mod:DominateMind(player, spellId, _, _, spellName)
		mindControlled[#mindControlled + 1] = player
		if handle then self:CancelTimer(handle, true) end
		id, name = spellId, spellName
		handle = self:ScheduleTimer(mc, 0.1)
		if player == pName then
			warned = true
			self:TargetMessage(71289, spellName, player, "Important", spellId, "Info")
		end
	end
end
