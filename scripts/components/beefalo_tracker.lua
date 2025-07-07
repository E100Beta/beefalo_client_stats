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
    for anim in animations do
        if inst.AnimState:IsCurrentAnimation(anim) then
            return true
        end
    end
    return false
end

-----------------------------------------------------
-- CLASS
-----------------------------------------------------

local BeefaloTracker = Class(function(self, inst)
    self.inst = inst
    self.player = nil

    self.hunger = self:GetLowest("hunger")
    self.obedience = self:GetLowest("obedience")
    self.domestication = self:GetLowest("domestication")

    self.last_domestication_gain = 0
    self.last_update = nil
    self.start_ride = nil
    self.last_active_item = nil

    SetBuilds(self.inst)
    self.tendency = GetTendency(self.inst)
end)

function BeefaloTracker:OnRemoveFromEntity()
    self:CancelTask()
end

function BeefaloTracker:IsCurrentBeefalo()
    if self.player == nil then
        return false
    end
    local bell = self.inst.replica.follower:GetLeader()
    return bell.components.bell_tracker:CheckInInventory()
end

function UpdateStats(inst, self)
    if self.last_update == nil then
        self.last_update = GetTime()
        self.last_domestication_gain = GetTime()
        return
    end

    local this_update = GetTime()
    local dt = this_update - self.last_update

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
        self.last_domestication_gain = GetTime()
        domestication_delta = TUNING.BEEFALO_DOMESTICATION_GAIN_DOMESTICATION
        if is_riding and self.player.components.skilltreeupdater:HasSkillTag("beefalodomestication") then
            domestication_delta = domestication_delta * TUNING.SKILLS.WATHGRITHR.WATHGRITHRHAT_BEEFALO_DOMESTICATION_MOD
        end
    else
        domestication_delta = math.min(
            (this_update - self.last_domestication_gain)
                / (TUNING.BEEFALO_DOMESTICATION_MAX_LOSS_DAYS * TUNING.TOTAL_DAY_TIME),
            1
        ) * TUNING.BEEFALO_DOMESTICATION_LOSE_DOMESTICATION
    end

    self:SyncDomestication({ delta = domestication_delta * dt })
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
        if self.inst:HasTag("domesticated") then
            return 1
        else
            return 0
        end
    elseif stat == "obedience" then
        if self.inst:HasTag("domesticated") then
            return TUNING.BEEFALO_MIN_DOMESTICATED_OBEDIENCE[self.tendency]
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
    self:SyncStat("obedience", data)
end

function BeefaloTracker:SyncHunger(data)
    self:SyncStat("hunger", data)
end

function BeefaloTracker:SyncDomestication(data)
    self:SyncStat("domesticated", data)
end

function BeefaloTracker:FedBy(player)
    local item = self.last_active_item
    if item:HasTag("edible_roughage") or item:HasTag("edible_veggie") then
        self:SyncHunger({ delta = scrapbook_data[item.prefab].hungervalue })
        self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_FEED_OBEDIENCE })
    end
    if player.replica.rider:IsRiding() then
        self.start_ride = GetTime()
    end
end

function BeefaloTracker:OnPerformedSuccessDirty(player)
    print("BCS: buffered action: " .. tostring(player.bufferedaction))
    player:DoTaskInTime(0, function(_)
        local beefalo = self.inst

        -- Feeding
        -- this seems like exclusive to feeding beefalo, and for idle it's graze_loop2
        -- also can be checked on player for riding version, but i think is_riding is good enough?
        local is_fed = beefalo.AnimState:IsCurrentAnimation("graze_loop")
        if is_fed then
            print("Fed with " .. tostring(self.last_active_item))
            self:FedBy(player)
        end

        -- Brushing
        -- doesn't make sense when riding
        if self.last_active_item.prefab == "bursh" then
            if beefalo.AnimState:IsCurrentAnimation("brush") then
                print("BCS: Brushed beefalo, he likes it!")
                self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_BRUSHED_OBEDIENCE })
                self:SyncDomestication({ delta = TUNING.BEEFALO_DOMESTICATION_BRUSHED_DOMESTICATION })
            elseif beefalo.AnimState:IsCurrentAnimation("shake") then
                print("BCS: Brushed beefalo, but it was for naught!")
            end
        end

        -- Beefalo refusing riding? For now let's assume player doesn't ride it when it's in mood
        if beefalo.AnimState:IsCurrentAnimation("mating_taunt1") and not beefalo:HasTag("scarytoprey") then
            print("BCS: beefalo refused riding")
            self:SyncObedience({ highest = 0.49 })
        end
    end)

    -- TODO: check post-animations, probably inst:StartThread and Sleep?
    --
    -- we probably don't want a periodic task that checks animations such as shake_off_saddle and beg_loop, should do another DoTaskInTime with amount of frames till end of animation? Or until not busy? :HasTag("busy") or .sg:HasStateTag("busy")
    -- beg_pre, beg_loop, beg_pst: probably can be used to set hunger below 168.5? Not here.
    -- shake_off_saddle: self-explanitory. can be used to sync our obedience. Not here.
    -- fart: can be used to sync hunger
    -- vomit: can be used to sync hunger, also obedience and domestication
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

    return math.max(time * mult - (GetTime() - self.start_ride), 0)
