-- Cancels all current jobs
--[====[

canceljobs
========

Cancels all jobs/tasks.

Usage::

    canceljobs

]====]
local job_count = 0;

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    qerror('canceljobs requires a fortress map to be loaded')
end

for _, unit in pairs(df.global.world.units.active) do
    if unit.job.current_job then
        dfhack.job.removeJob(unit.job.current_job)
        job_count = job_count + 1
    end
end

print(('%d jobs cancelled'):format(job_count))