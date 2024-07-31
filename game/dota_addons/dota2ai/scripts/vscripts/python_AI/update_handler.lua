-- imports
local Match_end_controller = require "match_end.match_end_controller"
local World_data_builder   = require "python_AI.world_data_builder"
local Statistics           = require "statistics.statistics"



-- restart_flag is set to `true` when restart is forced.
-- If restart_flag is `true` then `Match_end_controller:Force_restart()` will not be attempted,
-- preventing console command buffer full.
local restart_flag = false



-- constants
local RADIANT_UPDATE_ROUTE = "radiant_update"
local DIRE_UPDATE_ROUTE = "dire_update"

local update_in_progress = false
local update_counter = 0


-- Update_handler
local Update_handler = {}

---@param heroes CDOTA_BaseNPC_Hero[]
---@return string
function Update_handler:Get_route(heroes)
    if heroes[1]:GetTeam() == DOTA_TEAM_GOODGUYS then
        return RADIANT_UPDATE_ROUTE
    elseif heroes[1]:GetTeam() == DOTA_TEAM_BADGUYS then
        return DIRE_UPDATE_ROUTE
    end
end

---@param heroes CDOTA_BaseNPC_Hero[]
---@param on_update_callback fun(heroes: CDOTA_BaseNPC_Hero[], commands: table)
function Update_handler:Update(heroes, on_update_callback)
    if update_in_progress then
        return 0.01
    end
    update_in_progress = true

    local radiant_entities = World_data_builder:Get_all_entities(heroes[1])
    local dire_entities = World_data_builder:Get_all_entities(heroes[6])
    local statistics = Statistics:Collect_statistics(
        { unpack(heroes, 1, 5) },
        { unpack(heroes, 6, 10) },
        Settings.game_number
    )
    ---@type table
    local body = package.loaded["game/dkjson"].encode(
        {
            ["radiant_entities"] = radiant_entities,
            ["dire_entities"] = dire_entities,
            ["game_time"] = GameRules:GetDOTATime(false, true),
            ["is_day"] = GameRules:IsDaytime(),
            ["time_of_day"] = GameRules:GetTimeOfDay(),
            ["game_number"] = Settings.game_number,
            ["update_count"] = update_counter,
            ["statistics"] = statistics
        }
    )
    update_counter = update_counter + 1

    ---@type table
    local request = CreateHTTPRequestScriptVM("POST", "http://localhost:8080/api/game_update")
    request:SetHTTPRequestHeaderValue("Accept", "application/json")
    request:SetHTTPRequestRawPostBody("application/json", body)
    request:Send(
        ---@param result table
        function(result)
            if restart_flag then
                return
            end

            if result["StatusCode"] == 406 then
                if Settings.auto_restart_client_on_server_restart then
                    restart_flag = true
                    print("Restarting addon.")
                    Match_end_controller:Force_restart()
                else
                    print("Request update was Not Acceptable! Addon restart needed.")
                end
                Timers:RemoveTimer("UpdateForTeam" .. tostring(heroes[1]:GetTeam()))
                return
            end
            ---@type table
            local commands = package.loaded["game/dkjson"].decode(result["Body"])
            on_update_callback(heroes, commands)
            update_in_progress = false
        end
    )
end

return Update_handler