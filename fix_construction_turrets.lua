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


function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if unitDefID == nil then
		return
	end
	UD = UnitDefs[unitDefID]
	if not UD.canAssist or not UD.isStaticBuilder then
		-- isn't a construction turret
		return
	end
	target_unit_id = cmdParams[1]
	if target_unit_id == nil then
		return
	end
	if cmdID ~= 25 and cmdID ~= 40 and cmdID ~= 90 and cmdID ~= 125 then
		-- isn't a guard or repair or reclaim or rezz command
		return
	end
	if cmdParams[2] ~= nil then
		-- area command
		return
	end
	if cmdID == 25 then		
		local target_UD = UnitDefs[Spring.GetUnitDefID(target_unit_id)]
		if target_UD == nil then
			return
		end
		if not target_UD.isBuilder then
			-- guarding idle lab, issue stop command
			Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {} )
			return
		end
	end
	if Spring.GetUnitSeparation(target_unit_id, unitID, true) > UD.buildDistance then
		-- impossible command detected, issue stop command.
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {} )
		return
	end
end


function stop_nanos_guarding_idle_lab()
	local all_my_units = Spring.GetTeamUnits(Spring.GetMyTeamID())
	for i,unit_id in ipairs(all_my_units) do
		UD = UnitDefs[Spring.GetUnitDefID(unit_id)]
		local name = UD.name
		if UD.canAssist and UD.isStaticBuilder and not UD.isBuilding and not UD.isFactory and (UD.metalCost < 400) then
			local command_queue = Spring.GetCommandQueue(unit_id, 0)
			local is_nano_busy = command_queue == 1
			if is_nano_busy then
				local all_commands = Spring.GetUnitCommands(unit_id, 1)
				if all_commands[1]['id'] == CMD.GUARD then
					target_unit_id = all_commands[1]['params'][1]
					target_UD = UnitDefs[Spring.GetUnitDefID(target_unit_id)]
					if target_UD.isBuilding then
						local target_command_queue = Spring.GetCommandQueue(target_unit_id, 0)
						local is_target_busy = target_command_queue == 1
						if not is_target_busy then
							Spring.GiveOrderToUnit(unit_id, CMD.STOP, {}, {} )
						end
					end
				end
			end
		end
	end
end




function widget:GameFrame(n)	
	if ((n%1201) < 1) then
		-- poll irregularly to reduce performance impact.
		stop_nanos_guarding_idle_lab()
	end
end


function widget:Initialize()
end


