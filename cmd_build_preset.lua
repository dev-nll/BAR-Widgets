function widget:GetInfo()
    return {
        name = "Build Preset",
        desc = "Builds stuff according to the defined preset",
        author = "IM1",
        date = "June 2023",
        license = "GNU GPL, v2 or later",
        enabled = true
    }
end



function widget:Initialize()
	widgetHandler:AddAction("build_wind_sparse", build_wind_sparse, nil, 'p')
	widgetHandler:AddAction("build_wind_dense", build_wind_dense, nil, 'p')
	widgetHandler:AddAction("build_mines", build_mines, nil, 'p')
end





local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end



local BuildPreset = {}
BuildPreset.__index = BuildPreset



function BuildPreset.new(buildingNamesPreferred, buildingNamesSecondary, panelSize, panelPadding, nRow, nCol, skipModuloRow, skipModuloCol)
	local self = setmetatable({}, BuildPreset)
	self.buildingNamesPreferred = buildingNamesPreferred
	self.buildingNamesSecondary = buildingNamesSecondary
	self.panelSize = panelSize
	self.panelPadding = panelPadding
	self.nRow = nRow
	self.nCol = nCol
	self.skipModuloRow = skipModuloRow
	self.skipModuloCol = skipModuloCol
	return self
end

function BuildPreset.is_building_type_preferred(self, name)
	return has_value(self.buildingNamesPreferred, name)
end

function BuildPreset.is_building_type_secondary(self, name)
	return has_value(self.buildingNamesSecondary, name)
end



function build_mines()
	preset = BuildPreset.new({'cormine1', 'armmine1'}, {'cormine2', 'armmine2'}, 1, 60, 4, 4, 0, 0)
	build_preset(preset)
end

function build_wind_sparse()
	preset = BuildPreset.new({'armwin', 'corwin'}, {}, 47, 1, 7, 7, 2, 4)
	build_preset(preset)
end

function build_wind_dense()
	preset = BuildPreset.new({'armwin', 'corwin'}, {}, 47, 1, 7, 7, 4, 3)
	build_preset(preset)
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







function build_preset(preset)
	-- Define the size of the grid
	local nRow = preset.nRow
	local nCol = preset.nCol

	-- Define the position and size of the buildings
	local panelSize = preset.panelSize  -- Adjust the size as needed
	local panelPadding = preset.panelPadding  -- Adjust the padding between panels as needed

	-- Get the current mouse cursor position
	local mouseX, mouseY = Spring.GetMouseState()
	_, xyz_mouse = Spring.TraceScreenRay(mouseX, mouseY, true)
	mouseX = xyz_mouse[1]
	mouseY = xyz_mouse[3]

	-- Calculate the starting position of the grid based on the mouse cursor position
	local gridStartX = mouseX - (panelSize + panelPadding) * ((nRow - 1) / 2)
	local gridStartY = mouseY - (panelSize + panelPadding) * ((nCol - 1)/ 2)

	builders = {}
	for i, unitID in ipairs(Spring.GetSelectedUnits()) do
		UD = UnitDefs[Spring.GetUnitDefID(unitID)]
		if UD.isBuilder and not UD.isStaticBuilder then
			table.insert(builders, unitID)
		end
	end
	
	if #builders == 0 then
		return
	end

	for i, builderUnitID in ipairs(builders) do
		local buildCmdID = nil
		local unitDefID = Spring.GetUnitDefID(builderUnitID)
		local unitDef = UnitDefs[unitDefID]
		if unitDef and unitDef.buildOptions then
		  for i, buildOptionID in ipairs(unitDef.buildOptions) do
			local buildOptionDef = UnitDefs[buildOptionID]
			if buildOptionDef and preset:is_building_type_preferred(buildOptionDef.name) then
			  buildCmdID = buildOptionDef.id
			  break
			end
		  end
		end
		
		if buildCmdID == nil then
			if unitDef and unitDef.buildOptions then
			  for i, buildOptionID in ipairs(unitDef.buildOptions) do
				local buildOptionDef = UnitDefs[buildOptionID]
				if buildOptionDef and preset:is_building_type_secondary(buildOptionDef.name) then
				  buildCmdID = buildOptionDef.id
				  break
				end
			  end
			end
		end
		
		if buildCmdID ~= nil then

			currentBuilderCommand = Spring.GetUnitCurrentCommand(builderUnitID)
			local isCurrentCommandGuard = currentUnitCommand ~= nil and currentUnitCommand == CMD.GUARD
			if isCurrentCommandGuard then
				Spring.GiveOrderToUnit(builderUnitID, CMD.STOP, {}, {} )
			end
			
			local refX, _, refZ = Spring.GetUnitPosition(builderUnitID)
			
			unitCommands = Spring.GetUnitCommands(builderUnitID, -1)
			if unitCommands ~= nil and #unitCommands > 0 then
				lastCmd = unitCommands[#unitCommands]
				if lastCmd['id'] < 0 then
					refX = lastCmd['params'][1]
					refZ = lastCmd['params'][3]
				end
			end
			--Spring.Echo(unitCommands)
			--Spring.Echo(dump())
			
			if refZ < mouseY then
				rowLoopStart = 1
				rowLoopEnd = nRow
				rowLoopIt = 1
			else
				rowLoopStart = nRow
				rowLoopEnd = 1
				rowLoopIt = -1
			end
			
			local reverseRowAndColumn = false
			
			if refX < mouseX then
				flip = false
			else
				flip = true
			end
			
			for row = rowLoopStart, rowLoopEnd, rowLoopIt do
				if row % preset.skipModuloRow ~= 0 then
					if not flip then
						-- loop forwards
						for col = 1, (nCol) do
							if col % preset.skipModuloCol ~= 0 then
								local panelX = gridStartX + ((reverseRowAndColumn and row or col) - 1) * (panelSize + panelPadding)
								local panelY = gridStartY + ((reverseRowAndColumn and col or row) - 1) * (panelSize + panelPadding)
								--Spring.GiveOrderToUnit(builderUnitID, -buildCmdID, { 2660, 0, 6090 }, 0)
								Spring.GiveOrderToUnit(builderUnitID, CMD.INSERT, { -1, -buildCmdID, CMD.OPT_SHIFT, panelX, 0, panelY }, { 'alt' })
							end
						end
						flip = true
					else
						-- loop backwards
						local col = nCol + 1
						while(true) do
							col = col - 1
							if col % preset.skipModuloCol ~= 0 then
								local panelX = gridStartX + ((reverseRowAndColumn and row or col) - 1) * (panelSize + panelPadding)
								local panelY = gridStartY + ((reverseRowAndColumn and col or row) - 1) * (panelSize + panelPadding)
								Spring.GiveOrderToUnit(builderUnitID, CMD.INSERT, { -1, -buildCmdID, CMD.OPT_SHIFT, panelX, 0, panelY }, { 'alt' })
							end
							if (col == 1) then break; end
						end
						flip = false
					end
				end
			end
		end
	end
end
