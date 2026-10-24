--========================================
-- PUNAKAWAN IMPORTER
-- GUI BASE
--========================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer

if not player then
    warn("Punakawan Importer: LocalPlayer tidak tersedia.")
    return
end

local playerGui = player:WaitForChild("PlayerGui")

-- Cegah GUI duplikat
local oldGui = playerGui:FindFirstChild("PunakawanImporter")

if oldGui then
    oldGui.Enabled = true

    local oldMain = oldGui:FindFirstChild("Main")
    if oldMain then
        oldMain.Visible = true
    end

    return
end

--========================================
-- KONFIGURASI
--========================================

local PURPLE = Color3.fromRGB(145, 65, 255)
local DARK = Color3.fromRGB(19, 16, 27)
local PANEL = Color3.fromRGB(34, 28, 45)
local WHITE = Color3.fromRGB(245, 240, 255)
local GRAY = Color3.fromRGB(170, 160, 185)

--========================================
-- PEMBUAT GUI
--========================================

local function create(className, properties, parent)
    local obj = Instance.new(className)

    for property, value in pairs(properties) do
        obj[property] = value
    end

    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    create("UICorner", {
        CornerRadius = UDim.new(0, radius)
    }, obj)
end

--========================================
-- SCREEN GUI
--========================================

local gui = create("ScreenGui", {
    Name = "PunakawanImporter",
    ResetOnSpawn = false,
    DisplayOrder = 999,
}, playerGui)

--========================================
-- MAIN PANEL
--========================================

local main = create("Frame", {
    Name = "Main",
    Size = UDim2.new(0, 340, 0, 390),
    Position = UDim2.new(0.5, -170, 0.5, -195),
    BackgroundColor3 = DARK,
    BorderSizePixel = 0,
}, gui)

corner(main, 16)

create("UIStroke", {
    Color = PURPLE,
    Thickness = 2,
}, main)

--========================================
-- HEADER
--========================================

local header = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 65),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
}, main)

corner(header, 15)

