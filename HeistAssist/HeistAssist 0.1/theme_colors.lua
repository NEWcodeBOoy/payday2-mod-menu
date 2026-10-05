local A=HeistAssist
function A:hsv_color(h,s,v)
    h=(h%360)/60; local c=v*s; local x=c*(1-math.abs(h%2-1)); local m=v-c
    local rgb=h<1 and {c,x,0} or h<2 and {x,c,0} or h<3 and {0,c,x} or h<4 and {0,x,c} or h<5 and {x,0,c} or {c,0,x}
    return Color(1,rgb[1]+m,rgb[2]+m,rgb[3]+m)
end
function A:set_theme_hex(value)
    value=tostring(value):gsub('#',''):upper()
    if not value:match('^%x%x%x%x%x%x$') then return false end
    local r,g,b=tonumber(value:sub(1,2),16)/255,tonumber(value:sub(3,4),16)/255,tonumber(value:sub(5,6),16)/255
    local hi,lo=math.max(r,g,b),math.min(r,g,b); local d=hi-lo; local h=0
    if d>0 then h=hi==r and ((g-b)/d)%6 or hi==g and (b-r)/d+2 or (r-g)/d+4 end
    self.appearance.hue=h*60; self.appearance.saturation=hi==0 and 0 or d/hi; self.appearance.brightness=hi
    self.appearance.cycle=false
    return true
end
function A:theme_hex()
    local c=self:hsv_color(self.appearance.hue,self.appearance.saturation,self.appearance.brightness)
    return string.format('%02X%02X%02X',math.floor(c.red*255+0.5),math.floor(c.green*255+0.5),math.floor(c.blue*255+0.5))
end
