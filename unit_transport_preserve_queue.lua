function widget:GetInfo()
    return {
        name = "Unit Transport Preserve (Command) Queue",
        desc = "Restores command queue of units after they are unloaded from air transport. Initial move/guard commands in the unit's command queue are discarded.",
        author = "IM1",
        date = "July 2023",
        license = "GNU GPL, v2 or later",
		version = 0.2,
        layer = -1,
        enabled = true
    }
end



local recentlyUnloaded = nil


function widget:Initialize()
	if Spring.GetSpectatingState() then
		widgetHandler:removeWidget()
	end
end



function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if unitTeam == Spring.GetMyTeamID() then
		recentlyUnloaded = {unitID, Spring.GetCommandQueue(unitID, -1)}
	end
end

function widget:Update()
	if recentlyUnloaded == nil then
		return
	end
	
	unitID = recentlyUnloaded[1]
	oldBuildQueue = recentlyUnloaded[2]
	recentlyUnloaded = nil
	
	local hasSeenValidCommandToPreserve = false
	-- restore unit's command queue (except for initial move commands)
	for i, cmd in ipairs(oldBuildQueue) do
		if cmd['id'] ~= CMD.MOVE and cmd['id'] ~= CMD.GUARD then
			hasSeenValidCommandToPreserve = true
		end
		if hasSeenValidCommandToPreserve then		
			Spring.GiveOrderToUnit(unitID, CMD.INSERT, { -1, cmd['id'], CMD.OPT_SHIFT, cmd['params'][1], cmd['params'][2], cmd['params'][3], cmd['params'][4] }, { 'alt' })
		end
	end	
end


