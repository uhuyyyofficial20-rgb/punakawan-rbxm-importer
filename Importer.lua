--==================================================
-- PUNAKAWAN IMPORTER
-- BLACK & PURPLE EDITION
-- GUI + FILE SCANNER + TOGGLE
--==================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==================================================
-- CHECK EXISTING GUI
--==================================================

local existing = playerGui:FindFirstChild("PunakawanImporter")

if existing then
    local main = existing:FindFirstChild("Main")
    local toggle = existing:FindFirstChild("ToggleButton")

    if main then
        main.Visible = true
    end

    if toggle then
        toggle.Visible = false
    end

    return
end

--==================================================
-- CONFIG
--==================================================

local CONFIG = {
    Folder = "Delta/Workspace/",
    Title = "PUNAKAWAN IMPORTER",
}

--==================================================
-- COLORS
--==================================================

local C = {
    Background = Color3.fromRGB(18, 16, 25),
    Panel = Color3.fromRGB(31, 27, 42),
    Purple = Color3.fromRGB(145, 70, 255),
    PurpleDark = Color3.fromRGB(83, 42, 135),
    White = Color3.fromRGB(245, 242, 255),
    Gray = Color3.fromRGB(175, 165, 190),
    Green = Color3.fromRGB(100, 230, 155),
    Red = Color3.fromRGB(255, 105, 120),
}

--==================================================
-- GUI HELPERS
--==================================================

local function create(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

local function addCorner(object, radius)
    create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, object)
end

local function addStroke(object, color, thickness)
    create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
    }, object)
end

--==================================================
-- ROOT GUI
--==================================================

local gui = create("ScreenGui", {
    Name = "PunakawanImporter",
    ResetOnSpawn = false,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

--==================================================
-- MAIN WINDOW
--==================================================

local main = create("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(340, 440),
    Position = UDim2.new(0.5, -170, 0.5, -220),
    BackgroundColor3 = C.Background,
    BorderSizePixel = 0,
}, gui)

addCorner(main, 15)
addStroke(main, C.Purple, 1.5)

--==================================================
-- FLOATING TOGGLE
--==================================================

local toggle = create("TextButton", {
    Name = "ToggleButton",
    Size = UDim2.fromOffset(54, 54),
    Position = UDim2.new(0, 18, 0.5, -27),
    BackgroundColor3 = C.Purple,
    Text = "P",
    TextColor3 = C.White,
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    Visible = false,
}, gui)

addCorner(toggle, 27)
addStroke(toggle, C.White, 1)

--==================================================
-- HEADER
--==================================================

local header = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 66),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
}, main)

addCorner(header, 14)

create("Frame", {
    Size = UDim2.new(1, 0, 0, 14),
    Position = UDim2.new(0, 0, 1, -14),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
}, header)

