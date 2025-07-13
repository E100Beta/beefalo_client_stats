local scrapbook_data = require("screens/redux/scrapbookdata")

local BUILDS = {}

local DECAY_TASK_PERIOD = 10
local PERMISSIBLE_DOMESTICATION_ERROR = 0.03

-----------------------------------------------------
-- UTILITY
-----------------------------------------------------

-- Put this in another file

-- this is a very funny way to find out what's our tendency is
-- basically we try to find ids of animation builds of beefalo faces
-- took me 2 weeks to figure this out smh
local function SetBuilds(beefalo)
    if #BUILDS > 0 then
        return
    end

    local build_names = {
        ORNERY = "beefalo_personality_ornery",
        PUDGY = "beefalo_personality_pudgy",
        RIDER = "beefalo_personality_docile",
    }

    local original_build, _ = beefalo.AnimState:GetSymbolOverride("beefalo_mouthmouth")

    for tendency, build_name in pairs(build_names) do
        beefalo.AnimState:AddOverrideBuild(build_name)
        local build, _ = beefalo.AnimState:GetSymbolOverride("beefalo_mouthmouth")
        BUILDS[build] = tendency
    end

    if original_build == nil then
        beefalo.AnimState:ClearOverrideBuild("beefalo_personality_docile")
    else
        beefalo.AnimState:AddOverrideBuild(build_names[BUILDS[original_build]])
    end
end

local function GetTendency(beefalo)
    local build, _ = beefalo.AnimState:GetSymbolOverride("beefalo_mouthmouth")
    return BUILDS[build] or "DEFAULT"
end

local function AnimationIn(inst, animations)
    for i, anim in ipairs(animations) do
        if inst.AnimState:IsCurrentAnimation(anim) then
            return true
        end
    end
    return false
end

local function table_tostring(t)
    local str = ""
    for k, v in pairs(t) do
        str = str .. tostring(k) .. ": " .. tostring(v) .. ", "
    end
    return str
end

-----------------------------------------------------
-- CLASS
-----------------------------------------------------

local BeefaloTracker = Class(function(self, inst)
    self.inst = inst
    self.player = nil
    self.ui = nil

    self.hunger = self:GetLowest("hunger")
    self.obedience = self:GetLowest("obedience")
    self.domestication = self:GetLowest("domestication")

    self.last_domestication_gain = 0
    self.last_update = 0
    self.start_ride = nil

    SetBuilds(self.inst)
end)

function BeefaloTracker:OnRemoveFromEntity()
    self:CancelTask()
end

function BeefaloTracker:OnSave()
    return {
        hunger = self.hunger,
        obedience = self.obedience,
        domestication = self.domestication,
        last_domestication_gain = self.last_domestication_gain,
        last_update = self.last_update,
    }
end

function BeefaloTracker:OnLoad(data, newents)
    if data ~= nil then
        self.hunger = data.hunger
        self.obedience = data.obedience
        self.domestication = data.domestication
        self.last_domestication_gain = data.last_domestication_gain
        self.last_update = data.last_update
    end
end

function BeefaloTracker:IsCurrentBeefalo()
    if self.player == nil then
        return false
    end
    local bell = self.inst.replica.follower:GetLeader()
    return bell.replica.inventoryitem:IsHeldBy(self.player)
end

function BeefaloTracker:GetTendency()
    if #BUILDS == 0 then
        SetBuilds(self.inst)
    end
    return GetTendency(self.inst)
end

