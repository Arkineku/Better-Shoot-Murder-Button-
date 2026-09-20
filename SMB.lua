local shared = odh_shared_plugins

local coreGui = game:GetService("CoreGui")
local players = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local inputService = game:GetService("UserInputService")
local player = players.LocalPlayer
local http = game:GetService("HttpService")

local buttonWidth, buttonHeight = 100, 40
local saveFile = "Packet 3.2 will be never released buddy.json"
local buttonTag = "ShootMurderButton"

local button, scale, buttonPos, oldText
local draggingEnabled, keepGunEnabled, hideText = false, false, false

local gunConnection, gunTask
local tween, tweenConnection
local connections = {}

local dragging, dragInput, startPos, startButtonPos

local function savePosition(pos)
    if writefile then
        pcall(writefile, saveFile, http:JSONEncode({
            X = pos.X.Scale,
            XO = pos.X.Offset,
            Y = pos.Y.Scale,
            YO = pos.Y.Offset
        }))
    end
end

local function loadPosition()
    if isfile and isfile(saveFile) then
        local ok, data = pcall(function()
            return http:JSONDecode(readfile(saveFile))
        end)

        if ok and type(data) == "table" then
            return UDim2.new(data.X, data.XO, data.Y, data.YO)
        end
    end
end

buttonPos = loadPosition()

local function findButton()
    for _, item in ipairs(coreGui:GetDescendants()) do
        if item:IsA("TextButton") and item:GetAttribute(buttonTag) then
            return item
        end
    end

    for _, item in ipairs(coreGui:GetDescendants()) do
        if item:IsA("TextButton") and item.Text:lower():find("shoot murderer", 1, true) then
            item:SetAttribute(buttonTag, true)
            return item
        end
    end
end

local function stopGun()
    if gunConnection then
        gunConnection:Disconnect()
        gunConnection = nil
    end

    if gunTask then
        task.cancel(gunTask)
        gunTask = nil
    end
end

local function keepGun()
    if not keepGunEnabled then return end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local gun

    for _, item in ipairs(player.Backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find("gun", 1, true) then
            gun = item
            break
        end
    end

    if not gun then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("gun", 1, true) then
                gun = item
                break
            end
        end
    end

    if not gun then return end

    stopGun()

    gunConnection = gun.AncestryChanged:Connect(function(_, parent)
        if parent == player.Backpack then
            task.defer(function()
                if humanoid.Parent then
                    humanoid:EquipTool(gun)
                end
            end)
        end
    end)

    gunTask = task.delay(0.3, stopGun)
end

local function animateButton()
    if not scale then return end

    if tweenConnection then
        tweenConnection:Disconnect()
        tweenConnection = nil
    end

    if tween then
        tween:Cancel()
        tween = nil
    end

    scale.Scale = .91

    tween = tweenService:Create(
        scale,
        TweenInfo.new(.65, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
        {Scale = 1}
    )

    tween:Play()

    tweenConnection = tween.Completed:Connect(function()
        tweenConnection = nil
        tween = nil
    end)
end

local function updateSize()
    if not button then return end

    button.Size = UDim2.new(0, buttonWidth, 0, buttonHeight)

    if buttonPos then
        button.Position = buttonPos
    end
end

local function updateText()
    if button then
        button.Text = hideText and "" or oldText
    end
end

local function clearButton()
    if tweenConnection then
        tweenConnection:Disconnect()
        tweenConnection = nil
    end

    if tween then
        tween:Cancel()
        tween = nil
    end

    stopGun()

    dragging = false
    dragInput = nil

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    table.clear(connections)

    if scale then
        scale:Destroy()
        scale = nil
    end

    button = nil
    oldText = nil
end

local function bindButton(newButton)
    if button == newButton then return end

    newButton:SetAttribute(buttonTag, true)
    clearButton()

    button = newButton
    oldText = newButton.Text
    button.AutoButtonColor = false

    updateSize()
    updateText()

    scale = Instance.new("UIScale")
    scale.Parent = button

    connections[#connections + 1] = button.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if draggingEnabled then
            dragging = true
            dragInput = input
            startPos = input.Position
            startButtonPos = button.Position
        else
            keepGun()
            animateButton()
        end
    end)

    connections[#connections + 1] = inputService.InputChanged:Connect(function(input)
        if not draggingEnabled or not dragging or not button then return end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - startPos

        button.Position = UDim2.new(
            startButtonPos.X.Scale,
            startButtonPos.X.Offset + delta.X,
            startButtonPos.Y.Scale,
            startButtonPos.Y.Offset + delta.Y
        )
    end)

    connections[#connections + 1] = inputService.InputEnded:Connect(function(input)
        if not dragging then return end

        if input == dragInput
            or input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = false
            dragInput = nil

            if button then
                buttonPos = button.Position
                savePosition(buttonPos)
            end
        end
    end)

    connections[#connections + 1] = button:GetPropertyChangedSignal("Size"):Connect(function()
        local size = UDim2.new(0, buttonWidth, 0, buttonHeight)

        if button.Size ~= size then
            button.Size = size
        end
    end)

    connections[#connections + 1] = button.AncestryChanged:Connect(function()
        if not button:IsDescendantOf(game) then
            button = nil

            task.defer(function()
                local newButton = findButton()

                if newButton then
                    bindButton(newButton)
                end
            end)
        end
    end)
end

local foundButton = findButton()

if foundButton then
    bindButton(foundButton)
end

coreGui.DescendantAdded:Connect(function(item)
    if item:IsA("TextButton")
        and (item:GetAttribute(buttonTag) or item.Text:lower():find("shoot murderer", 1, true)) then

        task.defer(function()
            bindButton(item)
        end)
    end
end)

local smb_tab = shared.CreateTab("Shoot Murdh", "/axioriasolver/testplugin/refs/heads/main/icon")

local section = smb_tab:AddSection("Shoot Murdh", "")

section:AddLabel("Credits: Arkinigga")

section:AddButton("Save button pos", function()
    if button then
        buttonPos = button.Position
        savePosition(buttonPos)
    end
end)

section:AddButton("Reset pos", function()
    if button then
        buttonPos = UDim2.new(.5, -buttonWidth / 2, .5, -buttonHeight / 2)
        button.Position = buttonPos
        savePosition(buttonPos)
    end
end)

section:AddSlider("Button width X", 40, 300, buttonWidth, function(value)
    buttonWidth = value
    updateSize()
end)

section:AddSlider("Button height Y", 20, 150, buttonHeight, function(value)
    buttonHeight = value
    updateSize()
end)

section:AddToggle("Disable gun auto unequip", function(state)
    keepGunEnabled = state

    if not state then
        stopGun()
    end
end)

section:AddToggle("Drag", function(state)
    draggingEnabled = state
    dragging = false
    dragInput = nil
end)

section:AddToggle("Hide button text", function(state)
    hideText = state
    updateText()
end)
