-- every thing I need for this
-- BEEFALO_HUNGER = (calories_per_day * 4) / 0.8 -- so a 0.8 fullness lasts a day
-- BEEFALO_HUNGER_RATE = (calories_per_day * 4) / total_day_time
-- BEEFALO_SADDLEABLE_OBEDIENCE = 0.1
-- BEEFALO_KEEP_SADDLE_OBEDIENCE = 0.4
-- BEEFALO_MIN_BUCK_OBEDIENCE = 0.5
-- BEEFALO_MIN_BUCK_TIME = 50
-- BEEFALO_MAX_BUCK_TIME = 800
-- BEEFALO_BUCK_TIME_VARIANCE = 3
-- BEEFALO_MIN_DOMESTICATED_OBEDIENCE = {
--     DEFAULT = 0.8,
--     ORNERY = 0.45,
--     RIDER = 0.95,
--     PUDGY = 0.6,
-- }
-- BEEFALO_BUCK_TIME_MOOD_MULT = 0.2
-- BEEFALO_BUCK_TIME_UNDOMESTICATED_MULT = 0.3
-- BEEFALO_BUCK_TIME_NUDE_MULT = 0.2
--
-- BEEFALO_BEG_HUNGER_PERCENT = 0.45
--
-- BEEFALO_DOMESTICATION_STARVE_OBEDIENCE = -1 / (total_day_time * 1)
-- BEEFALO_DOMESTICATION_FEED_OBEDIENCE = 0.1
-- BEEFALO_DOMESTICATION_OVERFEED_OBEDIENCE = -0.3
-- BEEFALO_DOMESTICATION_ATTACKED_BY_PLAYER_OBEDIENCE = -1
-- BEEFALO_DOMESTICATION_BRUSHED_OBEDIENCE = 0.4
-- BEEFALO_DOMESTICATION_SHAVED_OBEDIENCE = -1
--
-- BEEFALO_DOMESTICATION_LOSE_DOMESTICATION = -1 / (total_day_time * 4)
-- BEEFALO_DOMESTICATION_GAIN_DOMESTICATION = 1 / (total_day_time * 20)
-- BEEFALO_DOMESTICATION_MAX_LOSS_DAYS = 10 -- days
-- BEEFALO_DOMESTICATION_OVERFEED_DOMESTICATION = -0.01
-- BEEFALO_DOMESTICATION_ATTACKED_DOMESTICATION = 0
-- BEEFALO_DOMESTICATION_ATTACKED_OBEDIENCE = -0.01
-- BEEFALO_DOMESTICATION_ATTACKED_BY_PLAYER_DOMESTICATION = -0.3
-- BEEFALO_DOMESTICATION_BRUSHED_DOMESTICATION = (1 - (15 / 20)) / 15 -- (1-(targetdays/basedays))/targetdays
--
-- BEEFALO_PUDGY_WELLFED = 1 / (total_day_time * 5)
-- BEEFALO_PUDGY_OVERFEED = 0.02
-- BEEFALO_RIDER_RIDDEN = 1 / (total_day_time * 5)
-- BEEFALO_ORNERY_DOATTACK = 0.004
-- BEEFALO_ORNERY_ATTACKED = 0.004

Tracker = {
    beefalo = nil,
    name = nil,
    stats = {
        hunger = 0,
        obedience = 0,
        domestication = 0,
    },
    last_active_item = nil,
    domesticated = nil,
    tendency = nil,
    heuristics = {
        begged_since_last_delta = nil,
        is_riding = nil,
        current_held_item = nil,
    },
}

BUILDS = {}

-- this is a very funny way to find out what's our tendency is
-- basically we try to find ids of animation builds of beefalo faces
-- took me 2 weeks to figure this out smh
function SetBuilds(beefalo)
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

function GetTendency(beefalo)
    local build, _ = beefalo.AnimState:GetSymbolOverride("beefalo_mouthmouth")
    return BUILDS[build]
end

-- Dunno if it's actually best way, should be enough to just IsCurrentAnimation
function GetCurrentAnimation(inst)
    return string.match(inst.entity:GetDebugString(), "anim: ([^ ]+) ")
end

function AnimationIn(inst, animations)
    for anim in animations do
        if inst.AnimState:IsCurrentAnimation(anim) then
            return true
        end
    end
    return false
end

local function IsLinkedBell(item)
    return item:HasTag("bell") and item:HasTag("nobundling")
end

