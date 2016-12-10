function newGame(config)
    local game = {}
    game.aspectRatio = config.aspectRatio or 16 / 9
    game.dt = config.dt or 1 / 60
    game.pendingDt = 0
    game.cameraScale = config.cameraScale or 1
    game.imageScale = config.imageScale or 1
    game.entities = {}
    game.images = {}
    game.updateHandlers = {}
    game.drawHandlers = {}
    return game
end

function newFireplace(game, config)
    local fireplace = {}
    fireplace.type = "fireplace"
    fireplace.x = config.x or 0
    fireplace.y = config.y or 0
    fireplace.z = config.z or 0

    fireplace.particles =
        love.graphics.newParticleSystem(game.images.fireParticle, 256)

    fireplace.particles:setParticleLifetime(0.25, 0.5)
    fireplace.particles:setEmissionRate(256)
    fireplace.particles:setSizes(game.imageScale)
    fireplace.particles:setAreaSpread("normal", 1 / 4, 1 / 8)
    fireplace.particles:setLinearAcceleration(0, -8)
    fireplace.particles:setLinearDamping(2)
    fireplace.particles:setColors(
        255, 127, 63, 255,
        127, 63, 0, 255,
        63, 0, 0, 255)
    table.insert(game.entities, fireplace)
    return fireplace
end

function newSurvivor(game, config)
    local survivor = {}
    survivor.type = "survivor"
    survivor.x = config.x or 0
    survivor.y = config.y or 0
    survivor.z = config.z or 0
    survivor.width = config.width or 1
    survivor.height = config.height or 1
    survivor.depth = config.depth or 1
    survivor.directionX = config.directionX or 1
    survivor.image = game.images.survivor
    survivor.leftKey = config.leftKey or "a"
    survivor.rightKey = config.rightKey or "d"
    survivor.upKey = config.upKey or "w"
    survivor.downKey = config.downKey or "s"
    survivor.walkingSpeed = config.walkingSpeed or 1
    table.insert(game.entities, survivor)
    return survivor
end

function newZombie(game, config)
    local zombie = {}
    zombie.type = "zombie"
    zombie.x = config.x or 0
    zombie.y = config.y or 0
    zombie.z = config.z or 0
    zombie.width = config.width or 1
    zombie.height = config.height or 1
    zombie.depth = config.depth or 1
    zombie.directionX = config.directionX or 1
    zombie.image = game.images.zombie
    table.insert(game.entities, zombie)
    return zombie
end

function newWindow(game, config)
    local window = {}
    window.type = "window"
    window.x = config.x or 0
    window.y = config.y or 0
    window.z = config.z or 0
    window.spawnTime = config.spawnTime or 1
    window.currentSpawnTime = window.spawnTime
    table.insert(game.entities, window)
    return window
end

function updateFireplace(game, fireplace)
    fireplace.particles:setPosition(fireplace.x, fireplace.y + fireplace.z)
    fireplace.particles:update(game.dt)
end

function updateSurvivor(game, survivor)
    local leftInput = love.keyboard.isDown(survivor.leftKey)
    local rightInput = love.keyboard.isDown(survivor.rightKey)
    local upInput = love.keyboard.isDown(survivor.upKey)
    local downInput = love.keyboard.isDown(survivor.downKey)
    local inputX = (rightInput and 1 or 0) - (leftInput and 1 or 0)
    local inputZ = (downInput and 1 or 0) - (upInput and 1 or 0)

    if inputX ~= 0 then
        survivor.directionX = inputX
    end

    survivor.x = survivor.x + inputX * survivor.walkingSpeed * game.dt
    survivor.z = survivor.z + inputZ * survivor.walkingSpeed * game.dt
end

function updateWindow(game, window)
    window.currentSpawnTime = window.currentSpawnTime - game.dt

    if window.currentSpawnTime < 0 then
        window.currentSpawnTime = window.spawnTime

        newZombie(game, {
            x = window.x,
            y = window.y,
            z = window.z,
        })
    end
end

function updateZombie(game, zombie)
end

function updateGame(game, dt)
    game.pendingDt = game.pendingDt + dt

    if game.pendingDt > game.dt then
        game.pendingDt = game.pendingDt - game.dt

        for i, entity in ipairs(game.entities) do
            local handler = game.updateHandlers[entity.type]

            if handler then
                handler(game, entity)
            end
        end

        table.sort(game.entities, function(a, b) return a.z < b.z end)
    end
end

function drawFireplace(game, fireplace)
    love.graphics.setBlendMode("add")
    love.graphics.draw(fireplace.particles)
    love.graphics.setBlendMode("alpha")
end

function drawSurvivor(game, survivor)
    local width, height = survivor.image:getDimensions()

    love.graphics.draw(survivor.image, survivor.x, survivor.y + survivor.z, 0,
        survivor.directionX * game.imageScale, game.imageScale,
        0.5 * width, 0.5 * height)
end

function drawZombie(game, zombie)
    local width, height = zombie.image:getDimensions()

    love.graphics.draw(zombie.image, zombie.x, zombie.y + zombie.z, 0,
        zombie.directionX * game.imageScale, game.imageScale,
        0.5 * width, 0.5 * height)
end

function drawBackground(game)
    local image = game.images.background
    local width, height = image:getDimensions()
    love.graphics.draw(image, 0, 0, 0, game.imageScale, game.imageScale,
        0.5 * width, 0.5 * height)
end

function drawGame(game)
    love.graphics.push()
    local width, height = love.graphics:getDimensions()
    love.graphics.translate(0.5 * width, 0.5 * height)
    local scale = math.min(width / game.aspectRatio, height) * game.cameraScale
    love.graphics.scale(scale, scale)
    drawBackground(game)

    for i, entity in ipairs(game.entities) do
        local handler = game.drawHandlers[entity.type]

        if handler then
            handler(game, entity)
        end
    end

    love.graphics.pop()
end

function loadImage(path)
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

function love.load()
    love.window.setMode(800, 600, {
        fullscreentype = "desktop",
        resizable = true,
    })

    game = newGame({
        cameraScale = 1 / 12,
        imageScale = 1 / 32,
    })

    game.updateHandlers.fireplace = updateFireplace
    game.updateHandlers.survivor = updateSurvivor
    game.updateHandlers.zombie = updateZombie
    game.updateHandlers.window = updateWindow
    game.drawHandlers.fireplace = drawFireplace
    game.drawHandlers.survivor = drawSurvivor
    game.drawHandlers.zombie = drawZombie
    game.images.background = loadImage("resources/images/background.png")
    game.images.fireParticle = loadImage("resources/images/fire-particle.png")
    game.images.survivor = loadImage("resources/images/survivor.png")
    game.images.zombie = loadImage("resources/images/zombie.png")

    newFireplace(game, {
        x = 0,
        y = -0.5,
        z = -3,
    })

    newWindow(game, {
        x = -9.5,
        y = -1.5,
        z = 4.5,
    })

    newWindow(game, {
        x = -9.5,
        y = -1.5,
        z = 0,
    })

    newWindow(game, {
        x = -6.5,
        y = -1.5,
        z = -3.5,
    })

    newWindow(game, {
        x = 6.5,
        y = -1.5,
        z = -3.5,
    })

    newWindow(game, {
        x = 9.5,
        y = -1.5,
        z = 0,
    })

    newWindow(game, {
        x = 9.5,
        y = -1.5,
        z = 4.5,
    })

    newSurvivor(game, {
        walkingSpeed = 6,
    })
end

function love.update(dt)
    updateGame(game, dt)
end

function love.draw(dt)
    drawGame(game, dt)
end
