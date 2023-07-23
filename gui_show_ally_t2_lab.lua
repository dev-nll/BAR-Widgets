function widget:GetInfo()
    return {
        name = "Show Ally T2 Lab",
        desc = "Puts a flashing yellow light around allies' t2 labs whenever your camera is zoomed out.",
        author = "IM1",
        date = "July 2023",
        license = "GNU GPL, v2 or later",
		layer = -10,
        enabled = true,
    }
end




local factories = {}
local animationDuration = 2
local animationFrequency = 3

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end



function widget:DrawWorld()
	if next(factories) == nil then
		return
	end

	local cameraState = Spring.GetCameraState()
	local camHeight = cameraState and cameraState.dist or nil

	if camHeight < 9000 then
		return
	end

	for _, unitID in pairs(factories) do
		local x, y, z = Spring.GetUnitPosition(unitID)

		if x == nil or y == nil or z == nil then
			return
		end

		local currentTime = Spring.GetGameSeconds() % animationDuration
		local animationProgress = math.sin((currentTime / animationDuration) * (2 * math.pi * animationFrequency))

		local redColor = 1
		local greenColor = (0.8 + animationProgress * 0.2)
		local radiusSize = 280 + animationProgress * 25

		gl.Color(1, greenColor, 0, 1)
		gl.DrawGroundCircle(x, y, z, radiusSize, 32)  -- Increase the radius based on animation progress

		local numSegments = 32
		local angleStep = (2 * math.pi) / numSegments
		gl.BeginEnd(GL.TRIANGLE_FAN, function()
			--gl.Color(1, greenColor, 0, (selectedUnit == unitID) and (0.5 + animationProgress * 0.5) or 0.2)  -- Increase the alpha based on animation progress
			gl.Color(1, greenColor, 0, (0.5 + animationProgress * 0.5))  -- Set alpha value to 1.0 for fully opaque red
			gl.Vertex(x, y+200, z)
			for i = 0, numSegments do
				local angle = i * angleStep
				--gl.Vertex(x + math.sin(angle) * (100 + animationProgress * 10), y + 30, z + math.cos(angle) * (100 + animationProgress * 10))  -- Increase the ring size based on animation progress
				gl.Vertex(x + math.sin(angle) * radiusSize, y + 80, z + math.cos(angle) * radiusSize)
			end
		end)
	end
end




function newUnitCallin(unitID, unitDefID, unitTeam)
	UD = UnitDefs[Spring.GetUnitDefID(unitID)]
	if UD == nil then
		return
	end
	if UD.isFactory and string.match(UD.translatedTooltip, "Tech 2") then
		if unitTeam == Spring.GetMyTeamID() then
			--widgetHandler:RemoveWidget() -- stop widget when we have our own t2 lab
			--Spring.Echo("Removing gui_show_ally_t2_lab.lua now that you have your own t2 lab.")
			--return
		end
		factories[unitID] = unitID
	end	
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	newUnitCallin(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	factories[unitID] = nil
end


function widget:Initialize()
  	if (Spring.GetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end
end
