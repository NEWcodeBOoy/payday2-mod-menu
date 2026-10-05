-- Optional adapter: Carry Stacker Reloaded owns the bag stack and loot lifecycle.
-- This mod only sets the local host's count limit. It never creates or destroys bags.
if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local A = HeistAssist
local function install()
    local stacker = _G.BLT_CarryStacker
    if not stacker or type(stacker.CanCarry) ~= "function" or not stacker.STATES or
        type(stacker.GetModState) ~= "function" or A.bag_adapter_installed then return end
    local original = stacker.CanCarry
    stacker.CanCarry = function(self, carry_id, ...)
        if Network and Network:is_server() then
            if self:GetModState() ~= self.STATES.ENABLED then return false end
            if not tweak_data.carry[carry_id] or not self.stack then return false end
            if managers.player:carry_blocked_by_cooldown() then return false end
            local limit = math.floor(math.max(1, math.min(20, tonumber(A.config.bag_limit) or 1)))
            return #self.stack < limit
        end
        -- Other hosts retain their own settings / permission checks.
        return original(self, carry_id, ...)
    end
    A.bag_adapter_installed = true
    log("[HeistAssist] Carry Stacker bag-capacity adapter installed")
end
install()
Hooks:Add("GameSetupUpdate", "BrandonsMenuBagAdapter", install)
