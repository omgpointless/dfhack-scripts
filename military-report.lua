-- A report of your current military, their skills and equipped weapon.
-- Useful for monitoring training and squad skill ratings.

local gui = require('gui')
local widgets = require('gui.widgets')

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    qerror('military-report requires a fortress map to be loaded')
end

-- Data
local BASE_STATS = {
    soldier_count = 0,
    missing_weapon_count = 0,
    highly_trained_count = 0,
    medium_trained_count = 0,
    low_trained_count = 0,
    badly_trained_count = 0
}
local general_stats = {}
local military_skills = {
    df.job_skill_class.MilitaryWeapon,
    df.job_skill_class.MilitaryUnarmed,
    df.job_skill_class.MilitaryAttack,
    df.job_skill_class.MilitaryDefense,
    df.job_skill_class.MilitaryMisc
}
local squad_entries = {}
local weapon_rating_thresholds = {
    HIGH = df.skill_rating.Legendary,
    MID = df.skill_rating.Accomplished,
    LOW = df.skill_rating.Proficient
}

-- Helpers
local function get_occupant_unit(occupant)
    local unit = nil
    local fig = df.historical_figure.find(occupant)
    if fig then
        unit = df.unit.find(fig.unit_id)
    end
    return unit
end

local function get_squads()
    local squad_list = {}
    for _, squad in pairs(df.global.world.squads.all) do
        for _, position in ipairs(squad.positions) do
            local unit = get_occupant_unit(position.occupant)
            if unit and dfhack.units.isOwnGroup(unit) then
                table.insert(squad_list, squad)
                break
            end
        end
    end
    return squad_list
end

local function get_squad_name(squad)
    local squad_name = dfhack.TranslateName(squad.name, true)
    if squad.alias ~= "" then
        squad_name = squad.alias
    end
    return dfhack.df2utf(squad_name)
end

local function get_unit_name(unit)
    return dfhack.TranslateName(dfhack.units.getVisibleName(unit))
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

local function is_skill_weapon(skill_id, equipped_weapon)
    local result = false

    if equipped_weapon and equipped_weapon:getRangedSkill() ~= -1 then
        result = skill_id == equipped_weapon:getRangedSkill()
    elseif equipped_weapon then
        result = skill_id == equipped_weapon:getMeleeSkill()
    end

    return result
end

function get_item_type_name(item)
    local name = dfhack.items.getSubtypeDef(item:getType(), item:getSubtype()).name
    return name
end

function update_general_stats()
    local stats = copyall(BASE_STATS)
    for _, squad_entry in ipairs(squad_entries) do
        for i, _ in pairs(stats) do
            stats[i] = stats[i] + squad_entry.stats[i]
        end
    end

    return stats
end
-- GUI Helpers
local function add_squad_stats(panel,stats) -- rename function
    table.insert(panel.subviews, widgets.Label{
        text=("%d soldiers"):format(stats.soldier_count),
        auto_width=true,
        frame={l=0, t=2}
    })

    table.insert(panel.subviews, widgets.Label{
        text=("%d without a weapon"):format(stats.missing_weapon_count),
        auto_width=true,
        frame={l=0, t=3}
    })

    table.insert(panel.subviews, widgets.Label{
        text=("%d highly trained"):format(stats.highly_trained_count),
        auto_width=true,
        frame={l=0, t=4}
    })

    table.insert(panel.subviews, widgets.Label{
        text=("%d medium trained"):format(stats.medium_trained_count),
        auto_width=true,
        frame={l=0, t=5}
    })

    table.insert(panel.subviews, widgets.Label{
        text=("%d low trained"):format(stats.low_trained_count),
        auto_width=true,
        frame={l=0, t=6}
    })

    table.insert(panel.subviews, widgets.Label{
        text=("%d badly trained"):format(stats.badly_trained_count),
        auto_width=true,
        frame={l=0, t=7}
    })
    return panel
end

