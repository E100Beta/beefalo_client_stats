local scrapbook_data = require("screens/redux/scrapbookdata")

local BUILDS = {}

local DELTA_TASK_PERIOD = 10

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
    for _, anim in ipairs(animations) do
        if inst.AnimState:IsCurrentAnimation(anim) then
            return true
        end
    end
    return false
end

local function table_tostring(t)
    if type(t) ~= "table" then
        return tostring(t)
    end
    local str = ""
    for k, v in pairs(t) do
        str = str .. tostring(k) .. ": " .. tostring(v) .. ", "
    end
    return str
end

local function make_safe(filename)
    -- exclude some problematic characters for filename serialization
    -- still want to preserve the name itself, mb it's chinese or cyrillic
    local res, _ = string.gsub(filename, "[()%[%]%%\\\"#/:*?!@+={}'~<>|;`^ ]", "_")
    return res
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
    self.config = nil
    self.tasks = {}

    SetBuilds(self.inst)
    self.inst:ListenForEvent("onremove", function()
        self:OnRemoveEntity()
    end)
end)

function BeefaloTracker:OnRemoveEntity()
    if self.player ~= nil then
        self:UnHookPlayer()
    end
end

function BeefaloTracker:GetFileName()
    return "BCS_"
        .. make_safe(TheNet and TheNet:GetServerListing() and TheNet:GetServerListing().name or "NONE")
        .. "_"
        .. (TheNet:GetUserID() or "INVALID_USERID")
        .. "_"
        .. make_safe(self.inst.name)
end

function BeefaloTracker:OnSave()
    if self.inst.name == STRINGS.NAMES.BEEFALO then
        -- 99% doesn't have bell associated if has default name
    elseif
        self.hunger == self:GetLowest("hunger")
        and self.obedience == self:GetLowest("obedience")
        and self.domestication == self:GetLowest("domestication")
    then
        TheSim:ErasePersistentString(self:GetFileName(), function(success)
            print("BCS: beefalo 0 stats, deleting savefile success: " .. tostring(success))
        end)
    else
        local data = {
            hunger = self.hunger,
            obedience = self.obedience,
            domestication = self.domestication,
            last_domestication_gain = self.last_domestication_gain,
            last_update = self.last_update,
        }
        local str = json.encode(data)
        TheSim:SetPersistentString(self:GetFileName(), str, false)
    end
end

function BeefaloTracker:OnLoad()
    TheSim:GetPersistentString(self:GetFileName(), function(success, str)
        if success and str ~= nil then
            local data = json.decode(str)
            self.hunger = data.hunger
            self.obedience = data.obedience
            self.domestication = data.domestication
            self.last_domestication_gain = data.last_domestication_gain
            self.last_update = data.last_update
        end
    end)
end

function BeefaloTracker:SetConfig(config)
    self.config = config
end

function BeefaloTracker:IsCurrentBeefalo()
    if self.player == nil or self.inst == nil or self.inst.replica.follower == nil then
        return false
    end
    local bell = self.inst.replica.follower:GetLeader()
    if bell == nil then
        return false
    end
    return bell.replica.inventoryitem:IsHeldBy(self.player)
end

function BeefaloTracker:GetTendency()
    if #BUILDS == 0 then
        SetBuilds(self.inst)
    end
    return GetTendency(self.inst)
end

function UpdateStats(_, self)
    if not self:IsCurrentBeefalo() then
        self:UnHookPlayer()
        return
    end

    local last_update = self.last_update
    local this_update = GetServerTime()
    local dt = math.max(this_update - last_update, 0) -- server rollbacks
    self.last_update = this_update

    -- OBEDIENCE
    local obedience_loss = TUNING.BEEFALO_DOMESTICATION_STARVE_OBEDIENCE / 2
    if self.hunger == 0 then
        -- starving is x2 + base
        obedience_loss = obedience_loss * 3
    end
    local obedience_delta = obedience_loss * dt
    self:SyncObedience({ delta = obedience_delta })

    -- HUNGER
    local hunger_delta = -TUNING.BEEFALO_HUNGER_RATE * dt
    self:SyncHunger({ delta = hunger_delta })

    -- DOMESTICATION
    local domestication_loss
    local is_riding = self.player.replica.rider:IsRiding()
    if self.hunger > 0 or is_riding then
        self.last_domestication_gain = GetServerTime()
        domestication_loss = TUNING.BEEFALO_DOMESTICATION_GAIN_DOMESTICATION
        if is_riding and self.player.components.skilltreeupdater:HasSkillTag("beefalodomestication") then
            domestication_loss = domestication_loss * TUNING.SKILLS.WATHGRITHR.WATHGRITHRHAT_BEEFALO_DOMESTICATION_MOD
        end
    else
        -- TODO: I'm really not sure if that's right. Doesn't line up with
        -- wiki numbers, maybe I'm missing something?
        domestication_loss = math.min(
            (this_update - self.last_domestication_gain)
                / (TUNING.BEEFALO_DOMESTICATION_MAX_LOSS_DAYS * TUNING.TOTAL_DAY_TIME),
            1
        ) * TUNING.BEEFALO_DOMESTICATION_LOSE_DOMESTICATION
    end
    local domestication_delta = domestication_loss * dt
    self:SyncDomestication({ delta = domestication_delta })

    self:OnSave() -- idk, seems like it doesn't trigger by itself on client