end

function BeefaloTracker:OnIsRidingDirty(player)
    player:DoTaskInTime(0, function(_)
        if player.replica.rider:IsRiding() then
            self.start_ride = GetTime()
        else
            if AnimationIn({ "buck", "bucked", "buck_pst" }) then
                if self.inst:HasTag("domesticated") then
                    return
                end

                local end_ride = GetTime()
                local mult = self:GetRideMult()
                local ride_time = (end_ride - self.start_ride) / mult
                -- / by wigfrid skill and other mults?
                local calculated_domestication =
                    Remap(ride_time, TUNING.BEEFALO_MIN_BUCK_TIME, TUNING.BEEFALO_MAX_BUCK_TIME, 0, 1)
                if math.abs(self.domestication - calculated_domestication) > PERMISSIBLE_DOMESTICATION_ERROR then
                    self:SyncDomestication({ set = calculated_domestication })
                end
            end
            self.start_ride = nil
        end
    end)
end

function BeefaloTracker:OnAttacked(player, data)
    if player.replica.rider:IsRiding() and data.redirected then
        self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_ATTACKED_OBEDIENCE })
    end
end

function BeefaloTracker:OnNewActiveItem(_, data)
    if data.item ~= nil then
        self.last_active_item = data.item
        print("BCS: active item " .. tostring(data.item))
    end
end

function BeefaloTracker:HookPlayer(player)
    self.player = player

    -- I could've made this more clean, but eh
    self.isridingdirty_fn = function(_)
        self:OnIsRidingDirty(player)
    end
    player:ListenForEvent("isridingdirty", self.isridingdirty_fn)

    self.attacked_fn = function(_, data)
        self:OnAttacked(player, data)
    end
    player:ListenForEvent("attacked", self.attacked_fn) -- if data.redirected == true, obedience -0.01

    self.newactiveitem_fn = function(_, data)
        self:OnNewActiveItem(player, data)
    end
    player:ListenForEvent("newactiveitem", self.newactiveitem_fn) -- feed, brush

    self.isperformactionsuccessdirty_fn = function(_)
        self:OnPerformedSuccessDirty(player)
    end
    player.classified:ListenForEvent("isperformactionsuccessdirty", self.isperformactionsuccessdirty_fn)

    self:StartTask()

    -- idea: dropitem: if dropped check if withing radius of salt lick, but syncing this is probably too hard
    -- I mean, we put bell near salt lick, check if we should pause domestication on next tick, then another
    -- player transports a bell to us on our beefalo, sooo how much domestication do we have?
    -- We should probably check for a lick on both drop and pickup?
end

function BeefaloTracker:UnHookPlayer(player)
    self.player = nil

    if self.isridingdirty_fn ~= nil then
        player:RemoveEventCallback("isridingdirty", self.isridingdirty_fn)
    end

    if self.attacked_fn ~= nil then
        player:RemoveEventCallback("attacked", self.attacked_fn)
    end

    if self.newactiveitem_fn ~= nil then
        player:RemoveEventCallback("newactiveitem", self.newactiveitem_fn)
    end

    if self.isperformactionsuccessdirty_fn ~= nil then
        player.classified:RemoveEventCallback("isperformactionsuccessdirty", self.isperformactionsuccessdirty_fn)
    end

    self:CancelTask()
end

return BeefaloTracker