local function add_unit_skills(panel, skills)
    for _, skill in ipairs(skills) do
        local job_skill = df.job_skill.attrs[skill.id]

        local skill_rating = df.skill_rating.attrs[skill.rating]
        if (skill.rating > df.skill_rating.Legendary) then
            skill_rating = df.skill_rating.attrs[df.skill_rating.Legendary]
        end

        local skill_caption = job_skill.caption_noun;
        local list_item = ('%s %s'):format(skill_rating.caption, skill_caption)
        print(list_item)

        --panel:addviews(widgets.Label{
        --    text=(list_item),
        --    auto_width=true,
        --    frame={l=0}
        --})
        -- why does this lag the input?
        --table.insert(panel.subviews, widgets.Label{
        --    text=(list_item),
         --   auto_width=true,
         --   frame={l=0}
        --})
    end
    --view:updateSubviewLayout(panel)
    return panel
end

local function toggle_panel_visibility(wrapper, base_id, selected_id)
    local id = 'all'
    if selected_id ~= -1 then
        id = selected_id
    end
    for _, subview in ipairs(wrapper.subviews) do
        subview.visible = false
    end
    wrapper.subviews[('%s%s'):format(base_id, id)].visible = true
end

local SUB_FRAME_STYLE = copyall(gui.GREY_LINE_FRAME)
SUB_FRAME_STYLE.signature_pen = false

-- Squad view GUI
MilitaryReportSquad = defclass(MilitaryReportSquad, widgets.Window)
MilitaryReportSquad.ATTRS{
    lockable=false,
    frame={l=0, r=0, t=0, b=0},
}

function MilitaryReportSquad:init()
    local unit_panels = {}
    for unitCount = 1, 10 do
        local unit_subviews = {}
        table.insert(unit_subviews, widgets.Label{
            text=('Skills %d'):format(unitCount),
            frame={l=0, t=0},
            auto_width=true,
        })
        local skills_unit_panel = widgets.Panel{
            subviews = unit_subviews,
            view_id = ("skills_unit_%d"):format(unitCount),
            frame={t=0},
            visible=false,
            autoarrange_subviews=true,
        }
        --skills_unit_panel = add_unit_skills(stats_unit_panel)
        table.insert(unit_panels, skills_unit_panel)
    end

    local wrapper_panel = widgets.Panel{
        view_id='wrapper',
        frame={l=0, r=0, t=13, b=0},
        frame_style=SUB_FRAME_STYLE,
        frame_inset = {t=0, l=1, r=1},
        subviews=unit_panels
    }

    local unit_list_panel = widgets.Panel{
        subviews = {
            widgets.Label{
                text='Units',
                frame={l=0, t=0},
                auto_width=true,
            },
            widgets.List{
                view_id='list',
                frame={l=0, t=2},
                on_select=self:callback('view_unit_stats'),
            }
        },
        view_id = "unit_list_panel",
        frame={t=0, h=12},
    }

    self:addviews{
        unit_list_panel,
        wrapper_panel
    }
end

function MilitaryReportSquad:show(choice)
    self.selected_squad = choice.data
    self.visible = true
    -- list, set choices.
    local choices = {}
    print(self.selected_squad)
    for i, u in ipairs(squad_entries[self.selected_squad].units) do
        -- body
        local weapon_name = "none"
        if u.weapon_item then
            weapon_name = get_item_type_name(u.weapon_item)
        end
        table.insert(choices, {text=('%d. %s (%s)'):format(i, u.name, weapon_name), data=i})
        local wrapper = self.subviews.wrapper.subviews[('%s%s'):format('skills_unit_', i)]
        local label_count = #wrapper.subviews
        print(("view_unit_stats, label_count: %d"):format(label_count))
        if label_count == 1 then
            add_unit_skills(wrapper, squad_entries[self.selected_squad].units[i].skills)
            wrapper:updateLayout()
        end
    end
    self.subviews.list:setChoices(choices)
    --self.frame_parent_rect

    --[self.selected_squad].units



    self:setFocus(true)
    self:updateLayout()
