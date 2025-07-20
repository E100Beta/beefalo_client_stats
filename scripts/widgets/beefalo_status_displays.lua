local Widget = require("widgets/widget")
local BeefaloBadge = require("widgets/beefalo_badge")

-- GetInventoryItemAtlas

-- starting from constants.WEBCOLOURS.PERU and tuning
local BADGE_COLORS = {
    BROWN = { 140 / 255, 80 / 255, 0 / 255, 1 },
    YELLOW = { 140 / 255, 120 / 255, 0 / 255, 1 },
    GREEN = { 0 / 255, 115 / 255, 0 / 255, 1 },
    BLUE = { 40 / 255, 40 / 255, 90 / 255, 1 },
}

local function RideSetPercent(self, val, max, bonus)
    self:OldSetPercent(val / max, max, bonus)
    local minutes = math.floor(val / 60)
    local seconds = math.ceil(val % 60)
    if val < 0 then
        self.num:SetString("--:--")
    elseif minutes == 0 then
        self.num:SetString(string.format("%d", seconds))
    else
        self.num:SetString(string.format("%d:%02d", minutes, seconds))
    end
end
local function UpdateTimer(_, self)
    -- Sometimes task doesn't cancel in time
    if self.timer.val == nil or self.timer.max == nil then
        self.timer:SetPercent(0, 1)
        return
    end
    self.timer.val = self.timer.val - 1
    self.timer:SetPercent(self.timer.val, self.timer.max)
end

local BeefaloStatusDisplays = Class(Widget, function(self, owner, ui_scale, distance_scale, parent)
    Widget._ctor(self, "BeefaloStatus")
    self:UpdateWhilePaused(false)
    self.owner = owner
    self.parent = parent

    -- When I google domestication, google likes giving me farm animals on green pastures
    self.domestication =
        self:AddChild(BeefaloBadge(nil, self.owner, BADGE_COLORS.GREEN, nil, nil, true, true, nil, nil, ui_scale))
    self.domestication:SetPosition(self.parent.column3 * distance_scale, 20 * distance_scale, 0)
    self.domestication.icon:SetTexture(GetInventoryItemAtlas("brush.tex"), "brush.tex")
    self.owner:ListenForEvent("bcs_domesticationdelta", function(_, data, widget)
        widget:SetPercent(data.new, 100)
    end, self.domestication)
    self.on_domestication_change_fn = function(self, data)
        if data.new == 1 then
            self.domestication:Hide()
        else
            self.domestication:Show()
        end
        self.domestication:SetPercent(data.new, 100)
        self.domestication.num:SetString(string.format("%.1f", data.new * 100))
    end

    -- Yellow is already a color of hunger, this one is just tinted to be in line with other colors
    self.hunger =
        self:AddChild(BeefaloBadge(nil, self.owner, BADGE_COLORS.YELLOW, nil, nil, true, true, nil, nil, ui_scale))
    self.hunger:SetPosition(self.parent.column2 * distance_scale, -40 * distance_scale, 0)
    self.hunger.icon:SetTexture(GetInventoryItemAtlas("beefalofeed.tex"), "beefalofeed.tex")
    self.hunger.icon:SetScale(0.8)
    self.on_hunger_change_fn = function(self, data)
        self.hunger:SetPercent(data.new / TUNING.BEEFALO_HUNGER, TUNING.BEEFALO_HUNGER)
    end

    -- If you google obedience, you may find a LOT of images with brown backgrounds, for some reason
    -- BTW why do all other mods put whip here? Nothing in the game requires us to whip a beefalo
    self.obedience =
        self:AddChild(BeefaloBadge(nil, self.owner, BADGE_COLORS.BROWN, nil, nil, true, true, nil, nil, ui_scale))
    self.obedience:SetPosition(self.parent.column4 * distance_scale, -40 * distance_scale, 0)
    self.obedience.icon:SetTexture(GetInventoryItemAtlas("beef_bell.tex"), "beef_bell.tex")
    self.owner:ListenForEvent("bcs_obediencedelta", function(_, data, widget)
        widget:SetPercent(data.new, 100)
    end, self.obedience)
    self.on_obedience_change_fn = function(self, data)
        self.obedience:SetPercent(data.new, 100)
    end

    -- riding => speed => sonic => blue
    self.timer =
        self:AddChild(BeefaloBadge(nil, self.owner, BADGE_COLORS.BLUE, nil, true, true, true, nil, true, ui_scale))
    self.timer:SetPosition(self.parent.column1 * distance_scale, 20 * distance_scale, 0)
    self.timer.icon:SetTexture(GetInventoryItemAtlas("saddle_basic.tex"), "saddle_basic.tex")
    self.timer.num:SetScale(0.9)
    -- A bit of hacking to make a pretty display for timer
    -- Should probably just put it into it's own class
    self.timer.OldSetPercent = self.timer.SetPercent
    self.timer.SetPercent = RideSetPercent
    self.timer:Hide()
    self.on_timer_change_fn = function(self, data)
        if data.is_start then
            self.timer.val = data.ridetime
            self.timer.max = data.ridetime
            self.timer:SetPercent(data.ridetime, data.ridetime)
            if self.timer.timer_task == nil then
                self.timer.timer_task = self.inst:DoPeriodicTask(1, UpdateTimer, 0, self)
            end
            if self.domestication.shown then
                self.timer:SetPosition(self.parent.column1 * distance_scale, 20 * distance_scale, 0)
            else
                self.timer:SetPosition(self.parent.column3 * distance_scale, 20 * distance_scale, 0)
            end
            self.timer:Show()
        else
            self.timer.timer_task:Cancel()
            self.timer.timer_task = nil
            self.timer.val = nil
            self.timer.max = nil
            self.timer:SetPercent(0, 1)
            self.timer:Hide()
        end
    end
end)

return BeefaloStatusDisplays
