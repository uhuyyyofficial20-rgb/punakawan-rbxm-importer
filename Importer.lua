--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- Android | Roblox Studio Lite | Delta
--==============================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")

local APP_NAME = "PUNAKAWAN COMMUNITY IMPORTER"

local EXTENSIONS = {
    RBXM = true,
    RBXMX = true,
    RBXL = true,
    RBXLX = true
}

--==============================================================
-- EXECUTOR API
--==============================================================

local function getAPI(name)
    local environments = {}

    pcall(function()
        table.insert(environments, getgenv())
    end)

    pcall(function()
        table.insert(environments, getfenv())
    end)

    table.insert(environments, _G)

    for _, env in ipairs(environments) do
        if type(env) == "table" then
            local value = rawget(env, name)

            if type(value) == "function" then
                return value
            end
        end
    end

    return nil
end

local listfiles = getAPI("listfiles")
local isfolder = getAPI("isfolder")
local isfile = getAPI("isfile")
local readfile = getAPI("readfile")
local getobjects = getAPI("getobjects")

--==============================================================
-- CLEANUP
--==============================================================

pcall(function()
    local old = CoreGui:FindFirstChild("PunakawanCommunityImporter")
    if old then
        old:Destroy()
    end
end)

--==============================================================
-- GUI HELPERS
--==============================================================

local function create(className, props, parent)
    local obj = Instance.new(className)

    for key, value in pairs(props or {}) do
        pcall(function()
            obj[key] = value
        end)
    end

    obj.Parent = parent
    return obj
end

local function addCorner(obj, radius)
    create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, obj)
end

local function addStroke(obj)
    create("UIStroke", {
        Color = Color3.fromRGB(93, 75, 125),
        Thickness = 1
    }, obj)
end

--==============================================================
-- GUI
--==============================================================

local gui = create("ScreenGui", {
    Name = "PunakawanCommunityImporter",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, CoreGui)

local main = create("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(370, 450),
    Position = UDim2.new(0.5, -185, 0.5, -225),
    BackgroundColor3 = Color3.fromRGB(23, 22, 30),
    BorderSizePixel = 0
}, gui)

addCorner(main, 13)
addStroke(main)

local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, 45),
    BackgroundColor3 = Color3.fromRGB(39, 34, 51),
    BorderSizePixel = 0
}, main)

addCorner(header, 12)

create("TextLabel", {
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -95, 1, 0),
    BackgroundTransparency = 1,
    Text = "PUNAKAWAN COMMUNITY",
    TextColor3 = Color3.fromRGB(245, 240, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)

local minimize = create("TextButton", {
    Position = UDim2.new(1, -72, 0, 7),
    Size = UDim2.fromOffset(28, 28),
    Text = "—",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 17,
    BackgroundColor3 = Color3.fromRGB(61, 52, 77),
    BorderSizePixel = 0
}, header)

addCorner(minimize, 7)

local close = create("TextButton", {
    Position = UDim2.new(1, -37, 0, 7),
    Size = UDim2.fromOffset(28, 28),
    Text = "×",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 20,
    BackgroundColor3 = Color3.fromRGB(61, 52, 77),
    BorderSizePixel = 0
}, header)

addCorner(close, 7)

local scan = create("TextButton", {
    Position = UDim2.fromOffset(12, 55),
    Size = UDim2.new(1, -24, 0, 36),
    Text = "SCAN FILES",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundColor3 = Color3.fromRGB(104, 78, 145),
    BorderSizePixel = 0
}, main)

addCorner(scan, 8)

local search = create("TextBox", {
    Position = UDim2.fromOffset(12, 99),
    Size = UDim2.new(1, -24, 0, 32),
    PlaceholderText = "Cari file...",
    Text = "",
    ClearTextOnFocus = false,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderColor3 = Color3.fromRGB(155, 150, 170),
    BackgroundColor3 = Color3.fromRGB(38, 35, 47),
    BorderSizePixel = 0
}, main)

addCorner(search, 7)

local filters = create("Frame", {
    Position = UDim2.fromOffset(12, 140),
    Size = UDim2.new(1, -24, 0, 30),
    BackgroundTransparency = 1
}, main)

local list = create("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 179),
    Size = UDim2.new(1, -24, 1, -222),
    BackgroundColor3 = Color3.fromRGB(30, 28, 37),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, main)

addCorner(list, 8)

create("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6)
}, list)