function UpdateStats(inst, self)
    local last_update = self.last_update
    local this_update = GetServerTime()
    local dt = this_update - last_update

    -- OBEDIENCE
    local obedience_loss = TUNING.BEEFALO_DOMESTICATION_STARVE_OBEDIENCE / 2
    if self.hunger == 0 then
        -- starving is x2 + base
        obedience_loss = obedience_loss * 3
    end
    self:SyncObedience({ delta = obedience_loss * dt })

    -- HUNGER
    self:SyncHunger({ delta = -TUNING.BEEFALO_HUNGER_RATE * dt })

    -- DOMESTICATION
    local domestication_delta
    local is_riding = self.player.replica.rider:IsRiding()
    if self.hunger > 0 or is_riding then
        self.last_domestication_gain = GetServerTime()
        domestication_delta = TUNING.BEEFALO_DOMESTICATION_GAIN_DOMESTICATION
        if is_riding and self.player.components.skilltreeupdater:HasSkillTag("beefalodomestication") then
            domestication_delta = domestication_delta * TUNING.SKILLS.WATHGRITHR.WATHGRITHRHAT_BEEFALO_DOMESTICATION_MOD
        end
    else
        -- TODO: I'm really not sure if that's right. Doesn't line up with
        -- wiki numbers, maybe I'm missing something?
        domestication_delta = math.min(
            (this_update - self.last_domestication_gain)
                / (TUNING.BEEFALO_DOMESTICATION_MAX_LOSS_DAYS * TUNING.TOTAL_DAY_TIME),
            1
        ) * TUNING.BEEFALO_DOMESTICATION_LOSE_DOMESTICATION
    end
    self:SyncDomestication({ delta = domestication_delta * dt })

    self.last_update = this_update
end

function BeefaloTracker:StartTask()
    self.decaytask = self.inst:DoPeriodicTask(DECAY_TASK_PERIOD, UpdateStats, 0, self)
end

function BeefaloTracker:CancelTask()
    if self.decaytask ~= nil then
        self.decaytask:Cancel()
    end
end

function BeefaloTracker:GetHighest(stat)
    if stat == "hunger" then
        return TUNING.BEEFALO_HUNGER
    end
    return 1
end

function BeefaloTracker:GetLowest(stat)
    if stat == "hunger" then
        return 0
    elseif stat == "domestication" then
        -- don't care about domestication after domesticating
        -- TODO: care
        if self.inst:HasTag("domesticated") then
            return 1
        else
            return 0
        end
    elseif stat == "obedience" then
        if self.inst:HasTag("domesticated") then
            return TUNING.BEEFALO_MIN_DOMESTICATED_OBEDIENCE[self:GetTendency()]
        else
            return 0
        end
    end
end

function BeefaloTracker:SyncStat(stat, data)
    if data.delta ~= nil then
        self[stat] = self[stat] + data.delta
    end
    if data.set ~= nil then
        self[stat] = data.set
    end

    -- clamp value
    local default_highest = (stat == "hunger") and TUNING.BEEFALO_HUNGER or 1
    local highest = math.min(self:GetHighest(stat), data.highest or default_highest)
    local lowest = math.max(self:GetLowest(stat), data.lowest or 0)
    self[stat] = math.min(math.max(self[stat], lowest), highest)
end

function BeefaloTracker:SyncObedience(data)
    local old_stat = self.obedience
    self:SyncStat("obedience", data)
    self.ui:on_obedience_change_fn({ old = old_stat, new = self.obedience })
end

function BeefaloTracker:SyncHunger(data)
    local old_stat = self.hunger
    self:SyncStat("hunger", data)
    self.ui:on_hunger_change_fn({ old = old_stat, new = self.hunger })
end

function BeefaloTracker:SyncDomestication(data)
    local old_stat = self.domestication
    self:SyncStat("domestication", data)
    self.ui:on_domestication_change_fn({ old = old_stat, new = self.domestication })
end

function BeefaloTracker:ResetRide(data)
    if data.start ~= nil then
        self.start_ride = data.start
        local time = self:GetRideTime()
        self.ui:on_timer_change_fn({ is_start = true, start = self.start_ride, ridetime = time })
    end
    if data.finish ~= nil then
        local start = self.start_ride
        self.start_ride = nil
        self.ui:on_timer_change_fn({ is_start = false, start = start, finish = GetServerTime() })
    end
end

