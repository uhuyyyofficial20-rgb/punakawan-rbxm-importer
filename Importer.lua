--============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- RBXM / RBXMX
-- GUI + File Scanner + Bottom Right Notification
--============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--============================================================
-- CONFIG
--============================================================

local CONFIG = {
    Title = "PUNAKAWAN COMMUNITY",
    Version = "3.0",

    Background = Color3.fromRGB(24, 20, 36),
    Panel = Color3.fromRGB(37, 30, 53),
    Purple = Color3.fromRGB(133, 75, 220),
    LightPurple = Color3.fromRGB(191, 145, 255),
    Text = Color3.fromRGB(245, 240, 255),
    Muted = Color3.fromRGB(170, 158, 190),

    MaxDepth = 6,

    Roots = {
        "Delta/Workspace",
        "Delta\\Workspace",
        "Delta/Workspace/",
        "Delta\\Workspace\\",
        "Workspace",
        "workspace",
        "Delta",
    },
}

--============================================================
-- EXECUTOR API LOOKUP
--============================================================

local function getAPI(name)
    local environments = {}

    if type(getgenv) == "function" then
        pcall(function()
            table.insert(environments, getgenv())
        end)
    end

    if type(getfenv) == "function" then
        pcall(function()
            table.insert(environments, getfenv())
            table.insert(environments, getfenv(0))
        end)
    end

    table.insert(environments, _G)

    for _, environment in ipairs(environments) do
        if type(environment) == "table" then
            local ok, value = pcall(function()
                return environment[name]
            end)

            if ok and value ~= nil then
                return value
            end
        end
    end

    return nil
end

local listfilesAPI = getAPI("listfiles")
local readfileAPI = getAPI("readfile")
local isfileAPI = getAPI("isfile")
local isfolderAPI = getAPI("isfolder")
local getobjectsAPI = getAPI("getobjects")

--============================================================
-- HELPERS
--============================================================

