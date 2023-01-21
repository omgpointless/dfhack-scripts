-- A report of your current military and their skills.
-- Useful for monitoring training and when a squad can be taken off full train.

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    qerror('military-report requires a fortress map to be loaded')
end

local military_skills = {
    df.job_skill_class.MilitaryWeapon,
    df.job_skill_class.MilitaryUnarmed,
    df.job_skill_class.MilitaryAttack,
    df.job_skill_class.MilitaryDefense,
    df.job_skill_class.MilitaryMisc
}

local weapon_rating_thresholds = {
    HIGH = df.skill_rating.Legendary,
    MID = df.skill_rating.Accomplished,
    LOW = df.skill_rating.Proficient
}


local squad_count = 0
local squads = {}
squads.members = {}

local function get_occupant_unit(occupant)
    local unit = nil
    local fig = df.historical_figure.find(occupant)
    if fig then
        unit = df.unit.find(fig.unit_id)
    end

    return unit
end

local function is_skill_military(sc)
    local is_military = false

    for _, skill_class in ipairs(military_skills) do
        if sc == skill_class then
            is_military = true
            break
        end
    end

    return is_military
end

local function is_skill_weapon(sc, equipped_weapon)
    local result = false

    if equipped_weapon then
        result = sc == equipped_weapon:getMeleeSkill() or sc == equipped_weapon:getRangedSkill()
    end

    return result
end

function get_item_type_name(item_type, sub_type)
    return dfhack.items.getSubtypeDef(item_type, sub_type).name
end

local function check_weapon(unit)
    local found_weapon = nil
    for _, used_item in ipairs(unit.used_items) do
        local item_id = used_item.id
        local item = df.item.find(item_id)
        if item then
            local hu = dfhack.items.getHolderUnit(item)
            if unit == hu and item.flags.in_inventory then
                if item:getType() == df.item_type.WEAPON then
                    found_weapon = item
                    print(('Equipped weapon: %s'):format(get_item_type_name(item:getType(), item:getSubtype())))
                end
            end
        end
    end
    return found_weapon
end

local function add_weapon_rating_stats(rating, stats)
    --stats.
    if rating >= weapon_rating_thresholds.HIGH then
        stats.highly_trained_count = stats.highly_trained_count + 1
    elseif rating >= weapon_rating_thresholds.MID then
        stats.medium_trained_count = stats.medium_trained_count + 1
    elseif rating >= weapon_rating_thresholds.LOW then
        stats.low_trained_count = stats.low_trained_count + 1
    else
        stats.badly_trained_count = stats.badly_trained_count + 1
    end

    return stats
end

local function check_skills(unit, equipped_weapon, stats)
    local skills = {}

    for _, skill in pairs(unit.status.current_soul.skills) do
        local job_skill = df.job_skill.attrs[skill.id]

        if is_skill_military(job_skill.type) then
            table.insert(skills, skill)

            -- check if weapon is for this skill
            if is_skill_weapon(skill.id, equipped_weapon) then
                print(("Weapon skill rating: %s"):format(skill.rating))
                stats = add_weapon_rating_stats(skill.rating, stats)
            end
        end
    end

    table.sort(skills, function (a, b)
        return a.rating > b.rating
    end)

    print("")
    print("Skills:")

    for _, skill in ipairs(skills) do
        local job_skill = df.job_skill.attrs[skill.id]

        local skill_rating = df.skill_rating.attrs[skill.rating]
        if (skill.rating > df.skill_rating.Legendary) then
            skill_rating = df.skill_rating.attrs[df.skill_rating.Legendary]
        end

        local skill_caption = job_skill.caption_noun;
        print(('%s %s'):format(skill_rating.caption, skill_caption))
    end

    print("")
    return stats
end

local function check_unit(i, unit)
    local name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
    print('')
    print(('%d. %s'):format(i, name))
end

local function check_squad(squad)
    local stats = {
        soldier_count = 0,
        missing_weapon_count = 0,
        highly_trained_count = 0,
        medium_trained_count = 0,
        low_trained_count = 0,
        badly_trained_count = 0}
    local squad_item = {squad = squad, units = {}}

    local squad_name = dfhack.TranslateName(squad.name, true)
    if squad.alias ~= "" then
        squad_name = squad.alias
    end
    squad_name = dfhack.df2utf(squad_name)

    for _, position in ipairs(squad.positions) do
        local unit = get_occupant_unit(position.occupant)
        if unit then
            table.insert(squad_item.units, unit)
            stats.soldier_count = stats.soldier_count + 1
        end
    end

    table.insert(squads, squad_item)
    print('')
    print(('Checking squad #%d %s...%d/10'):format(
        squad_count,
        squad_name,
        stats.soldier_count
    ))

    for i, unit in pairs(squad_item.units) do
        check_unit(i, unit)

        local equipped_weapon = check_weapon(unit)
        if not equipped_weapon then
            stats.missing_weapon_count = stats.missing_weapon_count + 1
        end

        stats = check_skills(unit, equipped_weapon, stats)
    end

    if stats.missing_weapon_count > 0 then
        print("")
        print(("Members without a weapon: %s"):format(stats.missing_weapon_count))
    end
end

-- Look for our squads.
for _, squad in pairs(df.global.world.squads.all) do
    for _, position in ipairs(squad.positions) do
        local unit = get_occupant_unit(position.occupant)

        if unit and dfhack.units.isOwnGroup(unit) then
            squad_count = squad_count + 1
            check_squad(squad)
            break
        end
    end
end
