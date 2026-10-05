HeistAssist = HeistAssist or {}
local A = HeistAssist
if A.config then return end
A.path = ModPath
A.settings_path = SavePath .. "brandons_new_menu.json"
A.config = {
    god_mode = true, unlimited_ammo = true, no_recoil = true,
    no_spread = true, unlimited_stamina = true, instant_mask = true,
    no_fall_damage = true, no_movement_penalty = true, shock_proof = true,
    flashbang_immunity = true, concussion_immunity = true,
    unlimited_cable_ties = true, unlimited_equipment = true,
    instant_deployment = true, instant_interactions = true,
    unlimited_pagers = true, no_drill_jamming = true, one_hit_kills = true,
    instant_weapon_swap = true, unlimited_sentry_ammo = true,
    unlimited_sentry_health = true,
    undetectable = false,
    keep_stealth = false,
    instant_timers = false,
    speed_multiplier = 1,
    damage_multiplier = 1,
    bag_limit = 1
}
A.appearance = {cycle = true, color = 1, hue = 195, saturation = 0.95, brightness = 1, seconds = 30, favorites = {}}
-- Preserve explicitly edited config.lua options, even when dofile discards return values.
local ok, custom = pcall(dofile, A.path .. "config.lua")
if ok and type(custom) == "table" then
    for key, value in pairs(custom) do
        if type(value) == "boolean" and A.config[key] ~= nil then A.config[key] = value end
    end
end
local file = io.open(A.settings_path, "r")
if file then
    local contents = file:read("*all")
    file:close()
    local valid, saved = pcall(json.decode, contents)
    if valid and type(saved) == "table" then
        if type(saved.appearance) == "table" then
            for key,bounds in pairs({hue={0,360},saturation={0,1},brightness={0,1},seconds={5,120}}) do
                local value=saved.appearance[key]
                if type(value)=="number" then A.appearance[key]=math.max(bounds[1],math.min(bounds[2],value)) end
            end
            if type(saved.appearance.favorites)=="table" then
                for _,hex in ipairs(saved.appearance.favorites) do
                    if type(hex)=="string" and hex:match('^%x%x%x%x%x%x$') and #A.appearance.favorites<8 then
                        table.insert(A.appearance.favorites,hex:upper())
                    end
                end
            end
            if type(saved.appearance.cycle) == "boolean" then A.appearance.cycle = saved.appearance.cycle end
            if type(saved.appearance.color) == "number" then A.appearance.color = math.floor(math.max(1,math.min(4,saved.appearance.color))) end
        end
        for key, value in pairs(saved) do
            if type(value) == "boolean" and A.config[key] ~= nil then A.config[key] = value end
        end
        if type(saved.speed_multiplier) == "number" then
            A.config.speed_multiplier = math.max(0.5, math.min(5, saved.speed_multiplier))
        end
        if type(saved.bag_limit) == "number" then
            A.config.bag_limit = math.floor(math.max(1, math.min(20, saved.bag_limit)))
        end
        if type(saved.damage_multiplier) == "number" then
            A.config.damage_multiplier = math.max(1, math.min(20, saved.damage_multiplier))
        end
    else
        log("[HeistAssist] Saved menu settings invalid; using configuration defaults")
    end
end
function A:save_settings()
    local saved = clone(self.config)
    saved.appearance = self.appearance
    local valid, contents = pcall(json.encode, saved)
    if not valid then return false end
    local file = io.open(self.settings_path, "w")
    if not file then
        log("[HeistAssist] Could not save menu settings")
        return false
    end
    local written = file:write(contents)
    file:close()
    return written ~= nil
end
