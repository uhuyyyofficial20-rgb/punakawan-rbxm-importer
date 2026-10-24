--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- Delta | Android | File Scanner
--==============================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

--==============================================================
-- EXECUTOR ENVIRONMENT
--==============================================================

local function findAPI(name)
    local environments = {}

    pcall(function()
        environments[#environments + 1] = getgenv()
    end)

    pcall(function()
        environments[#environments + 1] = getfenv(0)
    end)

    pcall(function()
        environments[#environments + 1] = getfenv()
    end)

    environments[#environments + 1] = _G

    for _, env in ipairs(environments) do
        if type(env) == "table" then
            local ok, value = pcall(function()
                return env[name]
            end)

            if ok and type(value) == "function" then
                return value
            end
        end
    end

    return nil
end

local listfilesAPI = findAPI("listfiles")
local isfolderAPI = findAPI("isfolder")
local isfileAPI = findAPI("isfile")
local readfileAPI = findAPI("readfile")
local getobjectsAPI = findAPI("getobjects")

--==============================================================
-- CLEANUP GUI
--==============================================================

local guiParent

pcall(function()
    guiParent = game:GetService("CoreGui")
end)

if not guiParent then
    guiParent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

pcall(function()
    local old = guiParent:FindFirstChild("PunakawanCommunityImporter")
    if old then
        old:Destroy()
    end
end)

--==============================================================
-- GUI HELPERS
--==============================================================

local function newObject(className, props, parent)
    local obj = Instance.new(className)

    for property, value in pairs(props or {}) do
        pcall(function()
            obj[property] = value
        end)
    end

    obj.Parent = parent
    return obj
end

local function round(obj, radius)
    newObject("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, obj)
end

--==============================================================
-- MAIN GUI
--==============================================================

local gui = newObject("ScreenGui", {
    Name = "PunakawanCommunityImporter",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, guiParent)

local main = newObject("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(370, 450),
    Position = UDim2.new(0.5, -185, 0.5, -225),
    BackgroundColor3 = Color3.fromRGB(24, 22, 31),
    BorderSizePixel = 0
}, gui)

round(main, 12)

local header = newObject("Frame", {
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = Color3.fromRGB(43, 35, 57),
    BorderSizePixel = 0
}, main)

round(header, 12)

newObject("TextLabel", {
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -100, 1, 0),
    BackgroundTransparency = 1,
    Text = "PUNAKAWAN COMMUNITY",
    TextColor3 = Color3.fromRGB(245, 240, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)

local minimizeButton = newObject("TextButton", {
    Position = UDim2.new(1, -70, 0, 7),
    Size = UDim2.fromOffset(27, 27),
    Text = "—",
    TextSize = 17,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(65, 53, 83),
    BorderSizePixel = 0
}, header)

round(minimizeButton, 7)

local closeButton = newObject("TextButton", {
    Position = UDim2.new(1, -36, 0, 7),
    Size = UDim2.fromOffset(27, 27),
    Text = "×",
    TextSize = 19,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(65, 53, 83),
    BorderSizePixel = 0
}, header)

round(closeButton, 7)

local scanButton = newObject("TextButton", {
    Position = UDim2.fromOffset(12, 53),
    Size = UDim2.new(1, -24, 0, 36),
    Text = "SCAN FILES",
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(104, 78, 145),
    BorderSizePixel = 0
}, main)

round(scanButton, 7)

local searchBox = newObject("TextBox", {
    Position = UDim2.fromOffset(12, 97),
    Size = UDim2.new(1, -24, 0, 32),
    PlaceholderText = "Cari nama file...",
    Text = "",
    ClearTextOnFocus = false,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderColor3 = Color3.fromRGB(155, 150, 170),
    BackgroundColor3 = Color3.fromRGB(39, 35, 49),
    BorderSizePixel = 0
}, main)

round(searchBox, 7)

local filterFrame = newObject("Frame", {
    Position = UDim2.fromOffset(12, 137),
    Size = UDim2.new(1, -24, 0, 29),
    BackgroundTransparency = 1
}, main)

local fileList = newObject("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 175),
    Size = UDim2.new(1, -24, 1, -217),
    BackgroundColor3 = Color3.fromRGB(30, 28, 38),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, main)

round(fileList, 8)

newObject("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6)
}, fileList)

newObject("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder
}, fileList)

local statusLabel = newObject("TextLabel", {
    Position = UDim2.new(0, 12, 1, -31),
    Size = UDim2.new(1, -24, 0, 20),
    BackgroundTransparency = 1,
    Text = "Status: Siap",
    TextColor3 = Color3.fromRGB(185, 177, 198),
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left
}, main)

--==============================================================
-- DRAG WINDOW
--==============================================================

local dragging = false
local dragStart
local originalPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        originalPosition = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            originalPosition.X.Scale,
            originalPosition.X.Offset + delta.X,
            originalPosition.Y.Scale,
            originalPosition.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--==============================================================
-- FILE SCANNER
--==============================================================

local PATHS = {
    "Delta/Workspace",
    "Delta\\Workspace",
    "Workspace",
    "workspace",
    "Delta"
}

local files = {}
local selectedFilter = "ALL"

local function normalize(path)
    return tostring(path):gsub("\\", "/")
end

local function getExtension(path)
    local lower = normalize(path):lower()

    if lower:match("%.rbxmx$") then
        return "RBXMX"
    elseif lower:match("%.rbxm$") then
        return "RBXM"
    elseif lower:match("%.rbxlx$") then
        return "RBXLX"
    elseif lower:match("%.rbxl$") then
        return "RBXL"
    end

    return nil
end

local function listDirectory(path)
    if not listfilesAPI then
        return nil
    end

    local ok, result

    if path == nil or path == "" then
        ok, result = pcall(listfilesAPI)
        if not ok then
            ok, result = pcall(listfilesAPI, "")
        end
    else
        ok, result = pcall(listfilesAPI, path)
    end

    if ok and type(result) == "table" then
        return result
    end

    return nil
end

local function clearRows()
    for _, child in ipairs(fileList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function importSelected(file)
    if not readfileAPI then
        statusLabel.Text = "API readfile tidak tersedia."
        return
    end

    local readOK, contents = pcall(readfileAPI, file.path)

    if not readOK or type(contents) ~= "string" then
        statusLabel.Text = "Gagal membaca isi file."
        warn("[PUNAKAWAN] readfile error:", contents)
        return
    end

    if file.extension == "RBXL" or file.extension == "RBXLX" then
        statusLabel.Text = "File place tidak dapat diperlakukan sebagai model."
        return
    end

    if not getobjectsAPI then
        statusLabel.Text = "API getobjects tidak tersedia."
        return
    end

    local loadOK, objects = pcall(getobjectsAPI, file.path)

    if not loadOK then
        statusLabel.Text = "Gagal memuat model dengan getobjects."
        warn("[PUNAKAWAN] getobjects error:", objects)
        return
    end

    if type(objects) ~= "table" or #objects == 0 then
        statusLabel.Text = "Tidak ada objek hasil pemuatan."
        return
    end

    local inserted = 0

    for _, object in ipairs(objects) do
        if typeof(object) == "Instance" then
            local ok = pcall(function()
                object.Parent = workspace
            end)

            if ok then
                inserted += 1
            end
        end
    end

    statusLabel.Text = "Objek dimasukkan: " .. inserted
end

local function refreshList()
    clearRows()

    local query = searchBox.Text:lower()
    local visibleCount = 0

    for _, file in ipairs(files) do
        local matchesFilter =
            selectedFilter == "ALL"
            or file.extension == selectedFilter

        local matchesQuery =
            query == ""
            or file.name:lower():find(query, 1, true) ~= nil

        if matchesFilter and matchesQuery then
            visibleCount += 1

            local row = newObject("Frame", {
                Size = UDim2.new(1, -3, 0, 54),
                BackgroundColor3 = Color3.fromRGB(43, 39, 52),
                BorderSizePixel = 0,
                LayoutOrder = visibleCount
            }, fileList)

            round(row, 7)

            newObject("TextLabel", {
                Position = UDim2.fromOffset(8, 3),
                Size = UDim2.new(1, -88, 0, 26),
                BackgroundTransparency = 1,
                Text = file.name,
                TextColor3 = Color3.fromRGB(246, 242, 255),
                Font = Enum.Font.GothamSemibold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            }, row)

            newObject("TextLabel", {
                Position = UDim2.fromOffset(8, 29),
                Size = UDim2.new(1, -88, 0, 17),
                BackgroundTransparency = 1,
                Text = file.extension,
                TextColor3 = Color3.fromRGB(174, 163, 193),
                Font = Enum.Font.Gotham,
                TextSize = 9,
                TextXAlignment = Enum.TextXAlignment.Left
            }, row)

            local importButton = newObject("TextButton", {
                Position = UDim2.new(1, -76, 0.5, -13),
                Size = UDim2.fromOffset(69, 26),
                Text = "IMPORT",
                TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                BackgroundColor3 = Color3.fromRGB(105, 78, 145),
                BorderSizePixel = 0
            }, row)

            round(importButton, 6)

            importButton.Activated:Connect(function()
                importSelected(file)
            end)
        end
    end

    statusLabel.Text = "Ditemukan: " .. #files
        .. " | Ditampilkan: " .. visibleCount
end

local function scanFiles()
    if not listfilesAPI then
        statusLabel.Text = "listfiles tidak tersedia."
        warn("[PUNAKAWAN] listfiles tidak ditemukan.")
        return
    end

    local found = {}
    local seen = {}

    local function addEntry(path)
        if type(path) ~= "string" then
            return
        end

        local extension = getExtension(path)

        if not extension then
            return
        end

        local normalized = normalize(path)
        local key = normalized:lower()

        if seen[key] then
            return
        end

        seen[key] = true

        found[#found + 1] = {
            path = path,
            name = normalized:match("([^/]+)$") or normalized,
            extension = extension
        }
    end

    -- Coba root terlebih dahulu.
    local rootEntries = listDirectory(nil)

    if rootEntries then
        for _, entry in ipairs(rootEntries) do
            addEntry(entry)
        end
    end

    -- Kemudian coba lokasi yang umum digunakan.
    for _, path in ipairs(PATHS) do
        local entries = listDirectory(path)

        if entries then
            for _, entry in ipairs(entries) do
                addEntry(entry)
            end
        end
    end

    files = found

    table.sort(files, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    refreshList()

    if #files == 0 then
        statusLabel.Text = "Tidak ditemukan. Periksa path Delta."
    end
end

--==============================================================
-- FILTER BUTTONS
--==============================================================

local filters = {"ALL", "RBXM", "RBXMX", "RBXL", "RBXLX"}

for index, filterName in ipairs(filters) do
    local button = newObject("TextButton", {
        Position = UDim2.new((index - 1) * 0.2, 2, 0, 0),
        Size = UDim2.new(0.2, -4, 1, 0),
        Text = filterName,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        BackgroundColor3 = Color3.fromRGB(55, 49, 68),
        BorderSizePixel = 0
    }, filterFrame)

    round(button, 5)

    button.Activated:Connect(function()
        selectedFilter = filterName

        for _, child in ipairs(filterFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 =
                    child.Text == selectedFilter
                    and Color3.fromRGB(105, 78, 145)
                    or Color3.fromRGB(55, 49, 68)
            end
        end

        refreshList()
    end)
end

--==============================================================
-- EVENTS
--==============================================================

scanButton.Activated:Connect(function()
    statusLabel.Text = "Memindai file..."

    task.spawn(function()
        local ok, err = pcall(scanFiles)

        if not ok then
            statusLabel.Text = "Scan error."
            warn("[PUNAKAWAN] Scan error:", err)
        end
    end)
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(refreshList)

local reopenButton = newObject("TextButton", {
    Name = "ReopenButton",
    Position = UDim2.new(0, 16, 0.5, -25),
    Size = UDim2.fromOffset(50, 50),
    Text = "PC",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BackgroundColor3 = Color3.fromRGB(105, 78, 145),
    BorderSizePixel = 0,
    Visible = false
}, gui)

round(reopenButton, 25)

minimizeButton.Activated:Connect(function()
    main.Visible = false
    reopenButton.Visible = true
end)

reopenButton.Activated:Connect(function()
    main.Visible = true
    reopenButton.Visible = false
end)

closeButton.Activated:Connect(function()
    gui:Destroy()
end)

print("[PUNAKAWAN] Importer loaded.")
print("[PUNAKAWAN] Tekan SCAN FILES untuk mencari file.")
