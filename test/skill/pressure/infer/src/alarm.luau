--!strict
-- Guards raise the alarm when they spot an intruder and drop it a while later.
-- In a garrison of a few thousand, a handful are alarmed at any time.
local Game = require("./game")

local Alarm = {}

-- Called from the perception events, not every frame.
function Alarm.spotted(guard: any)
	Game.setAlarmed(guard, true)
end

function Alarm.calmedDown(guard: any)
	Game.setAlarmed(guard, false)
end

-- Runs every frame: alarmed guards ring the nearest bell.
function Alarm.step(ring: (any) -> ())
	for _, guard in Game.alarmed() do
		ring(guard)
	end
end

return Alarm
