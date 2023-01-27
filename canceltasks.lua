-- Cancels all current tasks.
--[====[

canceltasks
========

Removes workers from assigned tasks.
When not possible it removes the task from the task list.

Usage::

    canceltasks

]====]
--@ module = true

local utils = require 'utils'
local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local function cancel_tasks()
    local count = 0
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if dfhack.job.getWorker(job) then
            if not dfhack.job.removeWorker(job, 10) then
                dfhack.job.removeJob(job)
            end
            count = count + 1
        end
    end
    return count
end

local function is_tasks_panel_visible()
    local info = df.global.game.main_interface.info
    return info.open and info.current_mode == df.info_interface_mode_type.JOBS
end

TasksOverlay = defclass(TasksOverlay, overlay.OverlayWidget)
TasksOverlay.ATTRS{
    default_pos={x=-32,y=6},
    default_enabled=true,
    viewscreens='dwarfmode',
    frame={w=20, h=3},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN, 
}

function TasksOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='cancel all',
            key='CUSTOM_CTRL_C',
            on_activate=cancel_tasks,
        }
    }
end

function TasksOverlay:render(dc)
    if not is_tasks_panel_visible() then return false end
    TasksOverlay.super.render(self, dc)
end

function TasksOverlay:onInput(keys)
    if not is_tasks_panel_visible() then return false end
    TasksOverlay.super.onInput(self, keys)
end

OVERLAY_WIDGETS = {
    overlay=TasksOverlay,
}

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    qerror('canceltasks requires a fortress map to be loaded')
end

print(('%d tasks cancelled'):format(cancel_tasks()))
