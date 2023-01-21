-- Quick tool for me when not knowing creature_id to butcher

local unit = dfhack.gui.getSelectedUnit(true)

if not dfhack.isMapLoaded() then
    qerror('This tool requires a map to be loaded')
end

if not unit then
    qerror("This tool requires you to have a unit selected")
else
    local creature_id = df.global.world.raws.creatures.all[unit.race].creature_id
    print(('Creature race is %s'):format(creature_id))
end