create("TextLabel", {
    Size = UDim2.new(1, -55, 0, 27),
    Position = UDim2.new(0, 14, 0, 8),
    BackgroundTransparency = 1,
    Text = "PUNAKAWAN IMPORTER",
    TextColor3 = WHITE,
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

create("TextLabel", {
    Size = UDim2.new(1, -55, 0, 18),
    Position = UDim2.new(0, 14, 0, 36),
    BackgroundTransparency = 1,
    Text = "RBXM / RBXL • IMPORT TOOL",
    TextColor3 = GRAY,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local minimize = create("TextButton", {
    Name = "Minimize",
    Size = UDim2.new(0, 32, 0, 32),
    Position = UDim2.new(1, -42, 0, 16),
    BackgroundColor3 = Color3.fromRGB(105, 40, 65),
    Text = "—",
    TextColor3 = WHITE,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
}, header)

corner(minimize, 8)

--========================================
-- FORMAT BUTTONS
--========================================

create("TextLabel", {
    Size = UDim2.new(1, -24, 0, 22),
    Position = UDim2.new(0, 12, 0, 76),
    BackgroundTransparency = 1,
    Text = "PILIH FORMAT FILE",
    TextColor3 = GRAY,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local function makeButton(name, text, position, size)
    local button = create("TextButton", {
        Name = name,
        Size = size,
        Position = position,
        BackgroundColor3 = PANEL,
        Text = text,
        TextColor3 = WHITE,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
    }, main)

    corner(button, 9)
    return button
end

local rbxmButton = makeButton(
    "RBXMButton",
    "RBXM / RBXMX",
    UDim2.new(0, 12, 0, 102),
    UDim2.new(0, 153, 0, 38)
)

local rbxlButton = makeButton(
    "RBXLButton",
    "RBXL / RBXLX",
    UDim2.new(0, 175, 0, 102),
    UDim2.new(0, 153, 0, 38)
)

--========================================
-- FILE LIST AREA
--========================================

create("TextLabel", {
    Size = UDim2.new(1, -24, 0, 22),
    Position = UDim2.new(0, 12, 0, 150),
    BackgroundTransparency = 1,
    Text = "DAFTAR FILE",
    TextColor3 = WHITE,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local refresh = makeButton(
    "RefreshButton",
    "REFRESH",
    UDim2.new(1, -94, 0, 146),
    UDim2.new(0, 82, 0, 28)
)

local fileArea = create("Frame", {
    Name = "FileArea",
    Size = UDim2.new(1, -24, 0, 120),
    Position = UDim2.new(0, 12, 0, 177),
    BackgroundColor3 = PANEL,
    BorderSizePixel = 0,
}, main)

corner(fileArea, 10)

local fileText = create("TextLabel", {
    Name = "FileText",
    Size = UDim2.new(1, -16, 1, -16),
    Position = UDim2.new(0, 8, 0, 8),
    BackgroundTransparency = 1,
    Text = "Daftar file belum dimuat.",
    TextColor3 = GRAY,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, fileArea)

--========================================
-- STATUS
--========================================

local status = create("TextLabel", {
    Name = "Status",
    Size = UDim2.new(1, -24, 0, 30),
    Position = UDim2.new(0, 12, 0, 305),
    BackgroundTransparency = 1,
    Text = "Status: GUI siap.",
    TextColor3 = GRAY,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

--========================================
-- IMPORT BUTTON
--========================================

local importButton = makeButton(
    "ImportButton",
    "IMPORT FILE TERPILIH",
    UDim2.new(0, 12, 0, 345),
    UDim2.new(1, -24, 0, 35)
)

--========================================
-- FLOATING OPEN BUTTON
--========================================

local openButton = create("TextButton", {
    Name = "OpenButton",
    Size = UDim2.new(0, 52, 0, 52),
    Position = UDim2.new(0, 18, 0.5, -26),
    BackgroundColor3 = PURPLE,
    Text = "P",
    TextColor3 = WHITE,
    TextSize = 22,
    Font = Enum.Font.GothamBold,
    Visible = false,
}, gui)

corner(openButton, 26)

--========================================
-- GUI CONTROLS
--========================================

minimize.MouseButton1Click:Connect(function()
    main.Visible = false
    openButton.Visible = true
end)

openButton.MouseButton1Click:Connect(function()
    main.Visible = true
    openButton.Visible = false
end)

--========================================
-- FILE SCANNER
--========================================

local selectedFormat = "RBXM"
local selectedFile = nil

local function scanFiles()
    selectedFile = nil

    local listFunction = listfiles

    if type(listFunction) ~= "function" then
        fileText.Text =
            "Filesystem tidak tersedia di executor ini."
        status.Text = "Status: listfiles tidak tersedia."
        status.TextColor3 = Color3.fromRGB(255, 100, 120)
        return
    end

    local ok, result = pcall(function()
        return listFunction("Delta/Workspace/")
    end)

    if not ok or type(result) ~= "table" then
        fileText.Text =
            "Folder gagal dibaca: Delta/Workspace/"
        status.Text = "Status: gagal membaca folder."
        status.TextColor3 = Color3.fromRGB(255, 100, 120)
        return
    end

    local lines = {}

    for _, path in ipairs(result) do
        if type(path) == "string" then
            local lower = path:lower()

            local matches

            if selectedFormat == "RBXM" then
                matches = lower:match("%.rbxm$")
                    or lower:match("%.rbxmx$")
            else
                matches = lower:match("%.rbxl$")
                    or lower:match("%.rbxlx$")
            end

            if matches then
                table.insert(lines, path)
            end
        end
    end

    if #lines == 0 then
        fileText.Text =
            "Tidak ada file " .. selectedFormat ..
            " yang ditemukan di Delta/Workspace/."
        status.Text = "Status: tidak ada file."
        status.TextColor3 = GRAY
        return
    end

    fileText.Text = table.concat(lines, "\n")
    status.Text =
        "Status: " .. #lines ..
        " file ditemukan. Pemilihan file belum diaktifkan."
    status.TextColor3 = Color3.fromRGB(100, 230, 155)
end

rbxmButton.MouseButton1Click:Connect(function()
    selectedFormat = "RBXM"
    rbxmButton.BackgroundColor3 = PURPLE
    rbxlButton.BackgroundColor3 = PANEL
    scanFiles()
end)

rbxlButton.MouseButton1Click:Connect(function()
    selectedFormat = "RBXL"
    rbxlButton.BackgroundColor3 = PURPLE
    rbxmButton.BackgroundColor3 = PANEL
    scanFiles()
end)

refresh.MouseButton1Click:Connect(scanFiles)

importButton.MouseButton1Click:Connect(function()
    status.Text =
        "Status: parser RBXM/RBXL belum tersedia."
    status.TextColor3 = Color3.fromRGB(255, 190, 90)
end)

--========================================
-- START
--========================================

scanFiles()