end

function AnimationWatchdog(_, self)
    -- for debug (animations gotten from beefalo stategraph)
    -- stylua: ignore start
    -- local animations = { "alert_pre", "atk_pre", "beg_pre", "bellow", "brush", "carrat_idle1", "carrat_idle_2", "death", "fart", "graze2_pre", "graze2_pst", "graze_loop", "hair_growth", "hair_growth_pre", "idle_loop", "intestinal_cramp", "mating_taunt1", "mating_taunt2", "revive", "run_loop", "run_pre", "run_pst", "shake", "shakesaddle_off", "shave", "skin_change", "transform", "vomit", "walk_loop", "walk_pst", "walk_pre" }
    -- -- stylua: ignore end
    -- for _, v in ipairs(animations) do
    --     if self.inst.AnimState:IsCurrentAnimation(v) then
    --         print("BCS: animation after feeding: " .. v)
    --     end
    -- end
    -- actual logic
    if self.inst.AnimState:IsCurrentAnimation("shakesaddle_off") then
        print("BCS: shook off saddle")
        self:SyncObedience({ highest = TUNING.BEEFALO_KEEP_SADDLE_OBEDIENCE })
    elseif AnimationIn(self.inst, { "beg_pre", "beg", "beg_pst" }) then
        print("BCS: beefalo begged")
        self:SyncHunger({ highest = TUNING.BEEFALO_HUNGER * TUNING.BEEFALO_BEG_HUNGER_PERCENT })
    end
    self.tasks.animation_watcher.period = self:NextAnimTime()
end

function BeefaloTracker:StartTask()
    self.tasks.update = self.inst:DoPeriodicTask(DELTA_TASK_PERIOD, UpdateStats, 0, self)
    if self.config.animation_tracking == "AGGRESSIVE" and not self.inst:HasTag("domesticated") then
        self.tasks.animation_watcher = self.inst:DoPeriodicTask(self:NextAnimTime() or 0, AnimationWatchdog, 0, self)
    end
end

function BeefaloTracker:CancelTask()
    for _, task in pairs(self.tasks) do
        task:Cancel()
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
        if self.inst:HasTag("domesticated") and (self.config ~= nil and not self.config.track_domesticated) then
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
    local final_time = time * mult - (GetServerTime() - self.start_ride)

    return math.max(final_time, 0)
end

function BeefaloTracker:NextAnimTime()
    return self.inst.AnimState:GetCurrentAnimationLength() - self.inst.AnimState:GetCurrentAnimationTime() + FRAMES
end

function BeefaloTracker:CheckAnimationAfterFeed()
    -- Define task locally beacause there are sometimes race conditions,
    -- this ensures the closure captures its task
    local task
    task = self.inst:DoPeriodicTask(self:NextAnimTime(), function(inst, _)
        if self.player == nil then
            -- Sometimes component "loses" its task and it doesn't get cleaned up
            return
        end
        if inst.AnimState:IsCurrentAnimation("graze_loop") then
            -- still eating
            self.tasks.feed_animation.period = self:NextAnimTime()
            return
        elseif inst.AnimState:IsCurrentAnimation("fart") then
            print("BCS: flatulance")
            self:SyncHunger({ lowest = 300 })
        elseif inst.AnimState:IsCurrentAnimation("vomit") then
            print("BCS: regurgitation")
            self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_OVERFEED_OBEDIENCE })
            self:SyncDomestication({ delta = TUNING.BEEFALO_DOMESTICATION_OVERFEED_DOMESTICATION })
        else
            if not self.player.replica.rider:IsRiding() then
                print("BCS: nothing, probably lower hunger")
                self:SyncHunger({ highest = 300 })
            end
        end
        -- It seems like time reset happens after the animation, let's try resetting it here
        if self.player.replica.rider:IsRiding() then
            self:ResetRide({ start = GetServerTime() })
        end
        if task ~= nil then
            task:Cancel()
        end
    end, 0, self)
    self.tasks.feed_animation = task
