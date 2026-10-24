--==================================================
-- PUNAKAWAN RBXM IMPORTER
-- Black & Purple Edition
-- Delta Executor -> Roblox Studio Lite
-- File source: Delta/Workspace/
--==================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIGURATION
local CONFIG = {
    Folder = "Delta/Workspace/",
    Title = "PUNAKAWAN IMPORTER",
    Extensions = {".rbxm", ".rbxmx", ".rbxl", ".rbxlx"},
}

-- REMOVE OLD GUI
local old = playerGui:FindFirstChild("PunakawanImporter")
if old then
    old:Destroy()
end

-- COLORS
local C = {
    Background = Color3.fromRGB(18, 16, 25),
    Panel = Color3.fromRGB(30, 26, 41),
    Purple = Color3.fromRGB(145, 70, 255),
    PurpleDark = Color3.fromRGB(83, 42, 135),
    White = Color3.fromRGB(245, 242, 255),
    Gray = Color3.fromRGB(170, 163, 187),
    Green = Color3.fromRGB(100, 220, 150),
    Red = Color3.fromRGB(255, 105, 120),
}

local function make(className, props, parent)
    local obj = Instance.new(className)

    for key, value in pairs(props) do
        obj[key] = value
    end

    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    make("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, obj)
end

-- ROOT GUI
local gui = make("ScreenGui", {
    Name = "PunakawanImporter",
    ResetOnSpawn = false,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- MAIN WINDOW
local main = make("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(340, 440),
    Position = UDim2.new(0.5, -170, 0.5, -220),
    BackgroundColor3 = C.Background,
    BorderSizePixel = 0,
}, gui)

corner(main, 14)

make("UIStroke", {
    Color = C.Purple,
    Thickness = 1.5,
    Transparency = 0.15,
}, main)

-- HEADER
local header = make("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 66),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
}, main)

corner(header, 14)

make("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
}, header)

