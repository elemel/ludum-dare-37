function mix(x1, x2, t)
    return (1 - t) * x1 + t * x2
end

function clamp(x, x1, x2)
    return math.min(math.max(x, x1), x2)
end

function smoothstep(x1, x2, x)
    local t = clamp((x - x1) / (x2 - x1), 0, 1) 
    return t * t * (3 - 2 * t)
end

function newGame(config)
    local game = {}
    game.aspectRatio = config.aspectRatio or 16 / 9
    game.time = 0
    game.dt = config.dt or 1 / 60
    game.pendingDt = 0
    game.cameraScale = config.cameraScale or 1
    game.imageScale = config.imageScale or 1
    game.entities = {}
    game.images = {}
    game.animations = {}
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
    barricade.active = true
    barricade.window = window
    barricade.window.barricade = barricade
    barricade.window.state = "barricaded"
    barricade.x = barricade.window.x
    barricade.y = barricade.window.y
    barricade.z = barricade.window.z
    barricade.imageName = barricade.window.barricadeImageName
    barricade.destructionTime = 30 * love.math.random()
    table.insert(game.entities, barricade)
    return barricade
end

function newFire(game, config)
    local fire = {}
    fire.type = "fire"
    fire.active = true
    fire.x = config.x or 0
    fire.y = config.y or 0
    fire.z = config.z or 0

    fire.particles =
        love.graphics.newParticleSystem(game.images.fireParticle, 256)

    fire.particles:setParticleLifetime(0.25, 0.75)
    fire.particles:setEmissionRate(512)
    fire.particles:setSizes(game.imageScale)
    fire.particles:setAreaSpread("normal", 1 / 4, 1 / 8)
    fire.particles:setLinearAcceleration(0, -8)
    fire.particles:setLinearDamping(2)

    fire.particles:setColors(
        255, 127, 63, 255,
        127, 63, 0, 255,
        63, 0, 0, 255)

    table.insert(game.entities, fire)
    return fire
end

function newSurvivor(game, config)
    local survivor = {}
    survivor.type = "survivor"
    survivor.active = true
    survivor.x = config.x or 0
    survivor.y = config.y or 0
    survivor.z = config.z or 0
    survivor.radius = config.radius or 1
    survivor.height = config.height or 1
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

function newWindow(game, config)
    local window = {}
    window.type = "window"
    window.active = true
    window.state = config.state or "producing"
    window.x = config.x or 0
    window.y = config.y or 0
    window.z = config.z or 0
    window.rallyingX = config.rallyingX or 0
    window.rallyingY = config.rallyingY or 0
    window.rallyingZ = config.rallyingZ or 0
    window.productionTime = config.productionTime or 1
    window.currentProductionTime = 0
    window.rallyingTime = config.rallyingTime or 1
    window.currentRallyingTime = 0
    window.barricadeImageName = config.barricadeImageName
    window.directionX = config.directionX or 1
    table.insert(game.entities, window)
    return window
end

function newZombie(game, config)
    local zombie = {}
    zombie.type = "zombie"
    zombie.active = true
    zombie.x = config.x or 0
    zombie.y = config.y or 0
    zombie.z = config.z or 0
    zombie.radius = config.radius or 1
    zombie.height = config.height or 1
    zombie.directionX = config.directionX or 1
    zombie.image = game.images.zombie
    zombie.state = config.state or "standing"
    zombie.alpha = config.alpha or 255
    zombie.walkingSpeed = config.walkingSpeed or 1
    zombie.animationTime = 0
    zombie.animationSpeed = 2
    table.insert(game.entities, zombie)
    return zombie
end

function resolveBounds(game, entity)
    entity.x = math.max(entity.x, game.x1)
    entity.x = math.min(entity.x, game.x2)
    entity.z = math.max(entity.z, game.z1)
    entity.z = math.min(entity.z, game.z2)
end