create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder
}, list)

local status = create("TextLabel", {
    Position = UDim2.new(0, 12, 1, -31),
    Size = UDim2.new(1, -24, 0, 20),
    BackgroundTransparency = 1,
    Text = "Status: Siap",
    TextColor3 = Color3.fromRGB(180, 174, 195),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, main)

--==============================================================
-- DRAG
--==============================================================

local dragging = false
local dragStart
local startPosition

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
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
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--==============================================================
-- FILE SCANNER
--==============================================================

local searchPaths = {
    "Delta/Workspace",
    "Delta\\Workspace",
    "Workspace",
    "workspace",
    "Delta"
}

local files = {}
local activeFilter = "ALL"

local function normalize(path)
    return tostring(path):gsub("\\", "/")
end

local function extensionOf(path)
    local lower = normalize(path):lower()

    if lower:match("%.rbxm$") then
        return "RBXM"
    elseif lower:match("%.rbxmx$") then
        return "RBXMX"
    elseif lower:match("%.rbxl$") then
        return "RBXL"
    elseif lower:match("%.rbxlx$") then
        return "RBXLX"
    end

    return nil
end

local function clearList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function importFile(file)
    -- File selection and reading are separate from model loading.
    if not readfile then
        status.Text = "Gagal: API readfile tidak tersedia."
        return
    end

    local readOK, contents = pcall(readfile, file.path)

    if not readOK or type(contents) ~= "string" then
        status.Text = "Gagal membaca file."
        warn("[PUNAKAWAN] readfile gagal:", contents)
        return
    end

    print("[PUNAKAWAN] File terbaca:", file.name)
    print("[PUNAKAWAN] Ukuran data:", #contents)

    if file.extension == "RBXL" or file.extension == "RBXLX" then
        status.Text = "File place terdeteksi; bukan model biasa."
        return
    end

    if not getobjects then
        status.Text = "Gagal: API getobjects tidak tersedia."
        return
    end

    -- This tests whether the executor can load a local model.
    -- It deliberately does not claim success or insert unverified data.
    local loadOK, result = pcall(getobjects, file.path)

    if not loadOK then
        status.Text = "API getobjects gagal memuat file."
        warn("[PUNAKAWAN] getobjects error:", result)
        return
    end

    if type(result) ~= "table" then
        status.Text = "Hasil getobjects bukan daftar objek."
        return
    end

    if #result == 0 then
        status.Text = "File terbaca, tetapi tidak ada objek hasil pemuatan."
        return
    end

    -- Insert only objects returned by the supported loading function.
    local inserted = 0

    for _, object in ipairs(result) do
        if typeof(object) == "Instance" then
            local ok = pcall(function()
                object.Parent = workspace
            end)

            if ok then
                inserted += 1
            end
        end
    end

    status.Text = "Objek dimasukkan: " .. inserted
end

local function refresh()
    clearList()

    local query = search.Text:lower()
    local count = 0

    for _, file in ipairs(files) do
        local filterMatches =
            activeFilter == "ALL"
            or file.extension == activeFilter

        local searchMatches =
            query == ""
            or file.name:lower():find(query, 1, true) ~= nil

        if filterMatches and searchMatches then
            count += 1

            local row = create("Frame", {
                Size = UDim2.new(1, -3, 0, 55),
                BackgroundColor3 = Color3.fromRGB(42, 39, 51),
                BorderSizePixel = 0,
                LayoutOrder = count
            }, list)

            addCorner(row, 7)

            create("TextLabel", {
                Position = UDim2.fromOffset(8, 4),
                Size = UDim2.new(1, -90, 0, 24),
                BackgroundTransparency = 1,
                Text = file.name,
                TextColor3 = Color3.fromRGB(246, 243, 255),
                Font = Enum.Font.GothamSemibold,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            }, row)

            create("TextLabel", {
                Position = UDim2.fromOffset(8, 28),
                Size = UDim2.new(1, -90, 0, 20),
                BackgroundTransparency = 1,
                Text = file.extension,
                TextColor3 = Color3.fromRGB(175, 164, 195),
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left
            }, row)

            local importButton = create("TextButton", {
                Position = UDim2.new(1, -75, 0.5, -13),
                Size = UDim2.fromOffset(68, 26),
                Text = "IMPORT",
                TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.GothamBold,
                TextSize = 10,
                BackgroundColor3 = Color3.fromRGB(105, 78, 145),
                BorderSizePixel = 0
            }, row)

            addCorner(importButton, 6)

            importButton.Activated:Connect(function()
                importFile(file)
            end)
        end
    end

    status.Text = "File ditemukan: " .. #files .. " | Ditampilkan: " .. count
end

--==============================================================
-- FILTERS
--==============================================================

local filterNames = {"ALL", "RBXM", "RBXMX", "RBXL", "RBXLX"}

for index, filterName in ipairs(filterNames) do
    local button = create("TextButton", {
        Position = UDim2.new((index - 1) * 0.2, 2, 0, 0),
        Size = UDim2.new(0.2, -4, 1, 0),
        Text = filterName,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        BackgroundColor3 = Color3.fromRGB(55, 49, 69),
        BorderSizePixel = 0
    }, filters)

    addCorner(button, 5)

    button.Activated:Connect(function()
        activeFilter = filterName

        for _, child in ipairs(filters:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 =
                    child.Text == activeFilter
                    and Color3.fromRGB(105, 78, 145)
                    or Color3.fromRGB(55, 49, 69)
            end
        end

        refresh()
    end)
end

--==============================================================
-- SCAN
--==============================================================

local function scanFiles()
    files = {}

    if not listfiles then
        status.Text = "API listfiles tidak tersedia."
        return
    end

    local seen = {}

    local function addFiles(path)
        local ok, result

        if path == "" then
            ok, result = pcall(listfiles)
        else
            ok, result = pcall(listfiles, path)
        end

        if not ok or type(result) ~= "table" then
            return
        end

        for _, item in ipairs(result) do
            if type(item) == "string" then
                local normalized = normalize(item)
                local ext = extensionOf(normalized)
                local key = normalized:lower()

                if ext and not seen[key] then
                    seen[key] = true

                    table.insert(files, {
                        path = item,
                        name = normalized:match("([^/]+)$") or normalized,
                        extension = ext
                    })
                end
            end
        end
    end

    addFiles("")

    for _, path in ipairs(searchPaths) do
        addFiles(path)
    end

    table.sort(files, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    refresh()
end

scan.Activated:Connect(function()
    status.Text = "Memindai file..."

    task.spawn(function()
        local ok, err = pcall(scanFiles)

        if not ok then
            status.Text = "Scan error: " .. tostring(err)
            warn("[PUNAKAWAN] Scan error:", err)
        end
    end)
end)

search:GetPropertyChangedSignal("Text"):Connect(refresh)

local reopen = create("TextButton", {
    Name = "Reopen",
    Position = UDim2.new(0, 15, 0.5, -25),
    Size = UDim2.fromOffset(50, 50),
    Text = "PC",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    BackgroundColor3 = Color3.fromRGB(105, 78, 145),
    BorderSizePixel = 0,
    Visible = false
}, gui)

addCorner(reopen, 25)

minimize.Activated:Connect(function()
    main.Visible = false
    reopen.Visible = true
end)

reopen.Activated:Connect(function()
    main.Visible = true
    reopen.Visible = false
end)

close.Activated:Connect(function()
    gui:Destroy()
end)

print("[PUNAKAWAN] Community Importer loaded.")
print("[PUNAKAWAN] Klik SCAN FILES untuk memulai.")
