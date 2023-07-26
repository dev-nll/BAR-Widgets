function widget:GetInfo()
    return {
      name      = "Energy Converter Reminder",
      desc      = "Suggests how many additional advanced converters you need to build to avoid overflow.",
      author    = "IM1",
      date      = "July 2023",
      layer     = -10,
      enabled   = true
    }
  end







-- FIFO implementation
List = {}
function List.new ()
	return {first = 0, last = -1}
end

function List.pushleft (list, value)
	local first = list.first - 1
	list.first = first
	list[first] = value
end

function List.pushright (list, value)
	local last = list.last + 1
	list.last = last
	list[last] = value
end

function List.popleft (list)
	local first = list.first
	if first > list.last then error("list is empty") end
	local value = list[first]
	list[first] = nil
	list.first = first + 1
	return value
end

function List.popright (list)
	local last = list.last
	if list.first > last then error("list is empty") end
	local value = list[last]
	list[last] = nil
	list.last = last - 1
	return value
end








-- Keep track of your winds and converters
nWinds = 0
winds = {}
converters = {}
function newUnitCallin(unitID, unitDefID, unitTeam)
	if unitTeam ~= Spring.GetMyTeamID() then
		return
	end
	UD = UnitDefs[Spring.GetUnitDefID(unitID)]
	if UD == nil then
		return
	end
	if UD.name == "armwin" or UD.name == "corwin" then
		nWinds = nWinds + 1
		winds[unitID] = unitID
	end
	if string.match(UD.translatedHumanName, "Energy Converter") then
		converters[unitID] = unitID
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	newUnitCallin(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if unitTeam ~= Spring.GetMyTeamID() then
		return
	end
	UD = UnitDefs[Spring.GetUnitDefID(unitID)]
	if UD.name == "armwin" or UD.name == "corwin" then
		nWinds = nWinds - 1
		if nWinds < 0 then
			Spring.Echo("nWinds shouldn't be < 0.")
			widgetHandler:RemoveWidget()
		end
	end
	winds[unitID] = nil
	converters[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if oldTeam == Spring.GetMyTeamID() then
		UD = UnitDefs[Spring.GetUnitDefID(unitID)]
		if UD.name == "armwin" or UD.name == "corwin" then
			nWinds = nWinds - 1
			if nWinds < 0 then
				Spring.Echo("nWinds shouldn't be < 0.")
				widgetHandler:RemoveWidget()
			end
		end
		winds[unitID] = nil
		converters[unitID] = nil
	else
		newUnitCallin(unitID, unitDefID, newTeam)
	end
end








local energyUseDeque = List.new()



local energyExpectedValue = nil
local energyExcessExpectedValue = nil
local actualEnergyExcess = nil


local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2

local RectRound, UiElement
local dlistGuishader, dlistCU
local area = {}

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glGetViewSizes = gl.GetViewSizes
local glDeleteList = gl.DeleteList

local floor = math.floor
local round = math.round



local function updateUI()
	local showNumber = energyExcessExpectedValue/600
	if energyExcessExpectedValue < 0 or actualEnergyExcess < 0 then
		showNumber = 0
	end
    local freeArea = WG['topbar'].GetFreeArea()
    widgetScale = freeArea[5]
    area[1] = freeArea[1]
    area[2] = freeArea[2]
    area[3] = freeArea[1] + floor(90 * widgetScale)
    if area[3] > freeArea[3] then
        area[3] = freeArea[3]
    end
    area[4] = freeArea[4]

    local color = "\255\255\255\255"

    local fontSize = (area[4] - area[2]) * 0.4
    local textWidth = font2:GetTextWidth(color .. (string.format("%.1f", showNumber))) * fontSize
    local desiredWidth = textWidth + (fontSize * 0.8) -- Add some padding on both sides of the text

    local actualWidth = area[3] - area[1]
    if desiredWidth < actualWidth then
        local widthDiff = actualWidth - desiredWidth
        area[3] = area[3] - widthDiff
    end

    if dlistCU ~= nil then
        glDeleteList(dlistCU)
    end
	dlistCU = glCreateList(function()
		UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1)--,  1, 0.3, 0.3, 0.25)

        if energyExcessExpectedValue < 0 then
            color = "\255\255\000\000"
        else
            color = "\255\000\255\000"
        end

		if showNumber > 0.4 or (showNumber >= 0.12 and actualEnergyExcess > 100 and energyExcessExpectedValue/energyExpectedValue > 0.1) then
			if Spring.GetGameSeconds() > 300 then
				-- change background color when you need to build converters, so you pay attention
				color1 = { 1, 0, 0.2, 1 }
				color2 = { 1, 1, 0.2, 1 }
				RectRound(area[1], area[2], area[3], area[4], 3.7 * widgetScale, 0, 0, 1, 1, color1, color2)
			end
		end

        font2:Begin()
		font2:Print(color .. (string.format("%.1f", showNumber)), area[1] + (fontSize * 0.4), area[2] + ((area[4] - area[2]) / 2.05) - (fontSize / 5), fontSize, 'ol')
        fontSize = fontSize * 0.75
		font2:End()


	end)
