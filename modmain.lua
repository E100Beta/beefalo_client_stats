local BeefaloStatusDisplays = require("widgets/beefalo_status_displays")

local LINKED_BELL_TAGS = { "bell", "nobundling" }

GLOBAL.GetServerTime = function()
    return (GLOBAL.TheWorld.state.cycles + GLOBAL.TheWorld.state.time) * GLOBAL.TUNING.TOTAL_DAY_TIME
end

CONFIG = {
    ui_show = GetModConfigData("UI_SHOW"),
    animation_tracking = GetModConfigData("ANIMATION_TRACKING"),
    track_domesticated = GetModConfigData("TRACK_DOMESTICATED"),
    x = GetModConfigData("X"),
    y = GetModConfigData("Y"),
    scale = GetModConfigData("SCALE"),
}

-- All logic is inside a component, that's more or less a reimplementation of
-- components/domesticatable with some guesswork on top
local function OnItemGet(player, data)
    if data ~= nil and data.item ~= nil then
        local item = data.item
        if item:HasTags(LINKED_BELL_TAGS) then
            local beefalo
            if data.target ~= nil then
                beefalo = data.target
            else
                local x, y, z = player.Transform:GetWorldPosition()
                for _, beef in ipairs(TheSim:FindEntities(x, y, z, 60, { "beefalo" })) do
                    local bell = beef.replica.follower:GetLeader()
                    if item == bell then
                        beefalo = beef
                        break
                    end
                end
            end
            if beefalo.components.beefalo_tracker.player ~= player then
                -- Unhooking is done inside the component because we don't have full context from outside
                beefalo.components.beefalo_tracker:HookPlayer(player)
            end
        end
    end
end

local function TrackBellBonding(player_classified)
    -- checking for bonding a beefalo
    local player = player_classified._parent
    local last_action = player.components.playercontroller.lastheldaction
    if
        last_action ~= nil
        and last_action.action == GLOBAL.ACTIONS.USEITEMON
        and (last_action.invobject ~= nil and last_action.invobject:HasTag("bell") and not last_action.invobject:HasTag(
            "nobundling"
        ))
        and (last_action.target ~= nil and last_action.target.prefab == "beefalo")
    then
        local task
        task = player:DoPeriodicTask(1, function(_, item, target)
            if target.replica.writeable.screen == nil then
                if target.replica.follower:GetLeader() == item then
                    print("BCS: bonded beefalo")
                    OnItemGet(player, { item = item, target = target })
                end
                task:Cancel()
            end
        end, 1, last_action.invobject, last_action.target)
    end
end

AddPlayerPostInit(function(player)
    player:ListenForEvent("itemget", OnItemGet)

    player:DoTaskInTime(0, function(inst)
        inst.player_classified:ListenForEvent("isperformactionsuccessdirty", TrackBellBonding)

        local bell = inst.replica.inventory:FindItem(function(v)
            return v:HasTags(LINKED_BELL_TAGS)
        end)
        print("BCS: found bell in inventory: " .. tostring(bell))
        if bell ~= nil then
            OnItemGet(inst, { item = bell })
        end
    end)
end)

AddPrefabPostInit("beefalo", function(beefalo)
    beefalo:AddComponent("beefalo_tracker")
    beefalo.components.beefalo_tracker:SetConfig(CONFIG)
end)

AddClassPostConstruct("widgets/statusdisplays", function(self, owner)
    local position_scale, ui_scale, distance_scale = 1, CONFIG.scale, CONFIG.scale

    -- Combined status
    -- Dunno, I tried
    if GLOBAL.KnownModIndex:IsModEnabled("workshop-376333686") then
        position_scale = 0.88
        ui_scale = ui_scale * 0.85
        distance_scale = distance_scale * 1.02
    end

    self.beefalostatusdisplays = self:AddChild(BeefaloStatusDisplays(owner, ui_scale, distance_scale, self))

    self.beefalostatusdisplays:SetPosition(CONFIG.x * position_scale, CONFIG.y * position_scale, 0)

    self.beefalostatusdisplays:MoveToBack()
    self.beefalostatusdisplays:Hide()
end)