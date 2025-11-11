ConfigRewards = {}

ConfigRewards.Stage1 = {
    money = {min = 5000, max = 8000},
    blackMoney = {min = 2000, max = 4000},
    reputation = {min = 10, max = 20},
    items = {
        {name = 'lockpick', count = 2, chance = 30},
        {name = 'phone', count = 1, chance = 10}
    }
}

ConfigRewards.Stage2 = {
    money = {min = 10000, max = 15000},
    blackMoney = {min = 5000, max = 8000},
    reputation = {min = 30, max = 50},
    items = {
        {name = 'lockpick', count = 3, chance = 40},
        {name = 'repairkit', count = 1, chance = 25}
    }
}

ConfigRewards.Stage3 = {
    money = {min = 20000, max = 30000},
    blackMoney = {min = 10000, max = 15000},
    reputation = {min = 50, max = 100},
    items = {
        {name = 'lockpick', count = 5, chance = 50},
        {name = 'repairkit', count = 2, chance = 40}
    }
}

ConfigRewards.FailurePenalty = {
    [1] = 20,
    [2] = 35,
    [3] = 50
}

ConfigRewards.ReputationScaling = {
    enabled = true,
    thresholds = {
        {reputation = 0, multiplier = 1.0},
        {reputation = 100, multiplier = 1.2},
        {reputation = 300, multiplier = 1.5},
        {reputation = 500, multiplier = 2.0}
    }
}

ConfigRewards.SpeedBonus = {
    enabled = true,
    timePercent = 50,
    bonusRep = {min = 5, max = 15},
    bonusMoney = {min = 1000, max = 3000}
}

function ConfigRewards.Calculate(stage, reputation, timeTaken, timeLimit)
    local config = ConfigRewards['Stage' .. stage]
    if not config then return nil end
    
    local multiplier = 1.0
    if ConfigRewards.ReputationScaling.enabled then
        for i = #ConfigRewards.ReputationScaling.thresholds, 1, -1 do
            if reputation >= ConfigRewards.ReputationScaling.thresholds[i].reputation then
                multiplier = ConfigRewards.ReputationScaling.thresholds[i].multiplier
                break
            end
        end
    end
    
    local money = math.random(config.money.min, config.money.max) * multiplier
    local blackMoney = math.random(config.blackMoney.min, config.blackMoney.max) * multiplier
    local rep = math.random(config.reputation.min, config.reputation.max)
    
    if ConfigRewards.SpeedBonus.enabled and timeTaken <= (timeLimit * ConfigRewards.SpeedBonus.timePercent / 100) then
        money = money + math.random(ConfigRewards.SpeedBonus.bonusMoney.min, ConfigRewards.SpeedBonus.bonusMoney.max)
        rep = rep + math.random(ConfigRewards.SpeedBonus.bonusRep.min, ConfigRewards.SpeedBonus.bonusRep.max)
    end
    
    local items = {}
    for _, item in ipairs(config.items) do
        if math.random(100) <= item.chance then
            table.insert(items, {name = item.name, count = item.count})
        end
    end
    
    return {
        money = math.floor(money),
        blackMoney = math.floor(blackMoney),
        reputation = rep,
        items = items
    }
end