function BeefaloTracker:GetRideMult()
    local mult = 1
    if self.inst:HasTag("scarytoprey") then
        mult = mult * TUNING.BEEFALO_BUCK_TIME_MOOD_MULT
    end
    if not self.inst:HasTag("bearded") then
        mult = mult * TUNING.BEEFALO_BUCK_TIME_NUDE_MULT
    end
    if self.player.components.skilltreeupdater:HasSkillTag("beefalobucktime") then
        mult = mult * TUNING.SKILLS.WATHGRITHR.WATHGRITHR_BEEFALO_BUCK_TIME_MOD
    end
    if not self.inst:HasTag("domesticated") then
        mult = mult * TUNING.BEEFALO_BUCK_TIME_UNDOMESTICATED_MULT
    end
    return mult
end

function BeefaloTracker:GetRideTime()
    if self.start_ride == nil then
        return nil
    end
    local time = Remap(self.domestication, 0, 1, TUNING.BEEFALO_MIN_BUCK_TIME, TUNING.BEEFALO_MAX_BUCK_TIME)
    local mult = self:GetRideMult()

    return math.max(time * mult - (GetServerTime() - self.start_ride), 0)
end

function BeefaloTracker:OnPerformedSuccessDirty(player)
    player:DoTaskInTime(0, function(_)
        -- NOTE: sometimes lastheldaction doesn't reset for a long time
        local last_action = player.components.playercontroller.lastheldaction
        if last_action == nil then
            return
        end
        print("BCS: got action " .. tostring(last_action))

        local action = last_action.action
        local item = last_action.invobject
        local is_success = player.player_classified.isperformactionsuccess:value()

        if
            (action == ACTIONS.GIVE or (player.replica.rider:IsRiding() and action == ACTIONS.FEED))
            and is_success
            and item:HasAnyTag("edible_roughage", "edible_veggie")
        then
            print("BCS: fed with " .. tostring(item))
            self:SyncHunger({ delta = scrapbook_data[item.prefab].hungervalue })
            self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_FEED_OBEDIENCE })
            if player.replica.rider:IsRiding() then
                self:ResetRide({ start = GetServerTime() })
            end
        end

        -- Brushing is almost almost always success because it drains durability
        if action == ACTIONS.BRUSH and self.inst.AnimState:IsCurrentAnimation("brush") then
            print("BCS: Brushed beefalo, he likes it!")
            self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_BRUSHED_OBEDIENCE })
            self:SyncDomestication({ delta = TUNING.BEEFALO_DOMESTICATION_BRUSHED_DOMESTICATION })
        end

        -- Also counts as success for some reason
        if action == ACTIONS.MOUNT and self.inst.AnimState:IsCurrentAnimation("mating_taunt1") then
            print("BCS: beefalo refused riding")
            self:SyncObedience({ highest = 0.49 })
        end

        if player.replica.combat:GetTarget() == self.inst then
            print("BCS: CONGRATS ON -30% DOMESTICATION LMAO")
            self:SyncDomestication({ delta = TUNING.BEEFALO_DOMESTICATION_ATTACKED_BY_PLAYER_DOMESTICATION })
        end

        if action == ACTIONS.DROP and item == self.inst.replica.follower:GetLeader() then
            self:UnHookPlayer(player)
        end
    end)

    -- TODO: check post-animations, probably inst:StartThread and Sleep?
    -- beg_pre, beg_loop, beg_pst: probably can be used to set hunger below 168.5? Not here.
    -- fart: can be used to sync hunger
    -- vomit: can be used to sync hunger, also obedience and domestication
end

