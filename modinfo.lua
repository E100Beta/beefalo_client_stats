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
version = "0.1.2"
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
    local i = 0
    for j = from, to, step do
        t[i] = { data = j, description = j, hover = description }
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
        options = coordinates(-300, 100, 10, "Relative to player stats HUD"),
    },
    {
        name = "Y",
        default = -190,
        options = coordinates(-300, 100, 10, "Relative to player stats HUD"),
    },
    {
        name = "SCALE",
        label = "UI Scale",
        default = 1.0,
        options = {
            { data = 0.1, description = "0.1" },
            { data = 0.2, description = "0.2" },
            { data = 0.3, description = "0.3" },
            { data = 0.4, description = "0.4" },
            { data = 0.5, description = "0.5" },
            { data = 0.6, description = "0.6" },
            { data = 0.7, description = "0.7" },
            { data = 0.8, description = "0.8" },
            { data = 0.9, description = "0.9" },
            { data = 1.0, description = "1.0" },
            { data = 1.1, description = "1.1" },
            { data = 1.2, description = "1.2" },
            { data = 1.3, description = "1.3" },
            { data = 1.4, description = "1.4" },
            { data = 1.5, description = "1.5" },
            { data = 1.6, description = "1.6" },
            { data = 1.7, description = "1.7" },
            { data = 1.8, description = "1.8" },
            { data = 1.9, description = "1.9" },
            { data = 2.0, description = "2.0" },
        },
    },
}