end

function MilitaryReportSquad:hide()
    self:setFocus(false)
    self.visible = false
end

function MilitaryReportSquad:onInput(keys)
    print("report squad input")
    if keys.LEAVESCREEN or  keys._MOUSE_R_DOWN then
        self:hide()
    end

    MilitaryReportSquad.super.onInput(self, keys)
    return true
end

function MilitaryReportSquad:view_unit_stats(_, option)
    local pos = option.data
    local wrapper = self.subviews.wrapper
    --print(wrapper)
    toggle_panel_visibility(wrapper, 'skills_unit_', pos)
end



-- Main GUI
MilitaryReport = defclass(MilitaryReport, gui.ZScreen)

function MilitaryReport:init()
    local squad_list_panel = widgets.Panel{
        subviews = {
            widgets.Label{
                text='Squads',
                frame={l=0, t=0},
                auto_width=true,
            },
            widgets.List{
                view_id='list',
                frame={l=0, t=2},
                on_submit=self:callback('view_squad'),
                on_select=self:callback('view_squad_stats'),
            }
        },
        view_id = "squad_list_panel",
        frame={t=0, h=8},
    }

    -- Add panel for "ALL" stats
    local squad_panels = {}
    local squad_stats_all_panel = widgets.Panel{
        subviews = {
            widgets.Label{
                text='ALL',
                frame={l=0, t=0},
                auto_width=true,
            }
        },
        view_id = "stats_squad_all",
        frame={t=0}
    }
    squad_stats_all_panel = add_squad_stats(squad_stats_all_panel, general_stats)
    table.insert(squad_panels, squad_stats_all_panel)

    -- Add stats panel for all squads.
    for i, squad_entry in ipairs(squad_entries) do
        local view_name = (('stats_squad_%s'):format(i))
        local squad_stats_panel = widgets.Panel{
            subviews = {
                widgets.Label{
                    text=('%d. %s'):format(i, squad_entry.name),
                    frame={l=0, t=0},
                    auto_width=true,
                }
            },
            view_id = view_name,
            frame={t=0},
            visible=false
        }
        squad_stats_panel = add_squad_stats(squad_stats_panel, squad_entry.stats)
        table.insert(squad_panels, squad_stats_panel)
    end

    local wrapper_panel = widgets.Panel{
        view_id='wrapper_panel',
        frame={t=9, l=0, r=0, b=2},
        frame_style=SUB_FRAME_STYLE,
        frame_inset = {t=0, l=1, r=1},
        subviews=squad_panels
    }

    local window = widgets.Window{
        frame={w=64, h=32},
        frame_title='Military report',
        resizable=true,
    }

    window:addviews{
        squad_list_panel,
        wrapper_panel,
        MilitaryReportSquad{
            view_id='military_report_squad',
            visible=false,
        },
    }

    self:addviews{window}
end

function MilitaryReport:view_squad(_, option)
    self.subviews.military_report_squad:show(option)
end

function MilitaryReport:view_squad_stats(_, option)
    local wrapper = self.subviews.wrapper_panel
    toggle_panel_visibility(wrapper, 'stats_squad_', option.data)
end

function MilitaryReport:onDismiss()
    view = nil
end

function MilitaryReport:onInput(keys)
   if self:inputToSubviews(keys) then return true end

   if keys.LEAVESCREEN or keys._MOUSE_R_DOWN then
        self:dismiss()
        return true
   end

    MilitaryReport.super.onInput(self, keys)
end

function MilitaryReport:onRenderFrame(dc, rect)
    self:renderParent()
end

function MilitaryReport:postUpdateLayout()
    self:update_squad_list()
end

function MilitaryReport:update_squad_list()
    local items = {}

    local squad_list = get_squads()
    table.insert(items, {text=("ALL"), data=-1})
    for i, squad in ipairs(squad_list) do
        table.insert(items, {text=("%d. %s"):format(i, get_squad_name(squad)), data=i})
    end

    self.subviews.list:setChoices(items)
    self.subviews.list:updateLayout()
