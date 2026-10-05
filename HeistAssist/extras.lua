local A = HeistAssist
if not A then dofile(ModPath .. "main.lua"); A = HeistAssist end
local C = A.config
A.extra_wrapped = A.extra_wrapped or {}
local function enabled(key) return C[key] ~= false end
local function server() return Network and Network:is_server() end
local function local_unit(unit)
    return managers.player and unit == managers.player:player_unit()
end
local function wrap(class_name, method, factory)
    local cls = _G[class_name]
    local key = class_name .. ":" .. method
    if cls and type(cls[method]) == "function" and not A.extra_wrapped[key] then
        cls[method] = factory(cls[method])
        A.extra_wrapped[key] = true
        log("[HeistAssist] Installed " .. key)
    end
end
local function constant(cls, method, option, ...)
    local values = {...}
    wrap(cls, method, function(original)
        return function(self, ...)
            if enabled(option) then return unpack(values) end
            return original(self, ...)
        end
    end)
end
local function block(cls, method, option, predicate, result)
    wrap(cls, method, function(original)
        return function(self, ...)
            if enabled(option) and (not predicate or predicate(self, ...)) then return result end
            return original(self, ...)
        end
    end)
end

for _, cls in ipairs({"RaycastWeaponBase", "NewRaycastWeaponBase", "ShotgunBase"}) do
    wrap(cls, "_get_spread", function(original)
        return function(self, ...)
            if enabled("no_spread") and self._setup and local_unit(self._setup.user_unit) then return 0, 0 end
            return original(self, ...)
        end
    end)
    constant(cls, "movement_penalty", "no_movement_penalty", 1)
end
wrap("PlayerMovement", "subtract_stamina", function(original)
    return function(self, ...)
        if enabled("unlimited_stamina") and local_unit(self._unit) then
            self._stamina = self:_max_stamina()
            return
        end
        return original(self, ...)
    end
end)
wrap("PlayerMaskOff", "_start_action_state_standard", function(original)
    return function(self, t, ...)
        if enabled("instant_mask") then return self:_end_action_start_standard() end
        return original(self, t, ...)
    end
end)
block("PlayerDamage", "damage_fall", "no_fall_damage", function(self) return local_unit(self._unit) end, false)
block("PlayerDamage", "damage_tase", "shock_proof", function(self) return local_unit(self._unit) end)
block("PlayerDamage", "on_flashbanged", "flashbang_immunity")
block("PlayerDamage", "on_concussion", "concussion_immunity")
-- Core classes are namespaced in Diesel.
local core = CoreEnvironmentControllerManager
if type(core) == "table" and core.EnvironmentControllerManager then
    A.core_environment_class = core.EnvironmentControllerManager
end
for _, cls in ipairs({"EnvironmentControllerManager", "CoreEnvironmentControllerManager", "HeistAssistCoreEnvironment"}) do
    if cls == "HeistAssistCoreEnvironment" then _G[cls] = A.core_environment_class end
    block(cls, "set_flashbang", "flashbang_immunity")
    block(cls, "set_concussion_grenade", "concussion_immunity")
end
block("PlayerManager", "remove_special", "unlimited_cable_ties", function(_, name) return name == "cable_tie" end)
block("PlayerManager", "remove_equipment", "unlimited_equipment")
constant("PlayerManager", "selected_equipment_deploy_timer", "instant_deployment", 0.01)
-- A tiny nonzero timer preserves start/completion callbacks for pagers and scripted interactions.
constant("BaseInteractionExt", "_get_timer", "instant_interactions", 0.01)
constant("PlayerStandard", "_get_swap_speed_multiplier", "instant_weapon_swap", 100)
for _, cls in ipairs({"PlayerStandard", "PlayerCarry"}) do
    wrap(cls, "_get_max_walk_speed", function(original)
        return function(self, t, force_run, ...)
            local depth = A.speed_depth or 0
            A.speed_depth = depth + 1
            local speed = original(self, t, force_run, ...)
            A.speed_depth = depth
            if enabled("no_movement_penalty") and not self:on_ladder() then
                local speeds = self._tweak_data.movement.speed
                local minimum = (self._running or force_run) and speeds.RUNNING_MAX or speeds.STANDARD_MAX
                speed = math.max(speed, minimum)
            end
            return depth == 0 and speed * (tonumber(C.speed_multiplier) or 1) or speed
        end
    end)
end

-- Preserve normal pager handling; reset only the bluff count used for its limit.
wrap("CopBrain", "on_alarm_pager_interaction", function(original)
    return function(self, status, player, ...)
        if enabled("unlimited_pagers") and server() and status == "complete" then
            local state = managers.groupai:state()
            local getter = state.get_nr_successful_alarm_pager_bluffs
            if type(getter) == "function" then
                state.get_nr_successful_alarm_pager_bluffs = function() return 0 end
                local function finish(ok, ...)
                    state.get_nr_successful_alarm_pager_bluffs = getter
                    if not ok then error((...), 0) end
                    return ...
                end
                return finish(pcall(original, self, status, player, ...))
            end
        end
        return original(self, status, player, ...)
    end
end)
for _, cls in ipairs({"Drill", "TimerGui"}) do
    for _, method in ipairs({"set_jammed", "_set_jammed"}) do
        wrap(cls, method, function(original)
            return function(self, jammed, ...)
                if enabled("no_drill_jamming") and server() then jammed = false end
                return original(self, jammed, ...)
            end
        end)
    end
end

-- Player-owned sentries only; enemy turrets have no player owner.
local function owned_sentry(self)
    if not server() or not alive(self._unit) then return false end
    local base = self._unit:base()
    local owner = base and base.get_owner_id and base:get_owner_id()
    local session = managers.network and managers.network:session()
    local peer = session and session:local_peer()
    return owner ~= nil and peer ~= nil and owner == peer:id()
end
wrap("SentryGunWeapon", "change_ammo", function(original)
    return function(self, amount, ...)
        if enabled("unlimited_sentry_ammo") and owned_sentry(self) and amount < 0 then amount = 0 end
        return original(self, amount, ...)
    end
end)
for _, method in ipairs({"damage_bullet", "damage_fire", "damage_explosion", "damage_melee"}) do
    block("SentryGunDamage", method, "unlimited_sentry_health", owned_sentry)
end
for _, method in ipairs({"damage_bullet", "damage_melee", "damage_explosion", "damage_fire"}) do
    wrap("CopDamage", method, function(original)
        return function(self, attack, ...)
            local multiplier = math.max(1, math.min(20, tonumber(C.damage_multiplier) or 1))
            local boosted_bullet = method == "damage_bullet" and server() and multiplier > 1
            if (enabled("one_hit_kills") or boosted_bullet) and type(attack) == "table" and local_unit(attack.attacker_unit) then
                local data = {}
                for key, value in pairs(attack) do data[key] = value end
                if enabled("one_hit_kills") then
                    data.damage = math.max(tonumber(data.damage) or 0, (self._HEALTH_INIT or self._health or 1000) * 1000)
                else
                    data.damage = (tonumber(data.damage) or 0) * multiplier
                end
                return original(self, data, ...)
            end
            return original(self, attack, ...)
        end
    end)
end