function BeefaloTracker:OnIsRidingDirty(player)
    player:DoTaskInTime(0, function(_)
        if player.replica.rider:IsRiding() then
            self:ResetRide({ start = GetServerTime() })
            self:SyncObedience({ lowest = 0.5 })
        else
            if AnimationIn(self.player, { "buck", "bucked", "buck_pst" }) and self.start_ride ~= nil then
                if self.inst:HasTag("domesticated") then
                    return
                end

                local end_ride = GetServerTime()
                local mult = self:GetRideMult()
                local ride_time = (end_ride - self.start_ride) / mult
                -- / by wigfrid skill and other mults?
                local calculated_domestication =
                    Remap(ride_time, TUNING.BEEFALO_MIN_BUCK_TIME, TUNING.BEEFALO_MAX_BUCK_TIME, 0, 1)
                if math.abs(self.domestication - calculated_domestication) > PERMISSIBLE_DOMESTICATION_ERROR then
                    self:SyncDomestication({ set = calculated_domestication })
                end
            end
            self:ResetRide({ finish = GetServerTime() })
        end
    end)
end

function BeefaloTracker:OnAttacked(player, data)
    print("BCS: onattack data: " .. table_tostring(data))
    if player.replica.rider:IsRiding() and data.redirected then
        self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_ATTACKED_OBEDIENCE })
    end
end

function BeefaloTracker:OnItemLose(player)
    -- Must check every instance of this noisy event, since "dropitem" event
    -- is not for client. Data on this event is generally useless too.
    -- Thankfully, IsHeldBy is more than enough for our case.
    -- But as usual it doesn't update on event so DoTaskInTime it is
    player:DoTaskInTime(0, function(_)
        local bell = self.inst.replica.follower:GetLeader()
        if
            bell ~= nil
            and (bell.replica.inventoryitem:IsHeldBy(player) or player.replica.inventory:GetActiveItem() == bell)
        then
            return
        end

        self:UnHookPlayer(player)
    end)
end

function BeefaloTracker:HookPlayer(player)
    if self.player ~= nil then
        print("BCS: player already hooked in")
        return
    else
        print("BCS: hooking player in")
    end

    self.player = player

    -- I could've made this more clean, but eh
    self.isridingdirty_fn = function(_)
        self:OnIsRidingDirty(player)
    end
    player:ListenForEvent("isridingdirty", self.isridingdirty_fn)

    self.attacked_fn = function(_, data)
        self:OnAttacked(player, data)
    end
    player:ListenForEvent("attacked", self.attacked_fn)

    self.itemlose_fn = function(_, _)
        self:OnItemLose(player)
    end
    player:ListenForEvent("itemlose", self.itemlose_fn)

    self.isperformactionsuccessdirty_fn = function(_)
        self:OnPerformedSuccessDirty(player)
    end
    player.player_classified:ListenForEvent("isperformactionsuccessdirty", self.isperformactionsuccessdirty_fn)

    self.ui = player.HUD.controls.status.beefalostatusdisplays
    self.ui:Show()

    if player.replica.rider:IsRiding() then
        self:ResetRide({ start = GetServerTime() })
    end

    self:StartTask()

    -- idea: dropitem: if dropped check if withing radius of salt lick, but syncing this is probably too hard
    -- I mean, we put bell near salt lick, check if we should pause domestication on next tick, then another
    -- player transports a bell to us on our beefalo, sooo how much domestication do we have?
    -- We should probably check for a lick on both drop and pickup?
end

function BeefaloTracker:UnHookPlayer(player)
    print("BCS: unhooking player from beefalo")

    self.player = nil

    if self.isridingdirty_fn ~= nil then
        player:RemoveEventCallback("isridingdirty", self.isridingdirty_fn)
    end

    if self.attacked_fn ~= nil then
        player:RemoveEventCallback("attacked", self.attacked_fn)
    end

    if self.itemlose_fn ~= nil then
        player:RemoveEventCallback("itemlose", self.itemlose_fn)
    end

    if self.isperformactionsuccessdirty_fn ~= nil then
        player.player_classified:RemoveEventCallback("isperformactionsuccessdirty", self.isperformactionsuccessdirty_fn)
    end

    self.ui:Hide()
    self.ui = nil

    self:CancelTask()
end

return BeefaloTracker