create("TextLabel", {
    Size = UDim2.new(1, -55, 0, 29),
    Position = UDim2.fromOffset(14, 8),
    BackgroundTransparency = 1,
    Text = CONFIG.Title,
    TextColor3 = C.White,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

create("TextLabel", {
    Size = UDim2.new(1, -55, 0, 18),
    Position = UDim2.fromOffset(14, 37),
    BackgroundTransparency = 1,
    Text = "RBXM / RBXL • MOBILE",
    TextColor3 = C.Gray,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local minimize = create("TextButton", {
    Name = "MinimizeButton",
    Size = UDim2.fromOffset(32, 32),
    Position = UDim2.new(1, -42, 0, 16),
    BackgroundColor3 = Color3.fromRGB(100, 42, 65),
    Text = "—",
    TextColor3 = C.White,
    TextSize = 20,
    Font = Enum.Font.GothamBold,
}, header)

addCorner(minimize)

--==================================================
-- FORMAT SELECTOR
--==================================================

create("TextLabel", {
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

local function makeButton(name, text, position, size, color, parent)
    local button = create("TextButton", {
        Name = name,
        Size = size,
        Position = position,
        BackgroundColor3 = color,
        Text = text,
        TextColor3 = C.White,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
    }, parent or main)

    addCorner(button)
    return button
end

local modelButton = makeButton(
    "RBXMButton",
    "RBXM / RBXMX",
    UDim2.fromOffset(12, 101),
    UDim2.fromOffset(153, 36),
    C.Purple
)

local placeButton = makeButton(
    "RBXLButton",
    "RBXL / RBXLX",
    UDim2.fromOffset(175, 101),
    UDim2.fromOffset(153, 36),
    C.Panel
)

--==================================================
-- FILE LIST
--==================================================

create("TextLabel", {
    Size = UDim2.new(1, -100, 0, 25),
    Position = UDim2.fromOffset(12, 145),
    BackgroundTransparency = 1,
    Text = "DAFTAR FILE",
    TextColor3 = C.White,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local refreshButton = makeButton(
    "RefreshButton",
    "REFRESH",
    UDim2.new(1, -94, 0, 144),
    UDim2.fromOffset(82, 27),
    C.PurpleDark
)

local fileList = create("ScrollingFrame", {
    Name = "FileList",
    Size = UDim2.new(1, -24, 0, 150),
    Position = UDim2.fromOffset(12, 176),
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.Purple,
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, main)

addCorner(fileList)

local layout = create("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, fileList)

create("UIPadding", {
    PaddingTop = UDim.new(0, 7),
    PaddingBottom = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7),
}, fileList)

local selectedFile
local fileButtons = {}

--==================================================
-- STATUS
--==================================================

local status = create("TextLabel", {
    Name = "Status",
    Size = UDim2.new(1, -24, 0, 34),
    Position = UDim2.fromOffset(12, 333),
    BackgroundTransparency = 1,
    Text = "Status: Siap memindai file.",
    TextColor3 = C.Gray,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local function setStatus(message, color)
    status.Text = "Status: " .. message
    status.TextColor3 = color or C.Gray
end

--==================================================
-- FILE SCANNER
--==================================================

local function getExecutorFunction(name)
    local fn

    pcall(function()
        fn = _G[name]
    end)

    if type(fn) == "function" then
        return fn
    end

    if type(getfenv) == "function" then
        pcall(function()
            fn = getfenv(0)[name]
        end)
    end

    if type(fn) == "function" then
        return fn
    end

    return nil
end

local function clearFileList()
    for _, button in ipairs(fileButtons) do
        button:Destroy()
    end

    table.clear(fileButtons)
    selectedFile = nil
end

local function matchesFormat(path)
    local lower = path:lower()

    if selectedType == "RBXM" then
        return lower:match("%.rbxm$") ~= nil
            or lower:match("%.rbxmx$") ~= nil
    end

    return lower:match("%.rbxl$") ~= nil
        or lower:match("%.rbxlx$") ~= nil
end

local function refreshFiles()
    clearFileList()

    local listfilesFn = getExecutorFunction("listfiles")
    local isfileFn = getExecutorFunction("isfile")

    if not listfilesFn then
        setStatus("Executor tidak menyediakan listfiles().", C.Red)
        return
    end

    local ok, files = pcall(function()
        return listfilesFn(CONFIG.Folder)
    end)

    if not ok then
        setStatus("Gagal membaca folder Delta/Workspace/.", C.Red)
        return
    end

    if type(files) ~= "table" then
        setStatus("Hasil pemindaian tidak valid.", C.Red)
        return
    end

    local count = 0

    for _, path in ipairs(files) do
        if type(path) == "string" and matchesFormat(path) then
            local valid = true

            if isfileFn then
                local checkOK, result = pcall(isfileFn, path)
                valid = checkOK and result == true
            end

            if valid then
                count = count + 1

                local name = path:match("([^/\\]+)$") or path

                local button = makeButton(
                    "File_" .. count,
                    "  " .. name,
                    UDim2.new(),
                    UDim2.new(1, -4, 0, 34),
                    C.Background,
                    fileList
                )

                button.LayoutOrder = count
                button.TextXAlignment = Enum.TextXAlignment.Left
                button.Font = Enum.Font.Gotham
                button.TextSize = 11

                table.insert(fileButtons, button)

                button.MouseButton1Click:Connect(function()
                    selectedFile = path

                    for _, item in ipairs(fileButtons) do
                        item.BackgroundColor3 = C.Background
                    end

                    button.BackgroundColor3 = C.PurpleDark
                    setStatus("Dipilih: " .. name, C.Green)
                end)
            end
        end
    end

    fileList.CanvasSize = UDim2.new(
        0, 0, 0, layout.AbsoluteContentSize.Y + 15
    )

    if count == 0 then
        setStatus(
            "File " .. selectedType .. " tidak ditemukan.",
            C.Gray
        )
    else
        setStatus(tostring(count) .. " file ditemukan.", C.Green)
    end
end

modelButton.MouseButton1Click:Connect(function()
    selectedType = "RBXM"
    modelButton.BackgroundColor3 = C.Purple
    placeButton.BackgroundColor3 = C.Panel
    refreshFiles()
end)

placeButton.MouseButton1Click:Connect(function()
    selectedType = "RBXL"
    modelButton.BackgroundColor3 = C.Panel
    placeButton.BackgroundColor3 = C.Purple
    refreshFiles()
end)

refreshButton.MouseButton1Click:Connect(refreshFiles)

--==================================================
-- IMPORT BUTTON
--==================================================

local importButton = makeButton(
    "ImportButton",
    "IMPORT FILE TERPILIH",
    UDim2.fromOffset(12, 373),
    UDim2.new(1, -24, 0, 40),
    C.Purple
)

importButton.MouseButton1Click:Connect(function()
    if not selectedFile then
        setStatus("Pilih file terlebih dahulu.", C.Red)
        return
    end

    local readfileFn = getExecutorFunction("readfile")

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

    setStatus(
        "File terbaca: " .. #data ..
        " byte. Parser impor belum tersedia.",
        C.Gray
    )
end)

--==================================================
-- MINIMIZE AND RESTORE
--==================================================

minimize.MouseButton1Click:Connect(function()
    main.Visible = false
    toggle.Visible = true
end)

toggle.MouseButton1Click:Connect(function()
    main.Visible = true
    toggle.Visible = false
end)

--==================================================
-- DRAG WINDOW
--==================================================

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

--==================================================
-- START
--==================================================

refreshFiles()
