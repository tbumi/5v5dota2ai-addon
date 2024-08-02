local Statistics = require "statistics.statistics"

local Match_end_controller = {}

-- end_flag is set to `true` when Match_end_controller:Handle_match_end() is called.
-- If end_flag is `true` then `game_ended` request will not be made,
-- preventing more than 1 match_end per game.
local end_flag = false

-- Runs console command "dota_launch_custom_game dota2ai dota", forcing a restart provided Addon has the name "dota2ai".
local function Restart()
    SendToServerConsole("dota_launch_custom_game dota2ai dota")
end

local function Exit()
    SendToServerConsole("disconnect")
end

-- Informs server of game end.
function Match_end_controller:Handle_match_end(winner)
    if end_flag then
        return
    end

    end_flag = true

    local end_game_stats = Statistics:Collect_end_game(Settings.game_number)
    end_game_stats["winner"] = winner or package.loaded["game/dkjson"].null
    local body = package.loaded["game/dkjson"].encode(end_game_stats)

    ---@type table
    local request = CreateHTTPRequestScriptVM("POST", "http://localhost:8080/api/game_ended")
    request:SetHTTPRequestHeaderValue("Accept", "application/json")
    request:SetHTTPRequestRawPostBody("application/json", body)
    request:Send(
        function(response_json)
        end
    )
    Restart()
end

-- Informs server of restart, then restarts addon.
function Match_end_controller:Handle_restart_game()
    ---@type table
    local request = CreateHTTPRequestScriptVM("POST", "http://localhost:8080/api/restart_game")
    request:Send(
        ---@param response_json table
        function(response_json)
            Restart()
        end
    )
end

-- Restart addon without informing server.
function Match_end_controller:Force_restart()
    Restart()
end

-- Stop game.
function Match_end_controller:Handle_exit()
    Exit()
end

return Match_end_controller