local function FindLinkedBeefalo(bell)
    if not IsLinkedBell(bell) then
        return
    end

    local x, y, z = GLOBAL.ThePlayer.Transform:GetWorldPosition()
    -- 60 seems like a bit over 1.5 screens, unless we're really unlucky we won't need more
    local beefalos = GLOBAL.TheSim:FindEntities(x, y, z, 60, { "beefalo" })
    for beefalo in beefalos do
        local mb_bell = beefalo.replica.follower:GetLeader()
        if bell == mb_bell then
            return beefalo
        end
    end
    return nil
end

local function OnPerformedSuccessDirty(inst)
    inst:DoTaskInTime(0, function(inst)
        local player = inst._parent
        -- is this even a thing?
        if player ~= GLOBAL.ThePlayer then
            return
        end
        local is_riding = player.replica.rider:IsRiding()
        local beefalo = player.tracker.beefalo

        -- Feeding
        -- this seems like exclusive to feeding beefalo, and for idle it's graze_loop2
        -- also can be checked on player for riding version, but i think is_riding is good enough?
        is_fed = beefalo.AnimState:IsCurrentAnimation("graze_loop")
        if is_fed then
            print("Fed with " .. tostring(player.tracker.last_active_item))
            Feed(beefalo, player.tracker.last_active_item, { riding = is_riding })
        end

        -- Brushing
        -- doesn't make sense when riding
        if player.tracker.last_active_item.prefab == "bursh" then
            if beefalo.AnimState:IsCurrentAnimation("brush") then
                print("BCS: Brushed beefalo, he likes it!")
            elseif beefalo.AnimState:IsCurrentAnimation("shake") then
                print("BCS: Brushed beefalo, but it was for naught!")
            end
        end

        -- Beefalo refusing riding?
        if beefalo.AnimState:IsCurrentAnimation("mating_taunt1") and not beefalo:HasTag("scarytoprey") then
            SyncObedience(beefalo, { highest = 49 })
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

local function OnIsRidingDirty(player)
    player:DoTaskInTime(0, function(_)
        if player.replica.rider:IsRiding() then
            player.tracker.start_ride = GLOBAL.GetTime()
        elseif AnimationIn({ "buck", "bucked", "buck_pst" }) then
            local end_time = GLOBAL.GetTime()
            local calculated_domestication = (end_time - player.tracker.start_ride - 15) / 225
        end
    end)
end

local function OnItemGet(inst, ...)
    -- IsBeefaloBell(inst, data)
end

local function OnAttacked(inst, ...) end
local function OnHungerDelta(inst, ...) end
local function OnItemLose(inst, ...) end
local function OnNewActiveItem(inst, ...) end

AddPlayerPostInit(function(inst)
    -- init tracker for player
    -- probably also listen on some save/load?

    -- Finding linked beefalo - probably will be done on init?
    -- LinkedBell()
    -- inst:ListenForEvent("itemget", OnItemGet) -- data.item, data.slot

    -- yes
    inst:ListenForEvent("isridingdirty", OnIsRidingDirty) -- mounted, dismount
    inst:ListenForEvent("attacked", OnAttacked) -- if data.redirected == true, obedience -0.01
    inst:ListenForEvent("hungerdelta", OnHungerDelta) -- my idea is if delta is negative then we subtract hunger, but this felt unreliable (what if nonstandard hunger drain?), i think we should just init a couple periodic tasks, one for domestication and one for hunger and obedience
    inst:ListenForEvent("newactiveitem", OnNewActiveItem) -- feed, brush
    inst:ListenForEvent("itemlose", OnItemLose) -- actually feels kinda useless, either use itemdrop instead or rescan inventory for if we have a bell for each event?

    -- no
    -- itemget, itemlose, newactiveitem, stacksizechange, itemchange
    -- onhitother, blocked, doattack, onattackother, onmissother, onareaattackother
end)

AddPrefabPostInit("player_classified", function(classified)
    -- yes
    -- hungerdelta is before this action, so we can see if we eaten something to remove possibility that we fed the beefalo
    classified:ListenForEvent("isperformactionsuccessdirty", OnPerformedSuccessDirty) -- I think i'll use it with newactiveitem to check what happened. also checking if beefalo ornery
    -- stackitemdirty

    -- no
end)

AddPrefabPostInit("beefalo", function(beefalo)
    -- probably put it in hunger delta event?
    -- animstatedirty? animover? animdatadirty?
    beefalo:DoTaskInTime(0, SetBuilds)
    beefalo:DoTaskInTime(0, function(inst)
        local bell = inst.replica.follower:GetLeader()
        local inventoryBell = GLOBAL.ThePlayer.replica.inventory:FindItem(function(v)
            if v == bell then
                return v
            end
        end)
    end)
end)
