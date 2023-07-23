function widget:GetInfo()
    return {
        name = "Fix Obstructed Lab",
        desc = "Moves units out of the way if they're blocking unit construction, because whatever is in place to do that currently occasionally doesn't work.",
        author = "IM1",
        date = "June 2023",
        license = "GNU GPL, v2 or later",
        enabled = true
    }
end





factories = {}
function newUnitCallin(unitID, unitDefID, unitTeam)
	if unitTeam ~= Spring.GetMyTeamID() then
		return
	end
	UD = UnitDefs[Spring.GetUnitDefID(unitID)]
	if UD == nil then
		return
	end
	if UD.isFactory then
		factories[unitID] = unitID
	end
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	newUnitCallin(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	factories[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if oldTeam == Spring.GetMyTeamID() then
		factories[unitID] = nil
	else
		newUnitCallin(unitID, unitDefID, newTeam)
	end
end



local last_x2 = nil
local last_z2 = nil
local lastCheckMinutes = nil
local lastMovedMinutes = nil
local movedUnitID = nil

function fixObstructedLab()
	if lastMovedMinutes ~= nil and Spring.GetGameSeconds() / 60 - lastMovedMinutes > 0.06 then
		Spring.GiveOrderToUnit(movedUnitID, CMD.STOP, {}, {} )
		last_x2 = nil
		last_z2 = nil
		lastCheckMinutes = nil
		movedUnitID = nil
		lastMovedMinutes = nil
		return
	end

	for _,unitID in pairs(factories) do
		UD = UnitDefs[Spring.GetUnitDefID(unitID)]
		if UD ~= nil then
			x, y, z = Spring.GetUnitPosition(unitID)
			local unitsInRange = Spring.GetUnitsInSphere(x, y, z, 58, Spring.GetMyTeamID()) -- get units on top of lab
			for i, unitID2 in ipairs(unitsInRange) do			
				UD = UnitDefs[Spring.GetUnitDefID(unitID2)]
				if not UD.isBuilding then
					local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID2)
					if buildProgress == 1 then -- filter out units under construction
						x2, y2, z2 = Spring.GetUnitPosition(unitID2)
						if last_x2 == nil then
							last_x2 = x2
							last_z2 = z2
							lastCheckMinutes = Spring.GetGameSeconds() / 60
						elseif Spring.GetGameSeconds() / 60 - lastCheckMinutes > 0.03 then
							if math.abs(x2 - last_x2) < 3 and math.abs(z2 - last_z2) < 3 then
								-- unit has been stationary for a few seconds, force it out of the way.
								Spring.GiveOrderToUnit(unitID2, CMD.MOVE, {x2 - 65, y2, z2-65}, {})
								last_x2 = nil
								last_z2 = nil
								lastCheckMinutes = nil
								lastMovedMinutes = Spring.GetGameSeconds() / 60
								movedUnitID = unitID2
							else
								last_x2 = x2
								last_z2 = z2
								lastCheckMinutes = Spring.GetGameSeconds() / 60
							end
						end
					end
				end
			end
		end
	end
end



function widget:GameFrame(n)	
	if ((n%120)<1) then
		fixObstructedLab()
	end
end



function widget:Initialize()
  	if (Spring.GetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end

end


