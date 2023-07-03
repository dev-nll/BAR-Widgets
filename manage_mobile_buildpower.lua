function widget:GetInfo()
    return {
        name = "Manage Mobile Buildpower",
        desc = "Tries to stop mobile buildpower from going idle when there are nearby tasks.",
        author = "IM1",
        date = "June 2023",
        license = "GNU GPL, v2 or later",
        enabled = true
    }
end


local doUntilGameMinutes = 12.0 -- only run this widget before this game time in minutes


local function hasValue (tab, val)
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



local function getIndex(tab, val)
    local index = nil
    for i, v in ipairs (tab) do 
        if (v.id == val) then
          index = i 
        end
    end
    return index
end


local function distanceFromSpawn(unitID)
	x, y, z = Spring.GetTeamStartPosition(Spring.GetMyTeamID())
	x2, y2, z2 = Spring.GetUnitPosition(unitID)
	local distance = math.sqrt(math.pow(x-x2, 2) + math.pow(z-z2, 2))
	return distance
end




factories = {}
mobileBuildpower = {}
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
	if UD.isMobileBuilder and not UD.canResurrect and (not UD.canCloak or UD['modCategories'].commander) then
		mobileBuildpower[unitID] = unitID
	end
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	newUnitCallin(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	factories[unitID] = nil
	mobileBuildpower[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if oldTeam == Spring.GetMyTeamID() then
		factories[unitID] = nil
		mobileBuildpower[unitID] = nil
	else
		newUnitCallin(unitID, unitDefID, newTeam)
	end
end



function reassignIdleMobileBuildpower()
	for _, unitID in pairs(mobileBuildpower) do
		repeat
			UD = UnitDefs[Spring.GetUnitDefID(unitID)]
			if UD['modCategories'].commander and distanceFromSpawn(unitID) > 400 then
				-- commander who is out on the field, don't mess with it
				do break end
			end
			unitCommands = Spring.GetUnitCommands(unitID, -1)
			if unitCommands == nil or #unitCommands == 0 then
				-- builder is idle
				x, y, z = Spring.GetUnitPosition(unitID)
				local unitsInRange = Spring.GetUnitsInSphere(x, y, z, 400, Spring.GetMyTeamID())
				local hasIssuedRepairCommand = false
				for i,nearbyUnitID in ipairs(unitsInRange) do	
					local _, _, _, _, buildProgress = Spring.GetUnitHealth(nearbyUnitID)
					if buildProgress < 1 and nearbyUnitID ~= unitID then
						--Spring.GiveOrderToUnit(unitID, CMD.REPAIR, {nearbyUnitID}, {})
						hasIssuedRepairCommand = true
						Spring.GiveOrderToUnit(unitID, CMD.INSERT, { -1, CMD.REPAIR, CMD.OPT_SHIFT, nearbyUnitID }, { 'alt' })
					end
				end
				local mostExpensiveFactoryInRange = 0
				local mostExpensiveFactoryInRangeUnitID = nil
				for _, factoryID in pairs(factories) do
					local unitSeparation = Spring.GetUnitSeparation(unitID, factoryID, true)
					if unitSeparation < 400 then
						UD = UnitDefs[Spring.GetUnitDefID(factoryID)]
						if UD.metalCost > mostExpensiveFactoryInRange then
							mostExpensiveFactoryInRange = UD.metalCost
							mostExpensiveFactoryInRangeUnitID = factoryID
						end
					end
				end
				
				if mostExpensiveFactoryInRangeUnitID ~= nil then
					Spring.GiveOrderToUnit(unitID, CMD.INSERT, { -1, CMD.GUARD, CMD.OPT_SHIFT, mostExpensiveFactoryInRangeUnitID }, { 'alt' })
				elseif hasIssuedRepairCommand then
					Spring.GiveOrderToUnit(unitID, CMD.INSERT, { -1, CMD.MOVE, CMD.OPT_SHIFT, x, y, z }, { 'alt' })
				end
			end
		until true
	end
end



function reassignMobileBuildpowerGuardingIdleLab()
	for _, factoryID in pairs(factories) do
		local isFactoryIdle = Spring.GetRealBuildQueue(factoryID)[1] == nil
		if isFactoryIdle then
			x, y, z = Spring.GetUnitPosition(factoryID)
			local unitsInRange = Spring.GetUnitsInSphere(x, y, z, 400, Spring.GetMyTeamID()) -- get units around lab
			local unitsInRangeNeedingRepair = {}
			local hasCheckedWhetherUnitsNeedRepair = false
			for i, unitID in ipairs(unitsInRange) do
				repeat
					UD = UnitDefs[Spring.GetUnitDefID(unitID)]
					if not UD.isMobileBuilder or (UD.canCloak and not UD['modCategories'].commander) or UD.canResurrect then
						do break end
					end
					local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
					if buildProgress ~= 1 then
						-- filter out units under construction
						do break end
					end
					--local currentUnitCommand = Spring.GetUnitCurrentCommand(factoryID)
					unitCommands = Spring.GetUnitCommands(unitID, -1)
					if not (unitCommands ~= nil and #unitCommands > 0) then
						do break end
					end
					firstCmd = unitCommands[1]
					if firstCmd['id'] ~= CMD.GUARD then
						do break end
					end
					local guardID = firstCmd['params'][1]
					if guardID ~= factoryID then
						do break end
					end
					if not hasCheckedWhetherUnitsNeedRepair then
						for i, unitID2 in ipairs(unitsInRange) do
							local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID2)
							if buildProgress < 1 and unitID2 ~= unitID and unitID2 ~= factoryID then
								unitsInRangeNeedingRepair[unitID2] = unitID2
							end
						end
						hasCheckedWhetherUnitsNeedRepair = true
					end
					
					local hasIssuedRepairCommand = false
					for _, unitID2 in pairs(unitsInRangeNeedingRepair) do	
						if not hasIssuedRepairCommand then
							Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {} )
							hasIssuedRepairCommand = true
						end
						Spring.GiveOrderToUnit(unitID, CMD.INSERT, { -1, CMD.REPAIR, CMD.OPT_SHIFT, unitID2 }, { 'alt' })
						--Spring.GiveOrderToUnit(unitID, CMD.REPAIR, {unitID2}, {})
					end
					nonIdleFactoryID = nil
					for _, factoryID_ in pairs(factories) do
						-- see if there's a nearby factory that isn't idle that we can guard instead
						local unitSeparation = Spring.GetUnitSeparation(unitID, factoryID_, true)
						local isFactoryIdle = Spring.GetRealBuildQueue(factoryID_)[1] == nil
						if unitSeparation < 600 and not isFactoryIdle then
							nonIdleFactoryID = factoryID_
						end
					end
					if nonIdleFactoryID ~= nil then
						Spring.GiveOrderToUnit(unitID, CMD.INSERT, { -1, CMD.GUARD, CMD.OPT_SHIFT, nonIdleFactoryID }, { 'alt' })
					elseif hasIssuedRepairCommand then
						Spring.GiveOrderToUnit(unitID, CMD.INSERT, { -1, CMD.GUARD, CMD.OPT_SHIFT, factoryID }, { 'alt' })
					end
				until true
			end
		end
	end
end




function widget:GameFrame(n)	
	if (((n+1)%60)<1) then
		if Spring.GetGameSeconds() / 60 < doUntilGameMinutes then
			reassignIdleMobileBuildpower()
			reassignMobileBuildpowerGuardingIdleLab()
		else
			widgetHandler:RemoveWidget()
		end
	end
end