make("TextLabel", {
    Size = UDim2.new(1, -60, 0, 29),
    Position = UDim2.fromOffset(14, 8),
    BackgroundTransparency = 1,
    Text = CONFIG.Title,
    TextColor3 = C.White,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

make("TextLabel", {
    Size = UDim2.new(1, -60, 0, 18),
    Position = UDim2.fromOffset(14, 37),
    BackgroundTransparency = 1,
    Text = "RBXM / RBXL • MOBILE",
    TextColor3 = C.Gray,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local close = make("TextButton", {
    Size = UDim2.fromOffset(32, 32),
    Position = UDim2.new(1, -42, 0, 16),
    BackgroundColor3 = Color3.fromRGB(100, 42, 65),
    Text = "X",
    TextColor3 = C.White,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
}, header)

corner(close)

-- FILE TYPE
make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 23),
    Position = UDim2.fromOffset(12, 76),
    BackgroundTransparency = 1,
    Text = "PILIH FORMAT FILE",
    TextColor3 = C.Gray,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local selectedType = "RBXM"

local function typeButton(text, x)
    return make("TextButton", {
        Size = UDim2.fromOffset(153, 36),
        Position = UDim2.fromOffset(x, 101),
        BackgroundColor3 = C.Panel,
        Text = text,
        TextColor3 = C.White,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
    }, main)
end

local modelButton = typeButton("RBXM / RBXMX", 12)
local placeButton = typeButton("RBXL / RBXLX", 175)

corner(modelButton)
corner(placeButton)

local function setType(value)
    selectedType = value

    modelButton.BackgroundColor3 =
        value == "RBXM" and C.Purple or C.Panel

    placeButton.BackgroundColor3 =
        value == "RBXL" and C.Purple or C.Panel
end

modelButton.MouseButton1Click:Connect(function()
    setType("RBXM")
end)

placeButton.MouseButton1Click:Connect(function()
    setType("RBXL")
end)

-- FILE LIST TITLE
make("TextLabel", {
    Size = UDim2.new(1, -100, 0, 25),
    Position = UDim2.fromOffset(12, 147),
    BackgroundTransparency = 1,
    Text = "DAFTAR FILE",
    TextColor3 = C.White,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local refresh = make("TextButton", {
    Size = UDim2.fromOffset(82, 27),
    Position = UDim2.new(1, -94, 0, 145),
    BackgroundColor3 = C.PurpleDark,
    Text = "REFRESH",
    TextColor3 = C.White,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
}, main)

corner(refresh)

-- SCROLLING FILE LIST
local list = make("ScrollingFrame", {
    Name = "FileList",
    Size = UDim2.new(1, -24, 0, 150),
    Position = UDim2.fromOffset(12, 177),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.Purple,
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, main)

corner(list)

local listLayout = make("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, list)

make("UIPadding", {
    PaddingTop = UDim.new(0, 7),
    PaddingBottom = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7),
}, list)

local selectedFile = nil
local fileButtons = {}

local status = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 34),
    Position = UDim2.fromOffset(12, 335),
    BackgroundTransparency = 1,
    Text = "Status: Menunggu pemeriksaan file.",
    TextColor3 = C.Gray,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local importButton = make("TextButton", {
    Size = UDim2.new(1, -24, 0, 40),
    Position = UDim2.fromOffset(12, 373),
    BackgroundColor3 = C.Purple,
    Text = "IMPORT FILE TERPILIH",
    TextColor3 = C.White,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
}, main)

corner(importButton)

local function setStatus(message, color)
    status.Text = "Status: " .. message
    status.TextColor3 = color or C.Gray
end

local function getFunction(name)
    local ok, fn = pcall(function()
        return getfenv()[name]
    end)

    if ok and type(fn) == "function" then
        return fn
    end

    return nil
end

local function clearList()
    for _, button in ipairs(fileButtons) do
        button:Destroy()
    end

    table.clear(fileButtons)
    selectedFile = nil
end

local function refreshFiles()
    clearList()

    local listfilesFn = getFunction("listfiles")
    local isfileFn = getFunction("isfile")

    if not listfilesFn then
        setStatus("Executor tidak menyediakan listfiles().", C.Red)
        return
    end

    local ok, files = pcall(function()
        return listfilesFn(CONFIG.Folder)
    end)

    if not ok or type(files) ~= "table" then
        setStatus("Folder tidak dapat dibaca: " .. CONFIG.Folder, C.Red)
        return
    end

    local count = 0

    for _, path in ipairs(files) do
        if type(path) == "string" then
            local lower = path:lower()
            local supported = false

            if selectedType == "RBXM" then
                supported =
                    lower:sub(-5) == ".rbxm"
                    or lower:sub(-6) == ".rbxmx"
            else
                supported =
                    lower:sub(-5) == ".rbxl"
                    or lower:sub(-6) == ".rbxlx"
            end

            local valid = true

            if isfileFn then
                local checkOk, result = pcall(isfileFn, path)
                valid = checkOk and result == true
            end

            if supported and valid then
                count += 1

                local name = path:match("([^/\\]+)$") or path

                local button = make("TextButton", {
                    Name = "File_" .. count,
                    Size = UDim2.new(1, -4, 0, 34),
                    BackgroundColor3 = C.Background,
                    Text = "  " .. name,
                    TextColor3 = C.White,
                    TextSize = 11,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    LayoutOrder = count,
                }, list)

                corner(button)

                table.insert(fileButtons, button)

                button.MouseButton1Click:Connect(function()
                    selectedFile = path

                    for _, other in ipairs(fileButtons) do
                        other.BackgroundColor3 = C.Background
                    end

                    button.BackgroundColor3 = C.PurpleDark
                    setStatus("Dipilih: " .. name, C.Green)
                end)
            end
        end
    end

    list.CanvasSize = UDim2.new(
        0, 0, 0, listLayout.AbsoluteContentSize.Y + 15
    )

    if count == 0 then
        setStatus("Tidak ada file " .. selectedType .. " yang ditemukan.", C.Gray)
    else
        setStatus(tostring(count) .. " file ditemukan.", C.Green)
    end
end

refresh.MouseButton1Click:Connect(refreshFiles)

importButton.MouseButton1Click:Connect(function()
    if not selectedFile then
        setStatus("Pilih file terlebih dahulu.", C.Red)
        return
    end

    local readfileFn = getFunction("readfile")

    if not readfileFn then
        setStatus("Executor tidak menyediakan readfile().", C.Red)
        return
    end

    local ok, data = pcall(function()
        return readfileFn(selectedFile)
    end)

    if not ok or type(data) ~= "string" then
        setStatus("File tidak dapat dibaca.", C.Red)
        return
    end

    -- File contents are read, but no RBXM/RBXL parser
    -- is included in this GUI.
    setStatus(
        "File terbaca (" .. #data ..
        " byte), tetapi parser impor belum tersedia.",
        C.Gray
    )
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- DRAG WINDOW
local dragging = false
local dragStart
local startPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

refreshFiles()
