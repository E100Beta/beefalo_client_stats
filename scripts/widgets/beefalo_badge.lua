local Badge = require("widgets/badge")
local Image = require("widgets/image")

local BeefaloBadge = Class(
    Badge,
    function(
        self,
        anim,
        owner,
        tint,
        iconbuild,
        circular_meter,
        use_clear_bg,
        dont_update_while_paused,
        bonustint,
        persist_num,
        scale
    )
        Badge._ctor(
            self,
            anim,
            owner,
            tint,
            iconbuild,
            circular_meter,
            use_clear_bg,
            dont_update_while_paused,
            bonustint
        )

        self:SetPercent(0, 100)
        self:SetScale(scale)

        if not iconbuild then
            self.icon = self.underNumber:AddChild(Image())
            self.icon:SetScale(0.7)
        end

        self.persist_num = persist_num
        if self.persist_num then
            self.num:Show()
        end
    end
)

-- We want ride timer to show when riding
function BeefaloBadge:OnGainFocus()
    if not self.persist_num then
        self.num:Show()
    end
end

function BeefaloBadge:OnLoseFocus()
    if not self.persist_num then
        self.num:Hide()
    end
end

return BeefaloBadge
