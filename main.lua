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
    game.x1 = config.x1 or -1
    game.z1 = config.z1 or -1
    game.x2 = config.x2 or 1
    game.z2 = config.z2 or 1
    return game
end

function newBarricade(window, config)
    local barricade = {}
    barricade.type = "barricade"
    barricade.window = window
    barricade.window.barricade = barricade
    barricade.x = barricade.window.x
    barricade.y = barricade.window.y
    barricade.z = barricade.window.z
    barricade.imageName = barricade.window.barricadeImageName
    table.insert(game.entities, barricade)
    return barricade
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
    zombie.state = config.state or "standing"
    zombie.spawnTime = config.spawnTime or 1
    zombie.currentSpawnTime = zombie.spawnTime
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
    window.barricadeImageName = config.barricadeImageName
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

    survivor.x = math.max(survivor.x, game.x1)
    survivor.x = math.min(survivor.x, game.x2)
    survivor.z = math.max(survivor.z, game.z1)
    survivor.z = math.min(survivor.z, game.z2)
end

function updateWindow(game, window)
    if not window.barricade then
        window.currentSpawnTime = window.currentSpawnTime - game.dt

        if window.currentSpawnTime < 0 then
            window.currentSpawnTime = window.spawnTime

            newZombie(game, {
                x = window.x,
                y = window.y,
                z = window.z,
                state = "spawning",
                spawnTime = 0.5,
            })
        end
    end
end

function updateZombie(game, zombie)
    if zombie.state == "spawning" then
        zombie.currentSpawnTime = zombie.currentSpawnTime - game.dt
        zombie.alpha = math.min(1 - zombie.currentSpawnTime / zombie.spawnTime, 1)

        if zombie.currentSpawnTime < 0 then
            zombie.state = "standing"
        end
    end
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

function drawBarricade(game, barricade)
    local image = game.images[barricade.imageName]
    local width, height = image:getDimensions()

    love.graphics.draw(image, barricade.x, barricade.y + barricade.z,
        0, game.imageScale, game.imageScale, 0.5 * width, 0.5 * height)
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
    love.graphics.setColor(255, 255, 255, zombie.alpha * 255)

    love.graphics.draw(zombie.image, zombie.x, zombie.y + zombie.z, 0,
        zombie.directionX * game.imageScale, game.imageScale,
        0.5 * width, 0.5 * height)

    love.graphics.setColor(255, 255, 255, 255)
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
        x1 = -8,
        z1 = -2.5,
        x2 = 8,
        z2 = 6,
    })

    game.updateHandlers.fireplace = updateFireplace
    game.updateHandlers.survivor = updateSurvivor
    game.updateHandlers.zombie = updateZombie
    game.updateHandlers.window = updateWindow
    game.drawHandlers.barricade = drawBarricade
    game.drawHandlers.fireplace = drawFireplace
    game.drawHandlers.survivor = drawSurvivor
    game.drawHandlers.zombie = drawZombie
    game.images.background = loadImage("resources/images/background.png")
    game.images.fireParticle = loadImage("resources/images/fire-particle.png")
    game.images.leftBottomBarricade = loadImage("resources/images/left-bottom-barricade.png")
    game.images.leftTopBarricade = loadImage("resources/images/left-top-barricade.png")
    game.images.survivor = loadImage("resources/images/survivor.png")
    game.images.rightBottomBarricade = loadImage("resources/images/right-bottom-barricade.png")
    game.images.rightTopBarricade = loadImage("resources/images/right-top-barricade.png")
    game.images.topLeftBarricade = loadImage("resources/images/top-left-barricade.png")
    game.images.topRightBarricade = loadImage("resources/images/top-right-barricade.png")
    game.images.zombie = loadImage("resources/images/zombie.png")

    newFireplace(game, {
        x = 0,
        y = -0.5,
        z = -3,
    })

    local leftBottomWindow = newWindow(game, {
        x = -9.5,
        y = -1.5,
        z = 4.5,
        barricadeImageName = "leftBottomBarricade",
    })

    local leftTopWindow = newWindow(game, {
        x = -9.5,
        y = -1.5,
        z = 0,
        barricadeImageName = "leftTopBarricade",
    })

    local topLeftWindow = newWindow(game, {
        x = -6.5,
        y = -1.5,
        z = -3.5,
        barricadeImageName = "topLeftBarricade",
    })

    local topRightWindow = newWindow(game, {
        x = 6.5,
        y = -1.5,
        z = -3.5,
        barricadeImageName = "topRightBarricade",
    })

    local rightTopWindow = newWindow(game, {
        x = 9.5,
        y = -1.5,
        z = 0,
        barricadeImageName = "rightTopBarricade",
    })

    local rightBottomWindow = newWindow(game, {
        x = 9.5,
        y = -1.5,
        z = 4.5,
        barricadeImageName = "rightBottomBarricade",
    })

    newBarricade(leftBottomWindow, {})
    newBarricade(leftTopWindow, {})
    newBarricade(topLeftWindow, {})
    newBarricade(topRightWindow, {})
    newBarricade(rightTopWindow, {})
    newBarricade(rightBottomWindow, {})

    newSurvivor(game, {
        y = -1,
        walkingSpeed = 6,
    })
end

function love.update(dt)
    updateGame(game, dt)
end

function love.draw(dt)
    drawGame(game, dt)
end
