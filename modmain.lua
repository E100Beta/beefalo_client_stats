local BeefaloStatusDisplays = require("widgets/beefalo_status_displays")

local LINKED_BELL_TAGS = { "bell", "nobundling" }

GLOBAL.GetServerTime = function()
    return (GLOBAL.TheWorld.state.cycles + GLOBAL.TheWorld.state.time) * GLOBAL.TUNING.TOTAL_DAY_TIME
end

CONFIG = {
    ui_show = GetModConfigData("UI_SHOW"),
    animation_tracking = GetModConfigData("ANIMATION_TRACKING"),
}

-- All logic is inside a component that's more or less a reimplementation of
-- components/domesticatable with some guesswork on top
local function OnItemGet(player, data)
    if data ~= nil and data.item ~= nil then
        local item = data.item
        if item:HasTags(LINKED_BELL_TAGS) then
            -- NOTE: need to clearly say in tutorial that player needs beefalo on screen
            --
            -- Also yes, that would be like a 1000 times easier if leader component worked on client. We could reimplement it, but eh
            local x, y, z = player.Transform:GetWorldPosition()
            for _, beefalo in ipairs(TheSim:FindEntities(x, y, z, 60, { "beefalo" })) do
                local bell = beefalo.replica.follower:GetLeader()
                if item == bell and beefalo.components.beefalo_tracker.player ~= player then
                    -- Unhooking is done inside the component because we don't have full context from outside
                    beefalo.components.beefalo_tracker:HookPlayer(player)
                end
            end
        end
    end
end

AddPlayerPostInit(function(player)
    player:ListenForEvent("itemget", OnItemGet)

    -- Manually run at the start
    player:DoTaskInTime(0, function(inst)
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
    self.beefalostatusdisplays = self:AddChild(BeefaloStatusDisplays(owner))

    -- And now to try and fit it all above the Krampus Sack :D
    self.beefalostatusdisplays:SetPosition(0, -180, 0)
    -- Check for Combined Status, it's kinda hard to make widget look good
    -- for both standard and it. Mb move it to the left?
    if GLOBAL.KnownModIndex:IsModEnabled("workshop-376333686") then
        self.beefalostatusdisplays:SetPosition(0, -150, 0)
    end

    self.beefalostatusdisplays:MoveToBack()
    self.beefalostatusdisplays:Hide()
end)