local function create(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        pcall(function()
            object[property] = value
        end)
    end

    object.Parent = parent
    return object
end

local function normalize(path)
    return tostring(path):gsub("\\", "/")
end

local function isSupported(path)
    local lower = string.lower(tostring(path))

    return lower:match("%.rbxm$") ~= nil
        or lower:match("%.rbxmx$") ~= nil
end

--============================================================
-- SCANNER
--============================================================

local function scanFiles()
    local results = {}
    local seen = {}
    local errors = {}

    if type(listfilesAPI) ~= "function" then
        return results,
            "API listfiles() tidak ditemukan pada lingkungan ini."
    end

    local function add(path)
        if type(path) ~= "string" then
            return
        end

        path = normalize(path)

        if not isSupported(path) then
            return
        end

        local key = string.lower(path)

        if seen[key] then
            return
        end

        if type(isfileAPI) == "function" then
            local ok, exists = pcall(isfileAPI, path)

            if ok and not exists then
                -- Coba versi path asli jika normalisasi berbeda.
                local originalOK, originalExists =
                    pcall(isfileAPI, path:gsub("/", "\\"))

                if originalOK and not originalExists then
                    return
                end
            end
        end

        seen[key] = true
        table.insert(results, path)
    end

    local visitedFolders = {}

    local function scanDirectory(directory, depth)
        if depth > CONFIG.MaxDepth then
            return
        end

        local normalizedDirectory = normalize(directory)
        local directoryKey = string.lower(normalizedDirectory)

        if visitedFolders[directoryKey] then
            return
        end

        visitedFolders[directoryKey] = true

        local ok, entries = pcall(listfilesAPI, directory)

        if not ok or type(entries) ~= "table" then
            table.insert(errors, tostring(directory) .. ": " .. tostring(entries))
            return
        end

        for _, entry in ipairs(entries) do
            if type(entry) == "string" then
                if isSupported(entry) then
                    add(entry)
                elseif type(isfolderAPI) == "function" then
                    local folderOK, isFolder =
                        pcall(isfolderAPI, entry)

                    if folderOK and isFolder then
                        scanDirectory(entry, depth + 1)
                    end
                end
            end
        end
    end

    -- Metode 1: listfiles() tanpa argumen.
    local rootOK, rootEntries = pcall(listfilesAPI)

    if rootOK and type(rootEntries) == "table" then
        for _, entry in ipairs(rootEntries) do
            if type(entry) == "string" then
                if isSupported(entry) then
                    add(entry)
                elseif type(isfolderAPI) == "function" then
                    local folderOK, isFolder =
                        pcall(isfolderAPI, entry)

                    if folderOK and isFolder then
                        scanDirectory(entry, 0)
                    end
                end
            end
        end
    end

    -- Metode 2: direktori umum.
    for _, root in ipairs(CONFIG.Roots) do
        scanDirectory(root, 0)
    end

    table.sort(results, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    if #results == 0 then
        if #errors > 0 then
            return results,
                "Tidak ada file yang ditemukan. Jalur folder tidak dapat dibaca."
        end

        return results,
            "Tidak ditemukan file RBXM/RBXMX pada direktori yang diperiksa."
    end

    return results
end

--============================================================
-- GUI SETUP
--============================================================

local oldGui = PlayerGui:FindFirstChild("PunakawanImporter")

if oldGui then
    oldGui:Destroy()
end

local gui = create("ScreenGui", {
    Name = "PunakawanImporter",
    ResetOnSpawn = false,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

--============================================================
-- NOTIFICATION - BOTTOM RIGHT
--============================================================

local notification = create("Frame", {
    Name = "Notification",
    Size = UDim2.new(0, 260, 0, 60),
    Position = UDim2.new(1, -275, 1, 80),
    BackgroundColor3 = CONFIG.Panel,
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 20,
}, gui)

create("UICorner", {
    CornerRadius = UDim.new(0, 10),
}, notification)

create("UIStroke", {
    Color = CONFIG.Purple,
    Thickness = 1.2,
    Transparency = 0.2,
}, notification)

create("TextLabel", {
    Size = UDim2.new(1, -16, 0, 20),
    Position = UDim2.new(0, 8, 0, 5),
    BackgroundTransparency = 1,
    Text = "PUNAKAWAN IMPORTER",
    TextColor3 = CONFIG.LightPurple,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 21,
}, notification)

local notificationText = create("TextLabel", {
    Size = UDim2.new(1, -16, 0, 29),
    Position = UDim2.new(0, 8, 0, 26),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = CONFIG.Text,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 21,
}, notification)

local notificationId = 0

local function popup(message, duration)
    notificationId = notificationId + 1
    local currentId = notificationId

    notificationText.Text = tostring(message)
    notification.Position = UDim2.new(1, -275, 1, 80)
    notification.Visible = true

    TweenService:Create(
        notification,
        TweenInfo.new(0.25),
        {Position = UDim2.new(1, -275, 1, -75)}
    ):Play()

    task.delay(duration or 3, function()
        if currentId ~= notificationId then
            return
        end

        local tween = TweenService:Create(
            notification,
            TweenInfo.new(0.25),
            {Position = UDim2.new(1, -275, 1, 80)}
        )

        tween:Play()
        tween.Completed:Wait()

        if currentId == notificationId then
            notification.Visible = false
        end
    end)
end

--============================================================
-- CIRCULAR OPEN BUTTON
--============================================================

local floatingButton = create("TextButton", {
    Name = "OpenImporter",
    Size = UDim2.new(0, 54, 0, 54),
    Position = UDim2.new(0, 18, 0.5, -27),
    BackgroundColor3 = CONFIG.Purple,
    Text = ">>>",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 24,
    Font = Enum.Font.GothamBlack,
    ZIndex = 10,
}, gui)

create("UICorner", {
    CornerRadius = UDim.new(1, 0),
}, floatingButton)

create("UIStroke", {
    Color = CONFIG.LightPurple,
    Thickness = 2,
}, floatingButton)

--============================================================
-- MAIN PANEL
--============================================================

local main = create("Frame", {
    Name = "MainPanel",
    Size = UDim2.new(0, 330, 0, 410),
    Position = UDim2.new(0.5, -165, 0.5, -205),
    BackgroundColor3 = CONFIG.Background,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 2,
}, gui)

create("UICorner", {
    CornerRadius = UDim.new(0, 13),
}, main)

create("UIStroke", {
    Color = CONFIG.Purple,
    Thickness = 1.5,
}, main)

local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = CONFIG.Panel,
    BorderSizePixel = 0,
    ZIndex = 3,
}, main)

create("UICorner", {
    CornerRadius = UDim.new(0, 13),
}, header)

create("Frame", {
    Size = UDim2.new(1, 0, 0, 12),
    Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = CONFIG.Panel,
    BorderSizePixel = 0,
    ZIndex = 3,
}, header)

create("TextLabel", {
    Size = UDim2.new(1, -95, 0, 24),
    Position = UDim2.new(0, 12, 0, 5),
    BackgroundTransparency = 1,
    Text = CONFIG.Title,
    TextColor3 = CONFIG.LightPurple,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
}, header)

create("TextLabel", {
    Size = UDim2.new(1, -95, 0, 15),
    Position = UDim2.new(0, 12, 0, 27),
    BackgroundTransparency = 1,
    Text = "RBXM / RBXMX  •  v" .. CONFIG.Version,
    TextColor3 = CONFIG.Muted,
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
}, header)

local minimizeButton = create("TextButton", {
    Size = UDim2.new(0, 27, 0, 27),
    Position = UDim2.new(1, -65, 0, 10),
    BackgroundColor3 = Color3.fromRGB(77, 57, 100),
    Text = "—",
    TextColor3 = CONFIG.Text,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    ZIndex = 5,
}, header)

create("UICorner", {
    CornerRadius = UDim.new(0, 7),
}, minimizeButton)

local closeButton = create("TextButton", {
    Size = UDim2.new(0, 27, 0, 27),
    Position = UDim2.new(1, -33, 0, 10),
    BackgroundColor3 = Color3.fromRGB(160, 55, 75),
    Text = "×",
    TextColor3 = CONFIG.Text,
    TextSize = 19,
    Font = Enum.Font.GothamBold,
    ZIndex = 5,
}, header)

create("UICorner", {
    CornerRadius = UDim.new(0, 7),
}, closeButton)

local searchBox = create("TextBox", {
    Size = UDim2.new(1, -24, 0, 32),
    Position = UDim2.new(0, 12, 0, 60),
    BackgroundColor3 = CONFIG.Panel,
    PlaceholderText = "Cari file RBXM atau RBXMX...",
    PlaceholderColor3 = CONFIG.Muted,
    Text = "",
    TextColor3 = CONFIG.Text,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
    ZIndex = 3,
}, main)

create("UICorner", {
    CornerRadius = UDim.new(0, 7),
}, searchBox)

local filterBar = create("Frame", {
    Size = UDim2.new(1, -24, 0, 29),
    Position = UDim2.new(0, 12, 0, 101),
    BackgroundTransparency = 1,
    ZIndex = 3,
}, main)

create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, filterBar)

local fileList = create("ScrollingFrame", {
    Size = UDim2.new(1, -24, 0, 174),
    Position = UDim2.new(0, 12, 0, 139),
    BackgroundColor3 = CONFIG.Panel,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 3,
}, main)

create("UICorner", {
    CornerRadius = UDim.new(0, 8),
}, fileList)

local fileLayout = create("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, fileList)

create("UIPadding", {
    PaddingTop = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, fileList)

local statusLabel = create("TextLabel", {
    Size = UDim2.new(1, -24, 0, 34),
    Position = UDim2.new(0, 12, 0, 319),
    BackgroundTransparency = 1,
    Text = "Tekan SCAN FILE untuk mulai.",
    TextColor3 = CONFIG.Muted,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, main)

local scanButton = create("TextButton", {
    Size = UDim2.new(0.5, -17, 0, 36),
    Position = UDim2.new(0, 12, 1, -48),
    BackgroundColor3 = CONFIG.Panel,
    Text = "SCAN FILE",
    TextColor3 = CONFIG.Text,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    ZIndex = 3,
}, main)

create("UICorner", {
    CornerRadius = UDim.new(0, 8),
}, scanButton)

local importButton = create("TextButton", {
    Size = UDim2.new(0.5, -17, 0, 36),
    Position = UDim2.new(0.5, 5, 1, -48),
    BackgroundColor3 = CONFIG.Purple,
    Text = "IMPORT",
    TextColor3 = CONFIG.Text,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    ZIndex = 3,
}, main)

create("UICorner", {
    CornerRadius = UDim.new(0, 8),
}, importButton)

--============================================================
-- LIST RENDERING
--============================================================

local files = {}
local selectedFile = nil
local activeFilter = "ALL"
local searchText = ""

local function renderFiles()
    for _, child in ipairs(fileList:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local count = 0

    for _, path in ipairs(files) do
        local lower = string.lower(path)
        local extension = lower:match("(%.[^./]+)$")

        local filterMatch =
            activeFilter == "ALL"
            or (activeFilter == "RBXM" and extension == ".rbxm")
            or (activeFilter == "RBXMX" and extension == ".rbxmx")

        local searchMatch =
            searchText == ""
            or lower:find(string.lower(searchText), 1, true) ~= nil

        if filterMatch and searchMatch then
            count = count + 1

            local button = create("TextButton", {
                Name = "FileEntry" .. count,
                Size = UDim2.new(1, -4, 0, 33),
                BackgroundColor3 = selectedFile == path
                    and CONFIG.Purple
                    or Color3.fromRGB(48, 39, 65),
                Text = "  " .. path,
                TextColor3 = CONFIG.Text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                LayoutOrder = count,
                ZIndex = 4,
            }, fileList)

            create("UICorner", {
                CornerRadius = UDim.new(0, 6),
            }, button)

            button.Activated:Connect(function()
                selectedFile = path
                statusLabel.Text = "Dipilih: " .. path
                renderFiles()
            end)
        end
    end

    if count == 0 then
        create("TextLabel", {
            Size = UDim2.new(1, -8, 0, 38),
            BackgroundTransparency = 1,
            Text = "Tidak ada file yang cocok.",
            TextColor3 = CONFIG.Muted,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            ZIndex = 4,
        }, fileList)
    end

    task.defer(function()
        fileList.CanvasSize = UDim2.new(
            0, 0, 0, fileLayout.AbsoluteContentSize.Y + 12
        )
    end)
end

for _, name in ipairs({"ALL", "RBXM", "RBXMX"}) do
    local button = create("TextButton", {
        Size = UDim2.new(0, 90, 0, 27),
        BackgroundColor3 = CONFIG.Panel,
        Text = name,
        TextColor3 = CONFIG.Text,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        ZIndex = 4,
    }, filterBar)

    create("UICorner", {
        CornerRadius = UDim.new(0, 6),
    }, button)

    button.Activated:Connect(function()
        activeFilter = name
        renderFiles()
    end)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = searchBox.Text
    renderFiles()
end)

--============================================================
-- SCAN BUTTON
--============================================================

scanButton.Activated:Connect(function()
    scanButton.Text = "SCANNING..."

    local result, err = scanFiles()
    files = result or {}

    if selectedFile then
        local stillExists = false

        for _, path in ipairs(files) do
            if path == selectedFile then
                stillExists = true
                break
            end
        end

        if not stillExists then
            selectedFile = nil
        end
    end

    if #files > 0 then
        statusLabel.Text = "Ditemukan " .. #files .. " file."
        popup("Ditemukan " .. #files .. " file.")
    else
        statusLabel.Text = err or "Tidak ada file yang ditemukan."
        popup(err or "File tidak ditemukan.")
    end

    scanButton.Text = "SCAN FILE"
    renderFiles()
end)

--============================================================
-- IMPORT BUTTON
--============================================================

local function importSelected(path)
    if type(readfileAPI) ~= "function" then
        return false, "API readfile() tidak tersedia."
    end

    local readOK, contents = pcall(readfileAPI, path)

    if not readOK or type(contents) ~= "string" then
        return false, "Gagal membaca file lokal."
    end

    if #contents == 0 then
        return false, "File kosong."
    end

    if type(getobjectsAPI) ~= "function" then
        return false, "API getobjects() tidak tersedia."
    end

    local loadOK, objects = pcall(getobjectsAPI, path)

    if not loadOK or type(objects) ~= "table" then
        return false,
            "File terbaca, tetapi getobjects() gagal memuat model lokal."
    end

    local imported = 0

    for _, object in ipairs(objects) do
        if typeof(object) == "Instance" then
            local ok = pcall(function()
                object.Parent = workspace
            end)

            if ok then
                imported = imported + 1
            end
        end
    end

    if imported == 0 then
        return false,
            "Tidak ada objek hasil pemuatan. " ..
            "Diperlukan API atau parser RBXM/RBXMX yang kompatibel."
    end

    return true, "Berhasil mengimpor " .. imported .. " objek."
end

importButton.Activated:Connect(function()
    if not selectedFile then
        popup("Pilih file terlebih dahulu.")
        return
    end

    importButton.Text = "MEMUAT..."

    local ok, message = importSelected(selectedFile)

    importButton.Text = "IMPORT"
    statusLabel.Text = message
    popup(message)
end)

--============================================================
-- PANEL CONTROLS
--============================================================

floatingButton.Activated:Connect(function()
    main.Visible = not main.Visible
end)

minimizeButton.Activated:Connect(function()
    main.Visible = false
end)

closeButton.Activated:Connect(function()
    main.Visible = false
end)

--============================================================
-- DRAG PANEL
--============================================================

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

UserInputService.InputChanged:Connect(function(input)
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

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

--============================================================
-- START
--============================================================

renderFiles()
popup("PUNAKAWAN COMMUNITY IMPORTER aktif.", 3)