end

function BeefaloTracker:OnPerformedSuccessDirty(player)
    -- NOTE: sometimes lastheldaction doesn't reset for a long time or disappears too fast
    local last_action = player.components.playercontroller.lastheldaction
    if last_action == nil then
        return
    end
    local action = last_action.action
    local item = last_action.invobject
    local is_success = player.player_classified.isperformactionsuccess:value()

    player:DoTaskInTime(0, function(_)
        if
            (
                (action == ACTIONS.GIVE and last_action.target == self.inst and is_success)
                or (action == ACTIONS.FEED and player.replica.rider:IsRiding())
            ) and item:HasAnyTag("edible_roughage", "edible_veggie")
        then
            print("BCS: fed beefalo")
            self:SyncHunger({ delta = scrapbook_data[item.prefab].hungervalue })
            self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_FEED_OBEDIENCE })
            -- reset ride after animation?
            self:CheckAnimationAfterFeed()
        end

        -- Brushing is almost almost always success because it drains durability
        if action == ACTIONS.BRUSH and self.inst.AnimState:IsCurrentAnimation("brush") then
            print("BCS: brushed beefalo")
            self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_BRUSHED_OBEDIENCE })
            self:SyncDomestication({ delta = TUNING.BEEFALO_DOMESTICATION_BRUSHED_DOMESTICATION })
        end

        -- Also counts as success for some reason
        if action == ACTIONS.MOUNT and self.inst.AnimState:IsCurrentAnimation("mating_taunt1") then
            print("BCS: beefalo refused riding")
            self:SyncObedience({ highest = 0.49 })
        end

        -- Can't be sure it he hit us or not
        if action == ACTIONS.SADDLE and not is_success then
            print("BCS: beefalo refused saddling")
            self:SyncObedience({ highest = TUNING.BEEFALO_SADDLEABLE_OBEDIENCE })
        end

        if
            (action == ACTIONS.DROP and item == self.inst.replica.follower:GetLeader())
            or (action == ACTIONS.GIVE and not self:IsCurrentBeefalo())
        then
            print("BCS: dropped bell")
            self:UnHookPlayer()
        end
    end)
end

function BeefaloTracker:GetDomesticationFromRideTime(dt)
    local domestication_mult = 1
    if self.player.components.skilltreeupdater:HasSkillTag("beefalodomestication") then
        domestication_mult = domestication_mult * TUNING.SKILLS.WATHGRITHR.WATHGRITHRHAT_BEEFALO_DOMESTICATION_MOD
    end
    -- It's unreliable if domestication tick happens after or before, but better be on the lower side
    local domestication_during_ride = TUNING.BEEFALO_DOMESTICATION_GAIN_DOMESTICATION
        * domestication_mult
        * math.max(dt - DELTA_TASK_PERIOD * 2, 0)
    local ride_real = dt / self:GetRideMult()
    local calculated_domestication = Remap(ride_real, TUNING.BEEFALO_MIN_BUCK_TIME, TUNING.BEEFALO_MAX_BUCK_TIME, 0, 1)
    return calculated_domestication + domestication_during_ride
end

function BeefaloTracker:OnIsRidingDirty(player)
    player:DoTaskInTime(0, function(_)
        if player.replica.rider:IsRiding() then
            self:ResetRide({ start = GetServerTime() })
            self:SyncObedience({ lowest = 0.5 })
        else
            if AnimationIn(player, { "buck", "bucked", "buck_pst" }) and self.start_ride ~= nil then
                print("BCS: player bucked")
                if self.inst:HasTag("domesticated") then
                    return
                end

                local end_ride = GetServerTime()
                local dt = end_ride - self.start_ride
                local calculated_domestication = self:GetDomesticationFromRideTime(dt)
                print("BCS: calculated domestication: " .. tostring(calculated_domestication))
                -- allow for some error
                if math.abs(self.domestication - calculated_domestication) > 0.01 then
                    self:SyncDomestication({ set = calculated_domestication })
                end
            end
            self:ResetRide({ finish = GetServerTime() })
        end
    end)