end



function widget:DrawScreen()
	if dlistCU then
        glCallList(dlistCU)
    end
    if area[1] then
        local x, y = Spring.GetMouseState()
        if math.isInRect(x, y, area[1], area[2], area[3], area[4]) then
            Spring.SetMouseCursor('cursornormal')
        end
    end
end


function widget:ViewResize()
    vsx, vsy = glGetViewSizes()

    RectRound = WG.FlowUI.Draw.RectRound
    UiElement = WG.FlowUI.Draw.Element

    font2 = WG['fonts'].getFont(fontfile2)
end




local avgWindScalar = 0.5
local maxWindScalar = 0.5

function widget:Initialize()
    widget:ViewResize()
	if math.abs(avgWindScalar + maxWindScalar - 1) > 0.0001 then
		Spring.Echo("avgWindScalar + maxWindScalar must equal 1")
		widgetHandler:RemoveWidget()
	end
end


-- precomputed average wind values, from wind random monte carlo simulation, given minWind and maxWind
local avgWind = {[0]={[1]="0.8",[2]="1.5",[3]="2.2",[4]="3.0",[5]="3.7",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[1]={[2]="1.6",[3]="2.3",[4]="3.0",[5]="3.8",[6]="4.5",[7]="5.2",[8]="6.0",[9]="6.7",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.4",[15]="11.2",[16]="11.9",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[2]={[3]="2.6",[4]="3.2",[5]="3.9",[6]="4.6",[7]="5.3",[8]="6.0",[9]="6.8",[10]="7.5",[11]="8.2",[12]="9.0",[13]="9.7",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.4",[19]="14.2",[20]="14.9",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.6",[26]="19.2",[27]="19.6",[28]="20.0",[29]="20.4",[30]="20.7",},[3]={[4]="3.6",[5]="4.2",[6]="4.8",[7]="5.5",[8]="6.2",[9]="6.9",[10]="7.6",[11]="8.3",[12]="9.0",[13]="9.8",[14]="10.5",[15]="11.2",[16]="12.0",[17]="12.7",[18]="13.5",[19]="14.2",[20]="15.0",[21]="15.7",[22]="16.4",[23]="17.2",[24]="17.9",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.0",[29]="20.4",[30]="20.7",},[4]={[5]="4.6",[6]="5.2",[7]="5.8",[8]="6.4",[9]="7.1",[10]="7.8",[11]="8.5",[12]="9.2",[13]="9.9",[14]="10.6",[15]="11.3",[16]="12.1",[17]="12.8",[18]="13.5",[19]="14.3",[20]="15.0",[21]="15.7",[22]="16.5",[23]="17.2",[24]="18.0",[25]="18.7",[26]="19.2",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[5]={[6]="5.5",[7]="6.1",[8]="6.8",[9]="7.4",[10]="8.0",[11]="8.7",[12]="9.4",[13]="10.1",[14]="10.8",[15]="11.5",[16]="12.2",[17]="12.9",[18]="13.6",[19]="14.4",[20]="15.1",[21]="15.8",[22]="16.5",[23]="17.3",[24]="18.0",[25]="18.8",[26]="19.3",[27]="19.7",[28]="20.1",[29]="20.4",[30]="20.7",},[6]={[7]="6.5",[8]="7.1",[9]="7.7",[10]="8.4",[11]="9.0",[12]="9.7",[13]="10.3",[14]="11.0",[15]="11.7",[16]="12.4",[17]="13.1",[18]="13.8",[19]="14.5",[20]="15.2",[21]="15.9",[22]="16.7",[23]="17.4",[24]="18.1",[25]="18.8",[26]="19.4",[27]="19.8",[28]="20.2",[29]="20.5",[30]="20.8",},[7]={[8]="7.5",[9]="8.1",[10]="8.7",[11]="9.3",[12]="10.0",[13]="10.6",[14]="11.3",[15]="11.9",[16]="12.6",[17]="13.3",[18]="14.0",[19]="14.7",[20]="15.4",[21]="16.1",[22]="16.8",[23]="17.5",[24]="18.2",[25]="19.0",[26]="19.5",[27]="19.9",[28]="20.3",[29]="20.6",[30]="20.9",},[8]={[9]="8.5",[10]="9.1",[11]="9.7",[12]="10.3",[13]="11.0",[14]="11.6",[15]="12.2",[16]="12.9",[17]="13.6",[18]="14.2",[19]="14.9",[20]="15.6",[21]="16.3",[22]="17.0",[23]="17.7",[24]="18.4",[25]="19.1",[26]="19.6",[27]="20.0",[28]="20.4",[29]="20.7",[30]="21.0",},[9]={[10]="9.5",[11]="10.1",[12]="10.7",[13]="11.3",[14]="11.9",[15]="12.6",[16]="13.2",[17]="13.8",[18]="14.5",[19]="15.2",[20]="15.8",[21]="16.5",[22]="17.2",[23]="17.9",[24]="18.6",[25]="19.3",[26]="19.8",[27]="20.2",[28]="20.5",[29]="20.8",[30]="21.1",},[10]={[11]="10.5",[12]="11.1",[13]="11.7",[14]="12.3",[15]="12.9",[16]="13.5",[17]="14.2",[18]="14.8",[19]="15.4",[20]="16.1",[21]="16.8",[22]="17.4",[23]="18.1",[24]="18.8",[25]="19.5",[26]="20.0",[27]="20.4",[28]="20.7",[29]="21.0",[30]="21.2",},[11]={[12]="11.5",[13]="12.1",[14]="12.7",[15]="13.3",[16]="13.9",[17]="14.5",[18]="15.1",[19]="15.8",[20]="16.4",[21]="17.1",[22]="17.7",[23]="18.4",[24]="19.1",[25]="19.7",[26]="20.2",[27]="20.6",[28]="20.9",[29]="21.2",[30]="21.4",},[12]={[13]="12.5",[14]="13.1",[15]="13.6",[16]="14.2",[17]="14.9",[18]="15.5",[19]="16.1",[20]="16.7",[21]="17.4",[22]="18.0",[23]="18.7",[24]="19.3",[25]="20.0",[26]="20.4",[27]="20.8",[28]="21.1",[29]="21.4",[30]="21.6",},[13]={[14]="13.5",[15]="14.1",[16]="14.6",[17]="15.2",[18]="15.8",[19]="16.5",[20]="17.1",[21]="17.7",[22]="18.4",[23]="19.0",[24]="19.6",[25]="20.3",[26]="20.7",[27]="21.1",[28]="21.4",[29]="21.6",[30]="21.8",},[14]={[15]="14.5",[16]="15.0",[17]="15.6",[18]="16.2",[19]="16.8",[20]="17.4",[21]="18.1",[22]="18.7",[23]="19.3",[24]="20.0",[25]="20.6",[26]="21.0",[27]="21.3",[28]="21.6",[29]="21.8",[30]="22.0",},[15]={[16]="15.5",[17]="16.0",[18]="16.6",[19]="17.2",[20]="17.8",[21]="18.4",[22]="19.0",[23]="19.6",[24]="20.3",[25]="20.9",[26]="21.3",[27]="21.6",[28]="21.9",[29]="22.1",[30]="22.3",},[16]={[17]="16.5",[18]="17.0",[19]="17.6",[20]="18.2",[21]="18.8",[22]="19.4",[23]="20.0",[24]="20.6",[25]="21.3",[26]="21.7",[27]="21.9",[28]="22.2",[29]="22.4",[30]="22.5",},[17]={[18]="17.5",[19]="18.0",[20]="18.6",[21]="19.2",[22]="19.8",[23]="20.4",[24]="21.0",[25]="21.6",[26]="22.0",[27]="22.3",[28]="22.5",[29]="22.7",[30]="22.8",},[18]={[19]="18.5",[20]="19.0",[21]="19.6",[22]="20.2",[23]="20.8",[24]="21.4",[25]="22.0",[26]="22.4",[27]="22.6",[28]="22.8",[29]="23.0",[30]="23.1",},[19]={[20]="19.5",[21]="20.0",[22]="20.6",[23]="21.2",[24]="21.8",[25]="22.4",[26]="22.7",[27]="22.9",[28]="23.1",[29]="23.2",[30]="23.4",},[20]={[21]="20.4",[22]="21.0",[23]="21.6",[24]="22.2",[25]="22.8",[26]="23.1",[27]="23.3",[28]="23.4",[29]="23.6",[30]="23.7",},[21]={[22]="21.4",[23]="22.0",[24]="22.6",[25]="23.2",[26]="23.5",[27]="23.6",[28]="23.8",[29]="23.9",[30]="24.0",},[22]={[23]="22.4",[24]="23.0",[25]="23.6",[26]="23.8",[27]="24.0",[28]="24.1",[29]="24.2",[30]="24.2",},[23]={[24]="23.4",[25]="24.0",[26]="24.2",[27]="24.4",[28]="24.4",[29]="24.5",[30]="24.5",},[24]={[25]="24.4",[26]="24.6",[27]="24.7",[28]="24.7",[29]="24.8",[30]="24.8",},}
-- precomputed percentage of time wind is less than 6, from wind random monte carlo simulation, given minWind and maxWind
local riskWind = {[0]={[1]="100",[2]="100",[3]="100",[4]="100",[5]="100",[6]="100",[7]="56",[8]="42",[9]="33",[10]="27",[11]="22",[12]="18.5",[13]="15.8",[14]="13.6",[15]="11.8",[16]="10.4",[17]="9.2",[18]="8.2",[19]="7.4",[20]="6.7",[21]="6.0",[22]="5.5",[23]="5.0",[24]="4.6",[25]="4.3",[26]="4.0",[27]="3.7",[28]="3.4",[29]="3.2",[30]="3.0",},[1]={[2]="100",[3]="100",[4]="100",[5]="100",[6]="100",[7]="56",[8]="42",[9]="33",[10]="27",[11]="22",[12]="18.5",[13]="15.7",[14]="13.6",[15]="11.8",[16]="10.4",[17]="9.2",[18]="8.2",[19]="7.4",[20]="6.7",[21]="6.0",[22]="5.5",[23]="5.0",[24]="4.6",[25]="4.3",[26]="4.0",[27]="3.7",[28]="3.4",[29]="3.2",[30]="3.0",},[2]={[3]="100",[4]="100",[5]="100",[6]="100",[7]="55",[8]="42",[9]="33",[10]="27",[11]="22",[12]="18.4",[13]="15.6",[14]="13.5",[15]="11.8",[16]="10.4",[17]="9.2",[18]="8.2",[19]="7.4",[20]="6.6",[21]="6.0",[22]="5.5",[23]="5.0",[24]="4.6",[25]="4.3",[26]="3.9",[27]="3.6",[28]="3.4",[29]="3.1",[30]="2.9",},[3]={[4]="100",[5]="100",[6]="100",[7]="53",[8]="40",[9]="32",[10]="25",[11]="21",[12]="17.8",[13]="15.2",[14]="13.2",[15]="11.5",[16]="10.2",[17]="9.1",[18]="8.1",[19]="7.3",[20]="6.6",[21]="6.0",[22]="5.4",[23]="5.0",[24]="4.6",[25]="4.2",[26]="3.9",[27]="3.6",[28]="3.4",[29]="3.1",[30]="2.9",},[4]={[5]="100",[6]="100",[7]="49",[8]="36",[9]="29",[10]="23",[11]="19.4",[12]="16.4",[13]="14.0",[14]="12.2",[15]="10.8",[16]="9.6",[17]="8.6",[18]="7.7",[19]="7.0",[20]="6.3",[21]="5.8",[22]="5.3",[23]="4.8",[24]="4.4",[25]="4.1",[26]="3.8",[27]="3.5",[28]="3.3",[29]="3.0",[30]="2.8",},[5]={[6]="100",[7]="41",[8]="30",[9]="24",[10]="19.5",[11]="16.2",[12]="13.9",[13]="11.9",[14]="10.4",[15]="9.3",[16]="8.3",[17]="7.5",[18]="6.8",[19]="6.2",[20]="5.7",[21]="5.2",[22]="4.8",[23]="4.4",[24]="4.1",[25]="3.8",[26]="3.5",[27]="3.2",[28]="3.0",[29]="2.8",[30]="2.6",},[6]={[7]="16.0",[8]="12.4",[9]="10.5",[10]="9.0",[11]="8.0",[12]="7.3",[13]="6.6",[14]="6.0",[15]="5.5",[16]="5.1",[17]="4.7",[18]="4.4",[19]="4.2",[20]="3.9",[21]="3.6",[22]="3.4",[23]="3.2",[24]="3.0",[25]="2.8",[26]="2.7",[27]="2.5",[28]="2.4",[29]="2.2",[30]="2.1",},}


function widget:GameFrame(frame)
	if frame % 60 ~= 0 then
		return
	end
	for _, converterID in pairs(converters) do
		_,_,energyMake, energyUse = Spring.GetUnitResources(converterID)
		
	end
	local myTeamID = Spring.GetMyTeamID()
	local energy, energyStorage, energyUsed, energyProduced, energyExcess, energyShare, energySent = Spring.GetTeamResources(myTeamID, 'energy')

	local minWind = Game.windMin
	local maxWind = Game.windMax
	
	local avgWindValue = avgWind[minWind]
	if avgWindValue ~= nil then
		avgWindValue=avgWindValue[maxWind]
	end
	if avgWindValue == nil then
		avgWindValue = 0
	end
	
	local eConvertedMax = Spring.GetTeamRulesParam(myTeamID, "mmCapacity")
	local eConverted = Spring.GetTeamRulesParam(myTeamID, "mmUse")
    local mmAvgEffi = Spring.GetTeamRulesParam(myTeamID, "mmAvgEffi")
	local mConverted = eConverted * mmAvgEffi
	
	local energyUsedAtFullConverterCapacity = energyUsed + eConvertedMax - eConverted
	
	--local windStrength = select(4, spGetWind())
	
	local energyFromWind = 0
	for _,unitID in pairs(winds) do
		_,_,energyMake, energyUse = Spring.GetUnitResources(unitID)
		if energyMake ~= nil then
			energyFromWind = energyFromWind + energyMake
		end
	end
	local energyProducedIfAvgWind = energyProduced - energyFromWind + nWinds*(avgWindScalar * avgWindValue + maxWindScalar * maxWind)
	
	
	local recentMaxEnergyUsedAtFullConverterCapacity = nil
    List.pushright(energyUseDeque, energyUsedAtFullConverterCapacity)
    if energyUseDeque.last - energyUseDeque.first >= 3 then
        List.popleft(energyUseDeque)
    end

    if energyUseDeque.last - energyUseDeque.first == 2 then
        local lastThree = {}
        for j = energyUseDeque.first, energyUseDeque.last do
            table.insert(lastThree, energyUseDeque[j])
        end

        if #lastThree == 3 then
            recentMaxEnergyUsedAtFullConverterCapacity = math.max(unpack(lastThree))
        end
    end
	
	if recentMaxEnergyUsedAtFullConverterCapacity == nil then
		return
	end
	
	energyExpectedValue = energyProducedIfAvgWind
	energyExcessExpectedValue = energyProducedIfAvgWind - recentMaxEnergyUsedAtFullConverterCapacity
	actualEnergyExcess = energyProduced - recentMaxEnergyUsedAtFullConverterCapacity
	
	updateUI()
end