function resolveCollisions(game, entity)
    for i, other in ipairs(game.entities) do
        if other ~= entity and (other.type == "survivor" or other.type == "zombie") then
            local squaredDistance = (other.x - entity.x) ^ 2 + (other.z - entity.z) ^ 2

            if squaredDistance < (entity.radius + other.radius) ^ 2 then
                local distance = math.sqrt(squaredDistance)
                local directionX = (other.x - entity.x) / distance
                local directionZ = (other.z - entity.z) / distance
                entity.x = other.x - directionX * (entity.radius + other.radius)
                entity.z = other.z - directionZ * (entity.radius + other.radius)
            end
        end
    end
end

function updateBarricade(game, barricade)
    barricade.destructionTime = barricade.destructionTime - game.dt

    if barricade.destructionTime < 0 then
        barricade.window.state = "producing"
        barricade.window.currentProductionTime = 0
        barricade.window.barricade = nil
        barricade.window = nil
        barricade.active = false
    end
end

function updateFire(game, fire)
    fire.particles:setPosition(fire.x, fire.y + fire.z)
    fire.particles:update(game.dt)
end

function updateSurvivor(game, survivor)
    local leftInput = love.keyboard.isDown(survivor.leftKey)
    local rightInput = love.keyboard.isDown(survivor.rightKey)
    local upInput = love.keyboard.isDown(survivor.upKey)
    local downInput = love.keyboard.isDown(survivor.downKey)
    local inputX = (rightInput and 1 or 0) - (leftInput and 1 or 0)
    local inputZ = (downInput and 1 or 0) - (upInput and 1 or 0)

    local inputLength = math.sqrt(inputX ^ 2 + inputZ ^ 2)

    if inputLength > 1 then
        inputX = inputX / inputLength
        inputZ = inputZ / inputLength
    end

    if math.abs(inputX) > 0.001 then
        survivor.directionX = (inputX < 0) and -1 or 1
    end

    survivor.x = survivor.x + inputX * survivor.walkingSpeed * game.dt
    survivor.z = survivor.z + inputZ * survivor.walkingSpeed * game.dt

    resolveCollisions(game, survivor)
    resolveBounds(game, survivor)
end

function updateWindow(game, window)
    if window.state == "producing" then
        window.currentProductionTime = window.currentProductionTime - game.dt

        if window.currentProductionTime < 0 then
            window.zombie = newZombie(game, {
                x = window.x,
                y = window.y,
                z = window.z,
                height = 1.75,
                radius = 0.5,
                directionX = window.directionX,
                alpha = 0,
                state = "rallying",
            })

            window.state = "rallying"
            window.currentRallyingTime = window.rallyingTime
        end
    elseif window.state == "rallying" then
        window.currentRallyingTime = window.currentRallyingTime - game.dt
        local t1 = 1 - smoothstep(0.5 * window.rallyingTime, window.rallyingTime, window.currentRallyingTime)
        local t2 = 1 - smoothstep(0, 0.5 * window.rallyingTime, window.currentRallyingTime)
        window.zombie.alpha = mix(0, 255, t1)
        window.zombie.x = mix(window.x, window.rallyingX, t2)
        window.zombie.y = mix(window.y, window.rallyingY, t2)
        window.zombie.z = mix(window.z, window.rallyingZ, t2)

        if window.currentRallyingTime < 0 then
            window.state = "producing"
            window.zombie.x = window.rallyingX
            window.zombie.y = window.rallyingY
            window.zombie.z = window.rallyingZ
            window.zombie.alpha = 255
            window.zombie.state = "standing"
            window.zombie = nil

            window.state = "producing"
            window.currentProductionTime = window.productionTime
        end
    end
end

function findNearestSurvivor(game, zombie)
    local survivor = nil
    local minSquaredDistance = math.huge

    for i, entity in ipairs(game.entities) do
        if entity.type == "survivor" then
            local squaredDistance = (entity.x - zombie.x) ^ 2 + (entity.z - zombie.z) ^ 2

            if squaredDistance < minSquaredDistance then
                survivor = entity
                minSquaredDistance = squaredDistance
            end
        end
    end

    return survivor
end

