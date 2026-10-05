-- Local player's normal attention profiles are saved and restored across toggles.
if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local A = HeistAssist
if not PlayerMovement or A.stealth_wrapped then return end
if type(PlayerMovement.set_attention_settings) ~= "function" or type(PlayerMovement.update) ~= "function" then
    log("[HeistAssist] Stealth attention hooks unavailable")
    return
end
A.stealth_wrapped = true
local original_attention = PlayerMovement.set_attention_settings
local original_update = PlayerMovement.update
local function local_player(self)
    return managers.player and self._unit == managers.player:player_unit()
end
local function active(self)
    return A.config.undetectable == true and Network and Network:is_server() and local_player(self)
end
function PlayerMovement:set_attention_settings(settings)
    if type(settings) == "table" then self._brandons_normal_attention = clone(settings) end
    local hide = active(self)
    self._brandons_attention_hidden = hide
    return original_attention(self, hide and {} or settings)
end
function PlayerMovement:update(...)
    if local_player(self) and self._attention_handler then
        local hide = active(self)
        if hide ~= (self._brandons_attention_hidden == true) then
            if hide and not self._brandons_normal_attention then
                local profiles = {}
                if self._attention_handler.attention_data then
                    for _, setting in pairs(self._attention_handler:attention_data() or {}) do
                        if type(setting) == "table" and type(setting.id) == "string" then profiles[#profiles + 1] = setting.id end
                    end
                end
                self._brandons_normal_attention = profiles
            end
            original_attention(self, hide and {} or self._brandons_normal_attention or {})
            self._brandons_attention_hidden = hide
        end
    end
    return original_update(self, ...)
end
log("[HeistAssist] Installed reversible solo/host player attention toggle")
