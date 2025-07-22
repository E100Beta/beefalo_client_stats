---@diagnostic disable: lowercase-global

name = "Beefalo Client Stats"
description = [[
Makes best effort guesses about your beefalo current stats for easier domestication and ornery obedience management.

Use Beefalo Bell to bond a beefalo, and UI should appear (if it doesn't, drop and pick up the bell).
Since simulating stats is not reliable, here are ways to sync them:
- Hunger: let stat in UI drop to 0, or feed your beefalo until it farts (3 Steamed Twigs).
- Obedience: just feed 11 twigs to max it out.
- Domestication: ride the beefalo until it bucks you off.

Tracking stops after completing domestication, unless beefalo is Ornery.
Ornery still needs Obedience management (this was mod's original goal).
]]
author = "E100"
version = "0.1.0"
forumthread = ""
icon_atlas = "icon.xml"
icon = "icon.tex"
client_only_mod = true
all_clients_require_mod = false
dst_compatible = true
dont_starve_compatible = false -- IDK lol
reign_of_giants_compatible = false -- IDK lol
priority = -9223372036854775808 -- IDK lol
api_version = 10

local function coordinates(from, to, step, description)
    local t = {}
    local i = 0 -- table.insert unavailable
    for j = from, to, step do
        local row = { data = j, description = "" .. j }
        if description ~= nil then
            row["hover"] = description
        end
        t[i] = row
        i = i + 1
    end
    return t
end

configuration_options = {
    {
        name = "UI_SHOW",
        label = "Show UI after domestication",
        default = "ORNERY",
        options = {
            {
                data = "NEVER",
                description = "Never",
                hover = "Hide UI after domestication. Effectively disables mod",
            },
            {
                data = "ORNERY",
                description = "Ornery",
                hover = "After domestication, only Ornery will still have UI show",
            },
            {
                data = "ALWAYS",
                description = "Always",
                hover = "Show UI no matter which type of beefalo (for ride time?)",
            },
        },
    },
    {
        name = "TRACK_DOMESTICATED",
        label = "Track domestication after domesticating (experimental)",
        default = false,
        options = {
            {
                data = false,
                description = "No",
            },
            {
                data = true,
                description = "Yes",
            },
        },
    },
    {
        name = "ANIMATION_TRACKING",
        label = "Use Animation for tracking",
        default = "AGGRESSIVE",
        options = {
            {
                data = "NORMAL",
                description = "Normal",
                hover = "Only check for reactions to feeding, like regurgitaning and flatulance",
            },
            {
                data = "AGGRESSIVE",
                description = "Aggressive",
                hover = "Try detecting shaking off saddle and begging for food",
            },
        },
    },
    {
        name = "X",
        default = 0,
        options = coordinates(-200, 200, 10, "Relative to player stats HUD"),
    },
    {
        name = "Y",
        default = -170,
        options = coordinates(-200, 200, 10, "Relative to player stats HUD"),
    },
    {
        name = "SCALE",
        label = "UI Scale",
        default = 1,
        options = coordinates(0.1, 2, 0.1),
    },
}
