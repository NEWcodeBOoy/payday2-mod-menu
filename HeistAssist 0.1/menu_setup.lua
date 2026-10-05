if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local function bind_default()
    if BLT and BLT.Keybinds then
        local bind = BLT.Keybinds:get_keybind("brandons_new_menu_f5")
        if bind and not bind:HasKey() then
            bind:SetKey("f5")
            log("[HeistAssist] Brandon's New Menu bound to F5")
        end
    end
end
bind_default()
Hooks:Add("MenuManagerInitialize", "BrandonsNewMenuDefaultKey", bind_default)
