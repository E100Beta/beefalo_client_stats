local function OnItemGet(inst, data)
    if data ~= nil and data.item ~= nil then
        local item = data.item
        if item:HasTag("bell") and item:HasTag("nobundling") then
            item.components.bell_tracker:SetInInventory(true)
            local beefalo = item.components.bell_tracker:GetBeefalo()
            if beefalo ~= nil then
                beefalo.components.beefalo_tracker:HookPlayer(inst)
            end
        end
    end
end

local function OnItemDrop(inst, data)
    if data ~= nil and data.item ~= nil then
        local item = data.item
        if item:HasTag("bell") and item:HasTag("nobundling") then
            item.components.bell_tracker:SetInInventory(false)
            local beefalo = item.components.bell_tracker:GetBeefalo()
            if beefalo ~= nil then
                beefalo.components.beefalo_tracker:UnHookPlayer(inst)
            end
        end
    end
end

AddPlayerPostInit(function(player)
    player:ListenForEvent("itemget", OnItemGet)
    player:ListenForEvent("dropitem", OnItemDrop)
    player:ListenForEvent("isridingdirty", OnIsRidingDirty) -- show/hide ui

    local bell = player.replica.inventory:FindItem(function(v)
        v:HasTag("bell")
    end)
    if bell ~= nil then
        bell.components.bell_tracker:SetInInventory(true)
    end
end)

AddPrefabPostInit("beefalo", function(beefalo)
    beefalo:AddComponent("beefalo_tracker")
    beefalo:DoTaskInTime(0, function(_)
        beefalo.components.beefalo_tracker:SetBondedBell()
    end)
end)

AddPrefabPostInit("beef_bell", function(bell)
    bell:AddComponent("bell_tracker")
end)

AddPrefabPostInit("shadow_beef_bell", function(bell)
    bell:AddComponent("bell_tracker")
end)
