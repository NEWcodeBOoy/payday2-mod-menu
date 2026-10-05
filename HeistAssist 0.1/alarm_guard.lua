if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local A = HeistAssist
if not GroupAIStateBase then return end
A.alarm_wrapped = A.alarm_wrapped or {}
local function protected(state)
    return A.config.keep_stealth == true and Network and Network:is_server()
        and type(state.whisper_mode) == "function" and state:whisper_mode()
end
-- Cover the ordinary alarm chain and direct escalation without rewinding a heist.
-- Original methods remain active when OFF, on clients, and once already loud.
for _, method in ipairs({"on_police_called", "on_enemy_weapons_hot", "on_player_weapons_hot"}) do
    if type(GroupAIStateBase[method]) == "function" and not A.alarm_wrapped[method] then
        local original = GroupAIStateBase[method]
        GroupAIStateBase[method] = function(self, ...)
            if protected(self) then return end
            return original(self, ...)
        end
        A.alarm_wrapped[method] = true
        log("[HeistAssist] Installed stealth alarm guard: " .. method)
    end
end