end


-- Data gathering methods
local function check_weapon(unit_entry)
    for _, used_item in ipairs(unit_entry.unit.used_items) do
        local item_id = used_item.id
        local item = df.item.find(item_id)
        if item then
            local hu = dfhack.items.getHolderUnit(item)
            if unit_entry.unit == hu and item.flags.in_inventory then
                if item:getType() == df.item_type.WEAPON then
                    unit_entry.weapon_item = item
                    unit_entry.has_weapon = true
                end
            end
        end
    end
    return unit_entry
end

local function add_weapon_rating_stats(rating, squad_entry)
    if rating >= weapon_rating_thresholds.HIGH then
        squad_entry.stats.highly_trained_count = squad_entry.stats.highly_trained_count + 1
    elseif rating >= weapon_rating_thresholds.MID then
        squad_entry.stats.medium_trained_count = squad_entry.stats.medium_trained_count + 1
    elseif rating >= weapon_rating_thresholds.LOW then
        squad_entry.stats.low_trained_count = squad_entry.stats.low_trained_count + 1
    elseif rating >= 0 then
        squad_entry.stats.badly_trained_count = squad_entry.stats.badly_trained_count + 1
    end

    return squad_entry
end

--TODO
--local function get_list_skills(unit_entry)
    --for _, skill in ipairs(skills) do
    --    local job_skill = df.job_skill.attrs[skill.id]

        --local skill_rating = df.skill_rating.attrs[skill.rating]
        --if (skill.rating > df.skill_rating.Legendary) then
        --    skill_rating = df.skill_rating.attrs[df.skill_rating.Legendary]
        --end

        --local skill_caption = job_skill.caption_noun;
        --local list_itemn = ('%s %s'):format(skill_rating.caption, skill_caption)
    --end
--end

local function check_skills(unit_entry)
    local skills = {}

    for _, skill in pairs(unit_entry.unit.status.current_soul.skills) do
        local job_skill = df.job_skill.attrs[skill.id]
        if is_skill_military(job_skill.type) then
            table.insert(skills, skill)
            -- check if weapon is for this skill
            if is_skill_weapon(skill.id, unit_entry.weapon_item) then
                unit_entry.weapon_rating = skill.rating
            end
        end
    end

    table.sort(skills, function (a, b)
        return a.rating > b.rating
    end)

    unit_entry.skills = skills
    return unit_entry
end

local function check_squad(squad)
    local squad_entry = {
        squad = squad,
        name = get_squad_name(squad),
        units = {},
        stats = copyall(BASE_STATS)
    }

    for _, position in ipairs(squad.positions) do
        local unit = get_occupant_unit(position.occupant)
        if unit then
            local unit_entry = {
                unit=unit,
                name=get_unit_name(unit),
                skills={},
                has_weapon=false,
                weapon_item=nil,
                weapon_rating=-1
            }
            -- get unit_entry stuff
            unit_entry = check_weapon(unit_entry)
            if not unit_entry.has_weapon then
                squad_entry.stats.missing_weapon_count = squad_entry.stats.missing_weapon_count + 1
            end
            unit_entry = check_skills(unit_entry)
            squad_entry = add_weapon_rating_stats(unit_entry.weapon_rating, squad_entry)

            table.insert(squad_entry.units, unit_entry)
            squad_entry.stats.soldier_count = squad_entry.stats.soldier_count + 1
        end
    end

    return squad_entry
end

function get_military_report()
    local squad_list = get_squads()
    for _, squad in ipairs(squad_list) do
        local squad_entry = check_squad(squad)
        if squad_entry then
            table.insert(squad_entries, squad_entry)
        end
    end
end

get_military_report()
general_stats = update_general_stats()
view = view or MilitaryReport{}:show()