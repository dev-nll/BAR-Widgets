function widget:GetInfo()
    return {
        name = "Fix Obstructed Lab",
        desc = "Moves units out of the way if they're blocking unit construction, because whatever is in place to do that currently occasionally doesn't work.",
        author = "IM1",
        date = "June 2023",
        license = "GNU GPL, v2 or later",
        enabled = true --  loaded by default?
    }
end



local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
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
local last_check_minutes = nil
local last_moved_minutes = nil
local moved_unit_id = nil

function fix_obstructed_lab()
	if last_moved_minutes ~= nil and Spring.GetGameSeconds() / 60 - last_moved_minutes > 0.06 then
		Spring.GiveOrderToUnit(moved_unit_id, CMD.STOP, {}, {} )
		last_x2 = nil
		last_z2 = nil
		last_check_minutes = nil
		moved_unit_id = nil
		last_moved_minutes = nil
		return
	end

	for i,unit_id in ipairs(factories) do
		UD = UnitDefs[Spring.GetUnitDefID(unit_id)]
		if UD ~= nil then
			if UD.isFactory then
				x, y, z = Spring.GetUnitPosition(unit_id)
				local unitsInRange = Spring.GetUnitsInSphere(x, y, z, 58, Spring.GetMyTeamID()) -- get units on top of lab
				for i,unit_id2 in ipairs(unitsInRange) do			
					UD = UnitDefs[Spring.GetUnitDefID(unit_id2)]
					if not UD.isBuilding then
						local _, _, _, _, buildProgress = Spring.GetUnitHealth(unit_id2)
						if buildProgress == 1 then -- filter out units under construction
							x2, y2, z2 = Spring.GetUnitPosition(unit_id2)
							if last_x2 == nil then
								last_x2 = x2
								last_z2 = z2
								last_check_minutes = Spring.GetGameSeconds() / 60
							elseif Spring.GetGameSeconds() / 60 - last_check_minutes > 0.03 then
								if math.abs(x2 - last_x2) < 3 and math.abs(z2 - last_z2) < 3 then
									-- unit has been stationary for a few seconds, force it out of the way.
									Spring.GiveOrderToUnit(unit_id2, CMD.MOVE, {x2 - 65, y2, z2-65}, {})
									last_x2 = nil
									last_z2 = nil
									last_check_minutes = nil
									last_moved_minutes = Spring.GetGameSeconds() / 60
									moved_unit_id = unit_id2
								else
									last_x2 = x2
									last_z2 = z2
									last_check_minutes = Spring.GetGameSeconds() / 60
								end
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
		fix_obstructed_lab()
	end
end



function widget:Initialize()
  	if (Spring.GetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end

end