function updateZombie(game, zombie)
    if zombie.state == "standing" then
        local survivor = findNearestSurvivor(game, zombie)

        if survivor then
            local offsetX = survivor.x - zombie.x
            local offsetZ = survivor.z - zombie.z
            local offsetLength = math.sqrt(offsetX ^ 2 + offsetZ ^ 2)
            local inputX = offsetX / offsetLength
            local inputZ = offsetZ / offsetLength

            if math.abs(inputX) > 0.001 then
                zombie.directionX = (inputX < 0) and -1 or 1
            end

            zombie.x = zombie.x + inputX * zombie.walkingSpeed * game.dt
            zombie.z = zombie.z + inputZ * zombie.walkingSpeed * game.dt
        end

        resolveCollisions(game, zombie)
        resolveBounds(game, zombie)

        zombie.animationTime = zombie.animationTime + zombie.animationSpeed * game.dt
        local animation = game.animations.zombieStanding
        local imageIndex = 1 + math.floor(zombie.animationTime) % #animation
        zombie.image = animation[imageIndex]
    end
end

function updateGame(game, dt)
    game.pendingDt = game.pendingDt + dt

    if game.pendingDt > game.dt then
        game.pendingDt = game.pendingDt - game.dt
        game.time = game.time + game.dt

        for i, entity in ipairs(game.entities) do
            local handler = game.updateHandlers[entity.type]

            if handler then
                handler(game, entity)
            end
        end

        local j = 1

        for i, entity in ipairs(game.entities) do
            if entity.active then
                entity.index = j
                game.entities[j] = entity
                j = j + 1
            end
        end

        while #game.entities >= j do
            table.remove(game.entities)
        end

        table.sort(game.entities, function(a, b) return a.z + 0.001 * a.index < b.z + 0.001 * b.index end)
    end
end

function drawBarricade(game, barricade)
    local image = game.images[barricade.imageName]
    local width, height = image:getDimensions()

    love.graphics.draw(image, barricade.x, barricade.y + barricade.z,
        0, game.imageScale, game.imageScale, 0.5 * width, 0.5 * height)
end

function drawFire(game, fire)
    love.graphics.setBlendMode("add")
    love.graphics.draw(fire.particles)
    love.graphics.setBlendMode("alpha")
end

function drawSurvivor(game, survivor)
    local shadowImage = game.images.survivorShadow
    local shadowWidth, shadowHeight = shadowImage:getDimensions()
    local shadowY = 0

    love.graphics.draw(shadowImage, survivor.x, shadowY + survivor.z, 0,
        survivor.directionX * game.imageScale, game.imageScale,
        0.5 * shadowWidth, 0.5 * shadowHeight)

    local width, height = survivor.image:getDimensions()

    love.graphics.draw(survivor.image, survivor.x, survivor.y + survivor.z, 0,
        survivor.directionX * game.imageScale, game.imageScale,
        0.5 * width, 0.5 * height)
end

