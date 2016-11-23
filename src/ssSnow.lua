---------------------------------------------------------------------------------------------------------
-- SCRIPT TO ADD PHYSICAL SNOW LAYERS
---------------------------------------------------------------------------------------------------------
-- Purpose:  to create plowable snow on the ground
-- Authors:  mrbear
--

ssSnow = {};

function ssSnow.preSetup()
end

function ssSnow.setup()
    addModEventListener(ssSnow)
end

function ssSnow:loadMap(name)
    -- Register Snow as a fill and Tip type
    FillUtil.registerFillType("snow",  g_i18n:getText("fillType_snow"), FillUtil.FILLTYPE_CATEGORY_BULK, 0,  false,  "dataS2/menu/hud/fillTypes/hud_fill_straw.png", "dataS2/menu/hud/fillTypes/hud_fill_straw_sml.png", 0.0002* 0.5, math.rad(50));
    TipUtil.registerDensityMapHeightType(FillUtil.FILLTYPE_SNOW, math.rad(35), 0.8, 0.10, 0.10, 1.20, 3, true, ssSeasonsMod.modDir .. "resources/snow_diffuse.dds", ssSeasonsMod.modDir .. "resources/snow_normal.dds", ssSeasonsMod.modDir .. "resources/snowDistance_diffuse.dds");

    -- General initalization
    g_currentMission.environment:addHourChangeListener(self)
    -- ssSeasonsMod:addSeasonChangeListener(self)

    self.doAddSnow = false; -- Should we currently be running a loop to add Snow on the map.
    self.doRemoveSnow = false;
    self.snowLayersDelta = 0; -- Number of snow layers to add or remove.
    self.appliedSnowDepth = 0; -- ChangeMe @Kuijpers  This variable should be persisted in the savegame.
    
    self.currentX = 0; -- The row that we are currently updating
    self.currentZ = 0; -- The column that we are currently updating
    self.addedSnowForCurrentSnowfall = false; -- Have we already added snow for the current snowfall?
end

function ssSnow:deleteMap()
end

function ssSnow:mouseEvent(posX, posY, isDown, isUp, button)
end

function ssSnow:keyEvent(unicode, sym, modifier, isDown)
end

function ssSnow:draw()
end

function ssSnow:seasonChanged()
    log("Season changed into "..ssSeasonsUtil:seasonName())
end

function ssSnow:hourChanged()

    local targetSnowDepth = 0; -- Target snow depth in meters. Fetch from weatersystem.

    local layerHeight = 0.06; -- Height of one snow layer.
    
    if targetSnowDepth - self.appliedSnowDepth > layerHeight then
        self.snowLayersDelta = math.modf((targetSnowDepth - self.appliedSnowDepth) / layerHeight);
        self.appliedSnowDepth = self.appliedSnowDepth + self.snowLayersDelta * layerHeight;
        self.doAddSnow = true;
        print("Adding: " .. self.snowLayersDelta .. " layers of Snow. Total depth: " .. self.appliedSnowDepth .. " m Requested: " .. targetSnowDepth .. " m" );
    elseif self.appliedSnowDepth - targetSnowDepth > layerHeight then
        self.snowLayersDelta = math.modf((self.appliedSnowDepth - targetSnowDepth) / layerHeight);
        self.appliedSnowDepth = self.appliedSnowDepth - self.snowLayersDelta * layerHeight;
        self.doRemoveSnow = true;
    end;
end

-- Must be defined before call to ssSeasonsUtil:ssIterateOverTerrain where it's used as an argument.
local addSnow = function(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, layers)
    if g_currentMission.terrainDetailHeightId ~= nil then

        local x,z, widthX,widthZ, heightX,heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailHeightId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);

        extraMaskid = g_currentMission.terrainDetailId;
        extraMaskFirstChannel = 0;
        extraMaskNumchannels = 1;

        -- Set snow type where we have no other heaps or painted areas on the map.
        setDensityMaskParams(extraMaskid,"greater",-1); -- noop until we use mask layers
        setDensityCompareParams(g_currentMission.terrainDetailHeightId, "equals",0);
        setDensityMaskedParallelogram(g_currentMission.terrainDetailHeightId, x, z, widthX, widthZ, heightX, heightZ, 0, 5, extraMaskid, extraMaskFirstChannel, extraMaskNumchannels, TipUtil.fillTypeToHeightType[FillUtil.FILLTYPE_SNOW]["index"]);
        setDensityMaskParams(g_currentMission.terrainDetailHeightId, "greater", -1);
        setDensityCompareParams(g_currentMission.terrainDetailHeightId, "greater", -1);

        -- Add snow where type is snow.
        setDensityMaskParams(g_currentMission.terrainDetailHeightId, "equals", TipUtil.fillTypeToHeightType[FillUtil.FILLTYPE_SNOW]["index"]);
        addDensityMaskedParallelogram(g_currentMission.terrainDetailHeightId, x, z, widthX, widthZ, heightX, heightZ, 5, 6, g_currentMission.terrainDetailHeightId, 0, 5, layers);
        setDensityMaskParams(g_currentMission.terrainDetailHeightId, "greater", -1);
    end
end

local removeSnow = function(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, layers)
    if g_currentMission.terrainDetailHeightId ~= nil then

        local x,z, widthX,widthZ, heightX,heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailHeightId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);

        -- Remove snow where type is snow.
        setDensityMaskParams(g_currentMission.terrainDetailHeightId, "equals", TipUtil.fillTypeToHeightType[FillUtil.FILLTYPE_SNOW]["index"]);
        setDensityCompareParams(g_currentMission.terrainDetailHeightId, "greater", 0);
        addDensityMaskedParallelogram(g_currentMission.terrainDetailHeightId, x, z, widthX, widthZ, heightX, heightZ, 5, 6, g_currentMission.terrainDetailHeightId, 0, 5, -layers);
        setDensityMaskParams(g_currentMission.terrainDetailHeightId, "greater", -1);

        -- Remove snow type where we have no snow.
        setDensityMaskParams(g_currentMission.terrainDetailHeightId,"equals",0);
        setDensityCompareParams(g_currentMission.terrainDetailHeightId, "equals",TipUtil.fillTypeToHeightType[FillUtil.FILLTYPE_SNOW]["index"]);
        setDensityMaskedParallelogram(g_currentMission.terrainDetailHeightId, x, z, widthX, widthZ, heightX, heightZ, 0, 5, g_currentMission.terrainDetailHeightId, 5, 6, 0);
        setDensityMaskParams(g_currentMission.terrainDetailHeightId, "greater", -1);
        setDensityCompareParams(g_currentMission.terrainDetailHeightId, "greater", -1);
    end
end

function ssSnow:update(dt)
    if self.doAddSnow == true then
        self.currentX, self.currentZ, self.doAddSnow = ssSeasonsUtil:ssIterateOverTerrain( self.currentX, self.currentZ, addSnow, self.snowLayersDelta);
    elseif self.doRemoveSnow == true then
        self.currentX, self.currentZ, self.doRemoveSnow = ssSeasonsUtil:ssIterateOverTerrain( self.currentX, self.currentZ, removeSnow, self.snowLayersDelta);
    end
end