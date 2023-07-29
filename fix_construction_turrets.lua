function widget:GetInfo()
    return {
        name = "Fix Construction Turrets",
        desc = "Prevents nanos from (1) guarding/repairing/reclaiming/rezzing units outside of its range, (2) guarding an idle lab, and (3) guarding buildings that can't make units.",
        author = "IM1",
        date = "June 2023",
        license = "GNU GPL, v2 or later",
        enabled = true
    }
end


nanos = {}
function newUnit(unitID, unitDefID, unitTeam)
	if unitTeam ~= Spring.GetMyTeamID() then
		return
	end
	UD = UnitDefs[Spring.GetUnitDefID(unitID)]
	if UD == nil then
		return
	end
	if UD.canAssist and UD.isStaticBuilder and not UD.isBuilding and not UD.isFactory and (UD.metalCost < 400) then
		nanos[unitID] = unitID
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	newUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	nanos[unitID] = nil
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if oldTeam == Spring.GetMyTeamID() then
		nanos[unitID] = nil
	else
		newUnit(unitID, unitDefID, newTeam)
	end
end






-- stop nanos messing up to begin with
function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if unitID == nil then
		return
	end
	if unitDefID == nil then
		return
	end
	UD = UnitDefs[unitDefID]
	if UD == nil then
		return
	end
	if not UD.canAssist or not UD.isStaticBuilder then
		-- isn't a construction turret
		return
	end
	target_unit_id = cmdParams[1]
	if target_unit_id == nil then
		return
	end
	if cmdID ~= CMD.GUARD and cmdID ~= CMD.REPAIR and cmdID ~= CMD.RECLAIM and cmdID ~= CMD.RESURRECT then
		-- isn't a guard or repair or reclaim or rezz command
		return
	end
	if cmdParams[2] ~= nil then
		-- area command
		return
	end
	if cmdID == CMD.GUARD then		
		local target_UD = UnitDefs[Spring.GetUnitDefID(target_unit_id)]
		if target_UD == nil then
			return
		end
		if not target_UD.isBuilder then
			-- trying to guard something that isn't a lab, issue stop command
			Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {} )
			return
		end
	end
	local unitSeparation = Spring.GetUnitSeparation(target_unit_id, unitID, true)
	if UD.buildDistance == nil or unitSeparation == nil or unitSeparation > UD.buildDistance then
		-- impossible command detected, issue stop command.
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {} )
		return
	end
end






-- fix remaining nanos that have messed up
function fixNanosAfterTheFact()
	for _, unitID in pairs(nanos) do
		local allCommands = Spring.GetUnitCommands(unitID, 1)
		--Spring.Echo(dump(allCommands))
		if allCommands ~= nil and #allCommands > 0 then
			if allCommands[1]['id'] == CMD.GUARD or allCommands[1]['id'] == CMD.REPAIR then
				-- stop nanos assisting beyond range
				targetUnitID = allCommands[1]['params'][1]
				if targetUnitID ~= nil then
					if Spring.GetUnitSeparation(unitID, targetUnitID, true) > UnitDefs[Spring.GetUnitDefID(unitID)].buildDistance then
						Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {} )
					end
				end
				-- stop nanos assisting idle lab
				targetUD = UnitDefs[Spring.GetUnitDefID(targetUnitID)]
				if targetUnitID ~= nil and allCommands[1]['id'] == CMD.GUARD then
					local targetCommandQueue = Spring.GetCommandQueue(targetUnitID, 0) -- note brand new idle lab == 0 if no units produced yet
					local isTargetBusy = false
					if targetUD.isBuilding and targetCommandQueue == 1 then
						isTargetBusy = true
					elseif not targetUD.isBuilding then
						isTargetBusy = targetCommandQueue > 1 or (targetCommandQueue == 1 and Spring.GetUnitCommands(targetUnitID, 1)[1]['id'] ~= CMD.GUARD)
					end
					if not isTargetBusy then
						Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {} )
					end
				end
			end
		end
	end
end


function widget:GameFrame(n)
	if ((n%301) < 1) then
		fixNanosAfterTheFact()
	end
end



function widget:Initialize()
end