function drawZombie(game, zombie)
    local shadowImage = game.images.zombieShadow
    local shadowWidth, shadowHeight = shadowImage:getDimensions()
    local shadowY = 0

    love.graphics.draw(shadowImage, zombie.x, shadowY + zombie.z, 0,
        zombie.directionX * game.imageScale, game.imageScale,
        0.5 * shadowWidth, 0.5 * shadowHeight)

    local width, height = zombie.image:getDimensions()
    love.graphics.setColor(255, 255, 255, zombie.alpha)

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
        fullscreen = true,
    })

    game = newGame({
        cameraScale = 1 / 12,
        imageScale = 1 / 32,
        x1 = -7.75,
        z1 = -2.5,
        x2 = 7.75,
        z2 = 5.75,
    })

    game.updateHandlers.barricade = updateBarricade
    game.updateHandlers.fire = updateFire
    game.updateHandlers.survivor = updateSurvivor
    game.updateHandlers.zombie = updateZombie
    game.updateHandlers.window = updateWindow

    game.drawHandlers.barricade = drawBarricade
    game.drawHandlers.fire = drawFire
    game.drawHandlers.survivor = drawSurvivor
    game.drawHandlers.zombie = drawZombie

    game.images.background = loadImage("resources/images/background.png")
    game.images.fireParticle = loadImage("resources/images/fire-particle.png")
    game.images.leftBottomBarricade = loadImage("resources/images/left-bottom-barricade.png")
    game.images.leftTopBarricade = loadImage("resources/images/left-top-barricade.png")
    game.images.survivor = loadImage("resources/images/survivor.png")
    game.images.survivorShadow = loadImage("resources/images/survivor-shadow.png")
    game.images.rightBottomBarricade = loadImage("resources/images/right-bottom-barricade.png")
    game.images.rightTopBarricade = loadImage("resources/images/right-top-barricade.png")
    game.images.topLeftBarricade = loadImage("resources/images/top-left-barricade.png")
    game.images.topRightBarricade = loadImage("resources/images/top-right-barricade.png")
    game.images.zombie = loadImage("resources/images/zombie.png")
    game.images.zombieShadow = loadImage("resources/images/zombie-shadow.png")
    game.images.zombieStanding1 = loadImage("resources/images/zombie-standing-1.png")
    game.images.zombieStanding2 = loadImage("resources/images/zombie-standing-2.png")

    game.animations.zombieStanding = {
        game.images.zombieStanding1,
        game.images.zombieStanding2,
    }

    newFire(game, {
        x = 0,
        y = -0.5,
        z = -3,
    })

    local leftBottomWindow = newWindow(game, {
        x = -9.5,
        y = -1.5,
        z = 4.5,
        rallyingX = -7.75,
        rallyingY = -0.875,
        rallyingZ = 4.5,
        productionTime = 1,
        rallyingTime = 0.75,
        barricadeImageName = "leftBottomBarricade",
    })

    local leftTopWindow = newWindow(game, {
        x = -9.5,
        y = -1.5,
        z = 0,
        rallyingX = -7.75,
        rallyingY = -0.875,
        rallyingZ = 0.5,
        productionTime = 1,
        rallyingTime = 0.75,
        barricadeImageName = "leftTopBarricade",
    })

    local topLeftWindow = newWindow(game, {
        x = -6,
        y = -1.5,
        z = -3.5,
        rallyingX = -5.5,
        rallyingY = -0.875,
        rallyingZ = -2.5,
        productionTime = 1,
        rallyingTime = 0.75,
        barricadeImageName = "topLeftBarricade",
    })

    local topRightWindow = newWindow(game, {
        x = 6,
        y = -1.5,
        z = -3.5,
        rallyingX = 5.5,
        rallyingY = -0.875,
        rallyingZ = -2.5,
        barricadeImageName = "topRightBarricade",
        directionX = -1,
        productionTime = 1,
        rallyingTime = 0.75,
    })

    local rightTopWindow = newWindow(game, {
        x = 9.5,
        y = -1.5,
        z = 0,
        rallyingX = 7.75,
        rallyingY = -0.875,
        rallyingZ = 0.5,
        barricadeImageName = "rightTopBarricade",
        directionX = -1,
        productionTime = 1,
        rallyingTime = 0.75,
    })

    local rightBottomWindow = newWindow(game, {
        x = 9.5,
        y = -1.5,
        z = 4.5,
        rallyingX = 7.75,
        rallyingY = -0.875,
        rallyingZ = 4.5,
        barricadeImageName = "rightBottomBarricade",
        directionX = -1,
        productionTime = 1,
        rallyingTime = 0.75,
    })

    newBarricade(leftBottomWindow, {})
    newBarricade(leftTopWindow, {})
    newBarricade(topLeftWindow, {})
    newBarricade(topRightWindow, {})
    newBarricade(rightTopWindow, {})
    newBarricade(rightBottomWindow, {})

    newSurvivor(game, {
        y = -0.875,
        height = 1.75,
        radius = 0.5,
        walkingSpeed = 6,
    })
end

function love.update(dt)
    updateGame(game, dt)
end

function love.draw(dt)
    drawGame(game, dt)
end
