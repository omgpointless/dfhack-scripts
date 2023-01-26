-- Cancels all current jobs
--[====[

canceljobs
========

Removes workers from assigned jobs.
When not possible it removes the job from the task list.

Usage::

    canceljobs

]====]

local utils = require 'utils'
local job_count = 0

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    qerror('canceljobs requires a fortress map to be loaded')
end

for _, job in utils.listpairs(df.global.world.jobs.list) do
    if dfhack.job.getWorker(job) then
        if not dfhack.job.removeWorker(job, 10) then
            dfhack.job.removeJob(job)
        end
        job_count = job_count + 1
    end
end

print(('%d jobs cancelled'):format(job_count))