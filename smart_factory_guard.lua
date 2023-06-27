function widget:GetInfo()
    return {
        name = "Smart Factory Guard",
        desc = "If mobile buildpower is guarding an idle factory, they will automatically assist with a nearby build/repair task (if any are available) before returning to guard the idle factory.",
        author = "IM1",
        date = "June 2023",
        license = "GNU GPL, v2 or later",
        enabled = true
    }
end




local do_until_game_minutes = 15.0 -- only run this widget before this game time, so we don't contribute to lategame lag


local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end


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



factories = {}
function widget:UnitCreated(unitID, unitDefID, unitTeam)
  	if (Spring.GetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end
	if unitTeam ~= Spring.GetMyTeamID() then
		return
	end
	UD = UnitDefs[Spring.GetUnitDefID(unitID)]
	if UD == nil then
		return
	end
	if not UD.isFactory then
		return
	end
	
	table.insert(factories, unitID)
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if (Spring.GetSpectatingState()) then
  		widgetHandler:RemoveWidget()
  	end

	factories[unitID] = nil
end


function reassign_cons_guarding_idle_lab()
	for i,unit_id in ipairs(factories) do
		UD = UnitDefs[Spring.GetUnitDefID(unit_id)]
		if UD ~= nil then
			if UD.isFactory then
				x, y, z = Spring.GetUnitPosition(unit_id)
				local unitsInRange = Spring.GetUnitsInSphere(x, y, z, 400, Spring.GetMyTeamID()) -- get units on top of lab
				for i,unit_id2 in ipairs(unitsInRange) do			
					UD = UnitDefs[Spring.GetUnitDefID(unit_id2)]
					if UD.isBuilder and not UD.isStaticBuilder and not UD.canResurrect then
						local _, _, _, _, buildProgress = Spring.GetUnitHealth(unit_id2)
						if buildProgress == 1 then -- filter out units under construction
							--local currentUnitCommand = Spring.GetUnitCurrentCommand(unit_id)
							local is_factory_idle = Spring.GetRealBuildQueue(unit_id)[1] == nil
							if is_factory_idle then
								unitCommands = Spring.GetUnitCommands(unit_id2, -1)
								if unitCommands ~= nil and #unitCommands > 0 then
									firstCmd = unitCommands[1]
									if firstCmd['id'] == CMD.GUARD then
										local guardID = firstCmd['params'][1]
										if guardID == unit_id then
											--x2, y2, z2 = Spring.GetUnitPosition(unit_id2)
											for i,unit_id3 in ipairs(unitsInRange) do	
												local _, _, _, _, buildProgress = Spring.GetUnitHealth(unit_id3)
												if buildProgress < 1 and unit_id3 ~= unit_id2 and unit_id3 ~= unit_id then
													Spring.GiveOrderToUnit(unit_id2, CMD.STOP, {}, {} )
													Spring.GiveOrderToUnit(unit_id2, CMD.REPAIR, {unit_id3}, {})
													Spring.GiveOrderToUnit(unit_id2, CMD.INSERT, { -1, CMD.GUARD, CMD.OPT_SHIFT, unit_id }, { 'alt' })
													break
												end
											end
										end
									end
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
	if ((n%60)<1) then
		if Spring.GetGameSeconds() / 60 < do_until_game_minutes then
			reassign_cons_guarding_idle_lab()
		else
			widgetHandler:RemoveWidget()
		end
	end
end
