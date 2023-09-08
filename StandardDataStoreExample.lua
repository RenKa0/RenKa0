local replicatedStorage = game:GetService("ReplicatedStorage")
local dataStoreService = game:GetService("DataStoreService")
local players = game:GetService("Players")

local dataStore = dataStoreService:GetDataStore("PlayersData")

local shared = replicatedStorage.Shared

local promise = require(shared.Promise)

local profiles = {} -- cache for our data stores

local dataTemplate = {
    Money = 100
}

local function getData(player: Player)
    return promise.new(function(resolve)
        if profiles[player] then
            resolve(profiles[player])
        end

        resolve(dataStore:GetAsync("Player_" .. player.UserId))
    end):catch(function(err)
        warn("Failure getting player " .. player.Name .. " data" .. err)
    end)
end

local function saveData(player: Player, doRemove)
    return promise.new(function(resolve)
        if profiles[player] then
            dataStore:UpdateAsync("Player_" .. player.UserId, function()
                return profiles[player]
            end)

            if doRemove then
                profiles[player] = nil
            end
            resolve()
        else
            resolve()
        end
    end):catch(function(err)
        warn("Error saving player " .. player.Name .. " data " .. err)
    end)
end

local function saveAllPlayersData()
    local promises = {}

    for _, player in players:GetPlayers() do
        table.insert(promises, saveData(player))
    end

    return promise.all(promises)
end

local function onPlayerAdded(player: Player)
    getData(player):andThen(function(data)
        data = data or dataTemplate
        profiles[player] = data -- to make a change we just data.Money += 30 (duh)
    end)

    promise.fromEvent(player.AncestryChanged, function()
        return not player:IsDescendantOf(players)
    end):andThenCall(saveData, player)
end

players.PlayerAdded:Connect(onPlayerAdded)
game:BindToClose(function()
    saveAllPlayersData()
end)
