-- Delta Executor Decal Installer Tool
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Hapus GUI lama jika sudah pernah dijalankan
if CoreGui:FindFirstChild("DeltaDecalGui") then
    CoreGui.DeltaDecalGui:Destroy()
end

-- Variables State
local selectedPart = nil
local isMinimized = false
local selectingMode = false
local currentFaceIndex = 1
local faces = {"Front", "Back", "Top", "Bottom", "Left", "Right"}
local selectedFace = Enum.NormalId.Front

--------------------------------------------------------------------------------
-- 1. UTILS (Fungsi Helper Draggable untuk Mobile & PC)
--------------------------------------------------------------------------------
local function makeDraggable(topbar, frame)
    local dragging, dragInput, dragStart, startPos
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

--------------------------------------------------------------------------------
-- 2. GUI CREATION
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DeltaDecalGui"
-- Mencoba memasukkan ke CoreGui agar aman dari reset character, jika gagal masuk ke PlayerGui
local success = pcall(function() screenGui.Parent = CoreGui end)
if not success then screenGui.Parent = player:WaitForChild("PlayerGui") end

-- Tombol On/Off Melayang (Toggle UI)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(0, 90, 0, 35)
toggleBtn.Position = UDim2.new(0, 10, 0.3, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
toggleBtn.TextColor3 = Color3.fromRGB(0, 255, 150)
toggleBtn.Text = "Decal UI [ON]"
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 13
toggleBtn.Parent = screenGui

-- Main Frame (Jendela Utama)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 260)
mainFrame.Position = UDim2.new(0.5, -140, 0.3, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Title Bar (Header)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
titleBar.Parent = mainFrame
makeDraggable(titleBar, mainFrame)

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(0.7, 0, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Delta Decal Installer"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Font = Enum.Font.SourceSansBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Tombol Minimize / Maximize
local minMaxBtn = Instance.new("TextButton")
minMaxBtn.Size = UDim2.new(0, 30, 0, 30)
minMaxBtn.Position = UDim2.new(1, -30, 0, 0)
minMaxBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
minMaxBtn.Text = "-"
minMaxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minMaxBtn.Font = Enum.Font.SourceSansBold
minMaxBtn.TextSize = 18
minMaxBtn.Parent = titleBar

-- Content Frame
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, 0, 1, -30)
contentFrame.Position = UDim2.new(0, 0, 0, 30)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

--------------------------------------------------------------------------------
-- 3. INTERFACE ELEMENTS
--------------------------------------------------------------------------------
-- Status Target
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 10)
statusLabel.Text = "Part: Belum Ada"
statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 14
statusLabel.Parent = contentFrame

-- Tombol Pilih Part
local selectPartBtn = Instance.new("TextButton")
selectPartBtn.Size = UDim2.new(1, -20, 0, 30)
selectPartBtn.Position = UDim2.new(0, 10, 0, 35)
selectPartBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
selectPartBtn.Text = "🎯 Pilih / Klik Part di Map"
selectPartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
selectPartBtn.Font = Enum.Font.SourceSansBold
selectPartBtn.Parent = contentFrame

-- Input Box ID Decal
local idBox = Instance.new("TextBox")
idBox.Size = UDim2.new(1, -20, 0, 30)
idBox.Position = UDim2.new(0, 10, 0, 75)
idBox.PlaceholderText = "Tempel ID / Link Decal di sini..."
idBox.Text = ""
idBox.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
idBox.TextColor3 = Color3.fromRGB(255, 255, 255)
idBox.Font = Enum.Font.SourceSans
idBox.Parent = contentFrame

-- Tombol Switch Sisi (Face)
local faceBtn = Instance.new("TextButton")
faceBtn.Size = UDim2.new(1, -20, 0, 30)
faceBtn.Position = UDim2.new(0, 10, 0, 115)
faceBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
faceBtn.Text = "Sisi (Face): Front"
faceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
faceBtn.Font = Enum.Font.SourceSans
faceBtn.Parent = contentFrame

-- Tombol Eksekusi (Pasang)
local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(1, -20, 0, 35)
applyBtn.Position = UDim2.new(0, 10, 0, 155)
applyBtn.BackgroundColor3 = Color3.fromRGB(46, 139, 87)
applyBtn.Text = "✅ PASANG / GANTI DECAL"
applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
applyBtn.Font = Enum.Font.SourceSansBold
applyBtn.TextSize = 15
applyBtn.Parent = contentFrame

--------------------------------------------------------------------------------
-- 4. LOGIC & FUNCTIONALITY
--------------------------------------------------------------------------------
-- Toggle Jendela Utama
toggleBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    toggleBtn.Text = mainFrame.Visible and "Decal UI [ON]" or "Decal UI [OFF]"
end)

-- Minimize / Maximize Window
minMaxBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        contentFrame.Visible = false
        mainFrame.Size = UDim2.new(0, 280, 0, 30)
        minMaxBtn.Text = "+"
    else
        contentFrame.Visible = true
        mainFrame.Size = UDim2.new(0, 280, 0, 205)
        minMaxBtn.Text = "-"
    end
end)

-- Ganti Sisi Part
faceBtn.MouseButton1Click:Connect(function()
    currentFaceIndex = (currentFaceIndex % #faces) + 1
    local faceName = faces[currentFaceIndex]
    selectedFace = Enum.NormalId[faceName]
    faceBtn.Text = "Sisi (Face): " .. faceName
end)

-- Mode Memilih Part
selectPartBtn.MouseButton1Click:Connect(function()
    selectingMode = true
    selectPartBtn.Text = "🔍 Klik Part di Layar..."
    selectPartBtn.BackgroundColor3 = Color3.fromRGB(215, 120, 0)
end)

mouse.Button1Down:Connect(function()
    if selectingMode then
        local target = mouse.Target
        if target and target:IsA("BasePart") then
            selectedPart = target
            statusLabel.Text = "Part: " .. target.Name
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
        else
            statusLabel.Text = "Part: Tidak Valid"
            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
        selectingMode = false
        selectPartBtn.Text = "🎯 Pilih / Klik Part di Map"
        selectPartBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    end
end)

-- Pasang/Ganti Decal
applyBtn.MouseButton1Click:Connect(function()
    if not selectedPart then
        statusLabel.Text = "⚠️ Pilih Part Dulu!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end

    local cleanId = idBox.Text:match("%d+")
    if not cleanId then
        statusLabel.Text = "⚠️ ID Decal Salah!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end

    local textureId = "rbxassetid://" .. cleanId
    local existingDecal = nil

    for _, v in pairs(selectedPart:GetChildren()) do
        if v:IsA("Decal") and v.Face == selectedFace then
            existingDecal = v
            break
        end
    end

    if existingDecal then
        existingDecal.Texture = textureId
    else
        local newDecal = Instance.new("Decal")
        newDecal.Face = selectedFace
        newDecal.Texture = textureId
        newDecal.Parent = selectedPart
    end

    statusLabel.Text = "✅ Berhasil Dipasang!"
    statusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
end)
