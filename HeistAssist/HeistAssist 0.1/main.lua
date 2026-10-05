HeistAssist = HeistAssist or {}
local mod = HeistAssist
if not mod.config then
    dofile(ModPath .. "settings.lua")
end

-- Only intercept the local player's damage extension.
log("[HeistAssist] Hook: " .. tostring(RequiredScript))
if PlayerDamage then
    mod.damage_wrapped = mod.damage_wrapped or {}
    for _, name in ipairs({"damage_bullet", "damage_explosion", "damage_fire",
        "damage_melee", "damage_fall", "damage_killzone", "damage_tase"}) do
        if type(PlayerDamage[name]) == "function" and not mod.damage_wrapped[name] then
            local original = PlayerDamage[name]
            local method = name
            PlayerDamage[method] = function(self, ...)
                if mod.config.god_mode and managers.player and
                    self._unit == managers.player:player_unit() then
                    if method == "damage_fall" then return false end
                    return
                end
                return original(self, ...)
            end
            mod.damage_wrapped[method] = true
            log("[HeistAssist] Installed damage protection: " .. method)
        end
    end
end

if RaycastWeaponBase and
    not mod.ammo_wrapped then
    mod.ammo_wrapped = true
    log("[HeistAssist] Installed ammo hook")
    local original = RaycastWeaponBase.fire
    RaycastWeaponBase.fire = function(self, ...)
        local local_weapon = mod.config.unlimited_ammo and self._setup and
            managers.player and self._setup.user_unit == managers.player:player_unit()
        local ammo
        if local_weapon and self.ammo_base then
            ammo = self:ammo_base()
            if ammo and ammo.get_ammo_max_per_clip and ammo.get_ammo_max and
                ammo.set_ammo_remaining_in_clip and ammo.set_ammo_total then
                ammo:set_ammo_total(ammo:get_ammo_max())
                ammo:set_ammo_remaining_in_clip(ammo:get_ammo_max_per_clip())
            else
                ammo = nil
            end
        end
        -- Preserve all return values, including trailing nils.
        local function finish(...)
            if ammo then
                ammo:set_ammo_total(ammo:get_ammo_max())
                ammo:set_ammo_remaining_in_clip(ammo:get_ammo_max_per_clip())
            end
            return ...
        end
        return finish(original(self, ...))
    end
end

if FPCameraPlayerBase and
    type(FPCameraPlayerBase.recoil_kick) == "function" and not mod.recoil_wrapped then
    mod.recoil_wrapped = true
    log("[HeistAssist] Installed recoil hook")
    local original = FPCameraPlayerBase.recoil_kick
    FPCameraPlayerBase.recoil_kick = function(self, ...)
        if mod.config.no_recoil then return end
        return original(self, ...)
    end
end