end

function BeefaloTracker:OnAttacked(player, data)
    -- Yeah I also kinda didn't know that you stop losing obedience on attack after
    -- domesticating
    if
        player.replica.rider:IsRiding()
        and data.redirected
        and (not self.inst:HasTag("domesticated") or not self:GetTendency() == "ORNERY")
    then
        self:SyncObedience({ delta = TUNING.BEEFALO_DOMESTICATION_ATTACKED_OBEDIENCE })
    end
end

function BeefaloTracker:OnItemLose(player)
    player:DoTaskInTime(0, function(_)
        -- Must check every instance of this noisy event, since "dropitem" event
        -- is not for client. Data on this event is generally useless too.
        -- Thankfully, IsHeldBy is more than enough for our case.
        local bell = self.inst.replica.follower:GetLeader()
        if
            bell ~= nil
            and (bell.replica.inventoryitem:IsHeldBy(player) or player.replica.inventory:GetActiveItem() == bell)
        then
            return
        end

        print("BCS: dropped bell")
        self:UnHookPlayer()
    end)
end

function BeefaloTracker:HookPlayer(player)
    if self.player ~= nil then
        print("BCS: player already hooked in")
        return
    else
        print("BCS: hooking player in")
    end

    if self.config.ui_show == "NEVER" and self.inst:HasTag("domesticated") then
        print("BCS: domesticated and config to never show ui, skipping hook in")
        return
    elseif self.config.ui_show == "ORNERY" and self.inst:HasTag("domesticated") and self:GetTendency() ~= "ORNERY" then
        print("BCS: domesticated not ornery and config to only show ui for ornery, skipping hook in")
        return
    end

    self.player = player

    -- I could've made this more clean, but eh
    self.isridingdirty_fn = function(_)
        self:OnIsRidingDirty(self.player)
    end
    self.player:ListenForEvent("isridingdirty", self.isridingdirty_fn)

    self.attacked_fn = function(_, data)
        self:OnAttacked(self.player, data)
    end
    self.player:ListenForEvent("attacked", self.attacked_fn)

    self.itemlose_fn = function(_, _)
        self:OnItemLose(self.player)
    end
    self.player:ListenForEvent("itemlose", self.itemlose_fn)

    self.isperformactionsuccessdirty_fn = function(_)
        self:OnPerformedSuccessDirty(self.player)
    end
    self.player.player_classified:ListenForEvent("isperformactionsuccessdirty", self.isperformactionsuccessdirty_fn)

    self.ui = player.HUD.controls.status.beefalostatusdisplays
    self.ui:Show()

    if self.player.replica.rider:IsRiding() then
        self:ResetRide({ start = GetServerTime() })
    end

    self:OnLoad()
    self:StartTask()

    -- idea: dropitem: if dropped check if withing radius of salt lick, but syncing this is probably too hard
    -- I mean, we put bell near salt lick, check if we should pause domestication on next tick, then another
    -- player transports a bell to us on our beefalo, sooo how much domestication do we have?
    -- We should probably check for a lick on both drop and pickup?
end

function BeefaloTracker:UnHookPlayer()
    print("BCS: unhooking player from beefalo")

    if self.isridingdirty_fn ~= nil then
        self.player:RemoveEventCallback("isridingdirty", self.isridingdirty_fn)
        self.isridingdirty_fn = nil
    end

    if self.attacked_fn ~= nil then
        self.player:RemoveEventCallback("attacked", self.attacked_fn)
        self.attacked_fn = nil
    end

    if self.itemlose_fn ~= nil then
        self.player:RemoveEventCallback("itemlose", self.itemlose_fn)
        self.itemlose_fn = nil
    end

    if self.isperformactionsuccessdirty_fn ~= nil then
        if self.player.player_classified ~= nil then
            self.player.player_classified:RemoveEventCallback(
                "isperformactionsuccessdirty",
                self.isperformactionsuccessdirty_fn
            )
        end
        self.isperformactionsuccessdirty_fn = nil
    end

    self:CancelTask()
    self:OnSave()

    if self.ui ~= nil then
        self.ui:Hide()
    end
    self.ui = nil
    self.player = nil
end

return BeefaloTracker
