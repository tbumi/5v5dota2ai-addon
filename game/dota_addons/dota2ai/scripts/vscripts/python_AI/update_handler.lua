-- imports
local Match_end_controller = require "match_end.match_end_controller"
local World_data_builder = require "python_AI.world_data_builder"



-- restart_flag is set to `true` when restart is forced.
-- If restart_flag is `true` then `Match_end_controller:Force_restart()` will not be attempted,
-- preventing console command buffer full.
local restart_flag = false



-- constants
local RADIANT_UPDATE_ROUTE = "radiant_update"
local DIRE_UPDATE_ROUTE = "dire_update"

local update_in_progress = {}
update_in_progress[DOTA_TEAM_GOODGUYS] = false
update_in_progress[DOTA_TEAM_BADGUYS] = false


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
    local team = heroes[1]:GetTeam()
    if update_in_progress[team] then
        return 0.01
    end
    update_in_progress[team] = true

    local entities = World_data_builder:Get_all_entities(heroes[1])
    ---@type table
    local body = package.loaded["game/dkjson"].encode(
        {
            ["entities"] = entities,
            ["game_time"] = GameRules:GetDOTATime(false, true),
            ["game_number"] = Settings.game_number
        }
    )

    local route = self:Get_route(heroes)

    ---@type table
    local request = CreateHTTPRequestScriptVM("POST", "http://localhost:8080/api/" .. route)
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
            update_in_progress[team] = false
        end
    )
end

return Update_handler