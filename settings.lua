--settings.lua

data:extend({
    {
        type = "int-setting",
        name = "syso-time-to-afk",
        setting_type = "runtime-global",
        default_value = 5,
        minimum_value = 0
    },
    {
        type = "int-setting",
        name = "syso-max-world-afk-time",
        setting_type = "runtime-global",
        default_value = 20,
        minimum_value = 0
    },
    {
        type = "bool-setting",
        name = "syso-can-anyone-unpause",
        setting_type = "runtime-global",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "syso-should-save-on-world-afk",
        setting_type = "runtime-global",
        default_value = true
    }
})