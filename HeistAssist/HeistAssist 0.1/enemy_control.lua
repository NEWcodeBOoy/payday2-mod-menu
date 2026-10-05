if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local A = HeistAssist
A.blocked_enemy_units = A.blocked_enemy_units or {}
local function hosting()
    return Network and Network:is_server()
end
local function hostile(unit)
    if not alive(unit) or not managers.enemy then return false end
    local entry = managers.enemy:all_enemies()[unit:key()]
    local damage = unit:character_damage()
    return entry ~= nil and damage ~= nil and not damage._converted
        and not damage:dead()
end

if CopMovement and not A.enemy_fire_wrapped then
    local original = CopMovement.set_allow_fire
    if type(original) == "function" then
        A.enemy_set_allow_fire_original = original
        CopMovement.set_allow_fire = function(self, state, ...)
            if hosting() and A.config.cops_no_shoot and hostile(self._unit) then
                self._brandons_requested_fire = state
                self._brandons_fire_blocked = true
                A.blocked_enemy_units[self._unit:key()] = self._unit
                return original(self, false, ...)
            end
            return original(self, state, ...)
        end
        A.enemy_fire_wrapped = true
    end
end

if EnemyManager and not A.enemy_manager_wrapped then
    local register = EnemyManager.register_enemy
    local update = EnemyManager.update
    if type(register) ~= "function" or type(update) ~= "function" then return end
    EnemyManager.register_enemy = function(self, unit, ...)
        local result = register(self, unit, ...)
        -- Defer death until registration and the unit's initialization finish.
        if hosting() and A.config.auto_kill_spawns then
            self._brandons_spawn_queue = self._brandons_spawn_queue or {}
            self._brandons_spawn_queue[unit:key()] = unit
        end
        return result
    end
    EnemyManager.update = function(self, t, dt, ...)
        local result = update(self, t, dt, ...)
        if not hosting() then self._brandons_spawn_queue = nil; return result end
        local queue = self._brandons_spawn_queue
        self._brandons_spawn_queue = nil
        if A.config.auto_kill_spawns and queue then
            for _, unit in pairs(queue) do
                if hostile(unit) then
                    local damage = unit:character_damage()
                    if type(damage.damage_mission) == "function" then
                        local ok, err = pcall(damage.damage_mission, damage,
                            {variant = "explosion", damage = damage:health(), attacker_unit = unit})
                        if not ok and not A.spawn_kill_error_logged then
                            log("[HeistAssist] Spawn-kill failed: " .. tostring(err))
                            A.spawn_kill_error_logged = true
                        end
                    end
                end
            end
        end
        if t < (self._brandons_fire_check or 0) then return result end
        self._brandons_fire_check = t + 0.1
        for _, entry in pairs(self:all_enemies()) do
            local unit = entry.unit
            if alive(unit) then
                local movement = unit:movement()
                if movement and type(movement.set_allow_fire) == "function" then
                    if A.config.cops_no_shoot and hostile(unit) then
                        if not movement._brandons_fire_blocked then
                            movement._brandons_requested_fire = movement._allow_fire
                            movement._brandons_fire_blocked = true
                        end
                        A.blocked_enemy_units[unit:key()] = unit
                        if A.enemy_set_allow_fire_original then
                            A.enemy_set_allow_fire_original(movement, false)
                        end
                    elseif movement._brandons_fire_blocked then
                        movement._brandons_fire_blocked = nil
                        local requested = movement._brandons_requested_fire
                        movement._brandons_requested_fire = nil
                        movement:set_allow_fire(requested == true)
                    end
                end
            end
        end
        -- Converted cops may leave all_enemies; release them from our block too.
        for key, unit in pairs(A.blocked_enemy_units) do
            if not alive(unit) then
                A.blocked_enemy_units[key] = nil
            elseif not A.config.cops_no_shoot or not hostile(unit) then
                local movement = unit:movement()
                if movement and movement._brandons_fire_blocked then
                    movement._brandons_fire_blocked = nil
                    local requested = movement._brandons_requested_fire
                    movement._brandons_requested_fire = nil
                    movement:set_allow_fire(requested == true)
                end
                A.blocked_enemy_units[key] = nil
            end
        end
        return result
    end
    A.enemy_manager_wrapped = true
end
