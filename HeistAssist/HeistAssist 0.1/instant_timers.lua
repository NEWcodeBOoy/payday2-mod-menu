if not HeistAssist or not HeistAssist.config then dofile(ModPath .. "settings.lua") end
local A = HeistAssist
A.timer_wrapped = A.timer_wrapped or {}
local function active()
    return A.config.instant_timers == true and Network and Network:is_server()
end
if TimerGui and not A.timer_wrapped.TimerGui and type(TimerGui.update) == "function" then
    local original = TimerGui.update
    function TimerGui:update(unit,t,dt)
        if active() and self._started and not self._done and self._powered and type(self._current_timer) == "number" then
            if self._jammed then self:set_jammed(false) end
            -- Use the normal completion path so done sequences and sync still run.
            self._current_jam_timer = nil
            dt = math.max(dt or 0,(math.max(0,self._current_timer)+1)*self:get_timer_multiplier())
        end
        return original(self,unit,t,dt)
    end
    A.timer_wrapped.TimerGui = true
end
if DigitalGui and not A.timer_wrapped.DigitalGui and type(DigitalGui.update) == "function" then
    local original = DigitalGui.update
    function DigitalGui:update(unit,t,dt)
        if active() and self.TYPE == "timer" and self._timer_count_down and not self._timer_paused
            and type(self._timer) == "number" then
            dt = math.max(dt or 0,math.max(0,self._timer)+1)
        end
        return original(self,unit,t,dt)
    end
    A.timer_wrapped.DigitalGui = true
end
