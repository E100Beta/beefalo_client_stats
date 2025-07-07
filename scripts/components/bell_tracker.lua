local BellTracker = Class(function(self, inst)
    self.inst = inst
    self.in_inventory = false
    self.is_linked = self.inst:HasTag("nobundling")

    -- This may fail, but I don't know how to do it for now
    self:IsBondedDirty()
    self.inst:ListenForEvent("isbondeddirty", function(_)
        print("BCS: isbondeddirty ping")
        self:IsBondedDirty()
    end)
end)

function BellTracker:SetBeefalo(beefalo)
    self.beefalo = beefalo
end

function BellTracker:CheckBeefalo(beefalo)
    -- In case we failed to find it
    if self.beefalo ~= beefalo and self.inst == beefalo.replica.follower:GetLeader() then
        self.beefalo = beefalo
    end
end

function BellTracker:GetBeefalo()
    if self.is_linked and self.beefalo ~= nil then
        return self.beefalo
    end
    return nil
end

function BellTracker:FindBeefalo()
    -- Search beefalo in immediate area
    local x, y, z = self.inst.Transform:GetWorldPosition()
    -- 60 seems like a bit over 1.5 screens, unless we're really unlucky we won't need more
    for beefalo in TheSim:FindEntities(x, y, z, 60, { "beefalo" }) do
        local mb_bell = beefalo.replica.follower:GetLeader()
        if self.inst == mb_bell then
            self:SetBeefalo(beefalo)
            return beefalo
        end
    end
    return nil
end

function BellTracker:IsBondedDirty()
    self.is_linked = self.inst:HasTag("nobundling")
    if self.is_linked then
        -- I kinda want to put xpcall here
        self.beefalo = self:FindBeefalo()
    else
        self.beefalo = nil
    end
end

function BellTracker:CheckInInventory(player)
    if self.in_inventory == nil then
        return player.replica.inventory:FindItem(function(v)
            return v == self.inst
        end) ~= nil
    else
        return self.in_inventory
    end
end

function BellTracker:SetInInventory(mb)
    self.in_inventory = mb
end

function BellTracker:IsLinkedBell()
    return self.is_linked
end

return BellTracker
