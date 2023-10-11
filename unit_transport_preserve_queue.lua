function widget:GetInfo()
    return {
        name = "Unit Transport Preserve (Command) Queue",
        desc = "Restores command queue of units after they are unloaded from air transport. Initial move/guard commands in the unit's command queue are discarded.",
        author = "IM1, DrWizzard",
        date = "July 2023",
        license = "GNU GPL, v2 or later",
		version = 0.3,
        layer = -1,
        enabled = true
    }
end

local CMD_MOVE = CMD.MOVE
local CMD_GUARD = CMD.GUARD
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_LOAD_ONTO = CMD.LOAD_ONTO
local CMD_WAIT = CMD.WAIT
local CMD_INSERT = CMD.INSERT
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGetCommandQueue = Spring.GetCommandQueue

local player_team_id = Spring.GetLocalTeamID()
local recentlyUnloaded = {}

function widget:Initialize()
	if Spring.GetSpectatingState() then
		widgetHandler:removeWidget()
	end
end

function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if unitTeam == player_team_id then
		local commands = spGetCommandQueue(unitID, -1)
		if commands and commands[1] and commands[1].id==CMD_WAIT then
			return
		end
		recentlyUnloaded[#recentlyUnloaded + 1] = {unitID, commands}
	end
end

function widget:Update()
	if #recentlyUnloaded == 0 then
		return
	end
	for j=1, #recentlyUnloaded do
		local kvp = recentlyUnloaded[j]
		local unitID = kvp[1]
		local oldBuildQueue = kvp[2]
		if oldBuildQueue ~= nil then
			local orders = {}
			local hasSeenValidCommandToPreserve = false
			for i = 1, #oldBuildQueue do
				local cmd = oldBuildQueue[i]
				if cmd['id'] ~= CMD_MOVE and cmd['id'] ~= CMD_GUARD and cmd['id'] ~= CMD_LOAD_UNITS and cmd['id'] ~= CMD_LOAD_ONTO then
					hasSeenValidCommandToPreserve = true
				end
				if hasSeenValidCommandToPreserve then	
					orders[#orders+1] = {cmd.id, cmd.params, cmd.options}
				end
			end
			spGiveOrderArrayToUnit(unitID, orders)	
		end
	end
	recentlyUnloaded = {}
end
