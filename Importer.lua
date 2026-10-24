--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- File Scanner GUI for Delta
--==============================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

--==============================================================
-- CONFIGURATION
--==============================================================

local APP_NAME = "PUNAKAWAN COMMUNITY IMPORTER"

local EXTENSIONS = {
    RBXM = {".rbxm"},
    RBXMX = {".rbxmx"},
    RBXL = {".rbxl"},
    RBXLX = {".rbxlx"}
}

local SEARCH_PATHS = {
    "Delta/Workspace",
    "Delta\\Workspace",
    "Workspace",
    "workspace",
    "Delta",
    ""
}

--==============================================================
-- CLEANUP OLD GUI
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

local function corner(parent, radius)
    create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8)
    }, parent)
end

local function stroke(parent, color, thickness)
    create("UIStroke", {
        Color = color or Color3.fromRGB(75, 70, 90),
        Thickness = thickness or 1
    }, parent)
end

--==============================================================
-- MAIN GUI
--==============================================================

local gui = create("ScreenGui", {
    Name = "PunakawanCommunityImporter",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, CoreGui)

local main = create("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(390, 455),
    Position = UDim2.new(0.5, -195, 0.5, -227),
    BackgroundColor3 = Color3.fromRGB(22, 21, 27),
    BorderSizePixel = 0
}, gui)
corner(main, 14)
stroke(main, Color3.fromRGB(75, 70, 90), 1)

local header = create("Frame", {
    Size = UDim2.new(1, 0, 0, 45),
    BackgroundColor3 = Color3.fromRGB(31, 29, 38),
    BorderSizePixel = 0
}, main)
corner(header, 12)

local title = create("TextLabel", {
    Position = UDim2.fromOffset(14, 0),
    Size = UDim2.new(1, -110, 1, 0),
    BackgroundTransparency = 1,
    Text = "PUNAKAWAN IMPORTER",
    TextColor3 = Color3.fromRGB(245, 242, 255),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)

local minimizeButton = create("TextButton", {
    Position = UDim2.new(1, -76, 0, 7),
    Size = UDim2.fromOffset(30, 30),
    Text = "—",
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(48, 45, 58),
    BorderSizePixel = 0
}, header)
corner(minimizeButton, 8)

local closeButton = create("TextButton", {
    Position = UDim2.new(1, -39, 0, 7),
    Size = UDim2.fromOffset(30, 30),
    Text = "×",
    TextSize = 20,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(48, 45, 58),
    BorderSizePixel = 0
}, header)
corner(closeButton, 8)

local scanButton = create("TextButton", {
    Position = UDim2.fromOffset(12, 55),
    Size = UDim2.new(1, -24, 0, 38),
    Text = "SCAN FILES",
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.fromRGB(35, 32, 45),
    BackgroundColor3 = Color3.fromRGB(240, 237, 248),
    BorderSizePixel = 0
}, main)
corner(scanButton, 8)

local searchBox = create("TextBox", {
    Position = UDim2.fromOffset(12, 101),
    Size = UDim2.new(1, -24, 0, 32),
    PlaceholderText = "Search files...",
    Text = "",
    ClearTextOnFocus = false,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderColor3 = Color3.fromRGB(150, 145, 165),
    BackgroundColor3 = Color3.fromRGB(35, 33, 43),
    BorderSizePixel = 0
}, main)
corner(searchBox, 7)

local filterFrame = create("Frame", {
    Position = UDim2.fromOffset(12, 141),
    Size = UDim2.new(1, -24, 0, 30),
    BackgroundTransparency = 1
}, main)

local listFrame = create("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 179),
    Size = UDim2.new(1, -24, 1, -222),
    BackgroundColor3 = Color3.fromRGB(29, 27, 35),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(130, 120, 155),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, main)
corner(listFrame, 9)

local listLayout = create("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder
}, listFrame)

create("UIPadding", {
    PaddingTop = UDim.new(0, 7),
    PaddingBottom = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7)
}, listFrame)

local status = create("TextLabel", {
    Position = UDim2.new(0, 12, 1, -32),
    Size = UDim2.new(1, -24, 0, 22),
    BackgroundTransparency = 1,
    Text = "Status: Ready | Files: 0",
    TextColor3 = Color3.fromRGB(165, 160, 180),
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left
}, main)

--==============================================================
-- DRAGGABLE WINDOW
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

UserInputService.InputChanged:Connect(function(input)
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

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--==============================================================
-- FILE SCANNER
--==============================================================

local allFiles = {}
local activeFilter = "ALL"

local function normalizePath(path)
    path = tostring(path):gsub("\\", "/")
    return path
end

local function getExtension(path)
    local lower = normalizePath(path):lower()

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

local function safeListFiles(path)
    if type(listfiles) ~= "function" then
        return nil, "listfiles tidak tersedia"
    end

    local ok, result

    if path == "" then
        ok, result = pcall(listfiles)
        if not ok then
            ok, result = pcall(listfiles, "")
        end
    else
        ok, result = pcall(listfiles, path)
    end

    if ok and type(result) == "table" then
        return result
    end

    return nil, tostring(result)
end

local function safeIsFolder(path)
    if type(isfolder) ~= "function" then
        return false
    end

    local ok, result = pcall(isfolder, path)
    return ok and result == true
end

local function scanFiles()
    allFiles = {}

    if type(listfiles) ~= "function" then
        status.Text = "Error: Delta tidak menyediakan listfiles."
        return
    end

    local seen = {}
    local foldersToScan = {}
    local scannedFolders = {}

    for _, path in ipairs(SEARCH_PATHS) do
        if path == "" or safeIsFolder(path) then
            table.insert(foldersToScan, path)
        end
    end

    -- Cari file pada folder umum terlebih dahulu.
    for _, folder in ipairs(foldersToScan) do
        local entries = safeListFiles(folder)

        if entries then
            for _, entry in ipairs(entries) do
                if type(entry) == "string" then
                    local fullPath = normalizePath(entry)
                    local extension = getExtension(fullPath)

                    if extension then
                        local key = fullPath:lower()

                        if not seen[key] then
                            seen[key] = true

                            table.insert(allFiles, {
                                path = fullPath,
                                name = fullPath:match("([^/]+)$") or fullPath,
                                extension = extension
                            })
                        end
                    elseif safeIsFolder(entry) then
                        table.insert(foldersToScan, entry)
                    end
                end
            end
        end
    end

    -- Coba subfolder satu tingkat tanpa pemindaian rekursif tanpa batas.
    local initialFolders = #foldersToScan

    for i = 1, math.min(initialFolders, 20) do
        local folder = foldersToScan[i]

        if folder ~= "" and not scannedFolders[folder] then
            scannedFolders[folder] = true

            local entries = safeListFiles(folder)

            if entries then
                for _, entry in ipairs(entries) do
                    if type(entry) == "string" then
                        local fullPath = normalizePath(entry)
                        local extension = getExtension(fullPath)

                        if extension then
                            local key = fullPath:lower()

                            if not seen[key] then
                                seen[key] = true

                                table.insert(allFiles, {
                                    path = fullPath,
                                    name = fullPath:match("([^/]+)$") or fullPath,
                                    extension = extension
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(allFiles, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
end

--==============================================================
-- FILTER BUTTONS
--==============================================================

local filterNames = {"ALL", "RBXM", "RBXMX", "RBXL", "RBXLX"}
local filterButtons = {}

for i, name in ipairs(filterNames) do
    local button = create("TextButton", {
        Position = UDim2.new((i - 1) * 0.2, 2, 0, 0),
        Size = UDim2.new(0.2, -4, 1, 0),
        Text = name,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.new(1, 1, 1),
        BackgroundColor3 = Color3.fromRGB(48, 45, 58),
        BorderSizePixel = 0
    }, filterFrame)

    corner(button, 6)
    filterButtons[name] = button

    button.Activated:Connect(function()
        activeFilter = name

        for filterName, filterButton in pairs(filterButtons) do
            filterButton.BackgroundColor3 =
                filterName == activeFilter
                and Color3.fromRGB(105, 82, 150)
                or Color3.fromRGB(48, 45, 58)
        end

        -- Refresh daftar sesuai filter.
        local function refresh()
            for _, child in ipairs(listFrame:GetChildren()) do
                if child:IsA("Frame") then
                    child:Destroy()
                end
            end

            local query = searchBox.Text:lower()
            local displayed = 0

            for _, file in ipairs(allFiles) do
                local matchesFilter =
                    activeFilter == "ALL"
                    or file.extension == activeFilter

                local matchesSearch =
                    query == ""
                    or file.name:lower():find(query, 1, true) ~= nil

                if matchesFilter and matchesSearch then
                    displayed += 1

                    local row = create("Frame", {
                        Size = UDim2.new(1, -4, 0, 55),
                        BackgroundColor3 = Color3.fromRGB(39, 37, 47),
                        BorderSizePixel = 0,
                        LayoutOrder = displayed
                    }, listFrame)
                    corner(row, 7)

                    create("TextLabel", {
                        Position = UDim2.fromOffset(8, 4),
                        Size = UDim2.new(1, -94, 0, 25),
                        BackgroundTransparency = 1,
                        Text = file.name,
                        TextColor3 = Color3.fromRGB(245, 242, 255),
                        TextSize = 11,
                        Font = Enum.Font.GothamSemibold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }, row)

                    create("TextLabel", {
                        Position = UDim2.fromOffset(8, 29),
                        Size = UDim2.new(1, -94, 0, 18),
                        BackgroundTransparency = 1,
                        Text = file.extension .. " | " .. file.path,
                        TextColor3 = Color3.fromRGB(155, 150, 170),
                        TextSize = 9,
                        Font = Enum.Font.Gotham,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd
                    }, row)

                    local insertButton = create("TextButton", {
                        Position = UDim2.new(1, -78, 0.5, -14),
                        Size = UDim2.fromOffset(70, 28),
                        Text = "IMPORT",
                        TextSize = 10,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = Color3.new(1, 1, 1),
                        BackgroundColor3 = Color3.fromRGB(88, 72, 112),
                        BorderSizePixel = 0
                    }, row)
                    corner(insertButton, 6)

                    insertButton.Activated:Connect(function()
                        status.Text =
                            "File terpilih: " .. file.name
                            .. " | API import belum terkonfirmasi."
                        warn("[PUNAKAWAN] File path:", file.path)
                        warn("[PUNAKAWAN] Delta harus menyediakan API impor yang sesuai untuk memasukkan model.")
                    end)
                end
            end

            status.Text = "Status: Ready | Files: "
                .. tostring(#allFiles)
                .. " | Shown: "
                .. tostring(displayed)
        end

        refresh()
    end)
end

--==============================================================
-- REFRESH LIST
--==============================================================

local function refreshList()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local query = searchBox.Text:lower()
    local displayed = 0

    for _, file in ipairs(allFiles) do
        local matchesFilter =
            activeFilter == "ALL"
            or file.extension == activeFilter

        local matchesSearch =
            query == ""
            or file.name:lower():find(query, 1, true) ~= nil

        if matchesFilter and matchesSearch then
            displayed += 1

            local row = create("Frame", {
                Size = UDim2.new(1, -4, 0, 55),
                BackgroundColor3 = Color3.fromRGB(39, 37, 47),
                BorderSizePixel = 0,
                LayoutOrder = displayed
            }, listFrame)
            corner(row, 7)

            create("TextLabel", {
                Position = UDim2.fromOffset(8, 4),
                Size = UDim2.new(1, -94, 0, 25),
                BackgroundTransparency = 1,
                Text = file.name,
                TextColor3 = Color3.fromRGB(245, 242, 255),
                TextSize = 11,
                Font = Enum.Font.GothamSemibold,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            }, row)

            create("TextLabel", {
                Position = UDim2.fromOffset(8, 29),
                Size = UDim2.new(1, -94, 0, 18),
                BackgroundTransparency = 1,
                Text = file.extension .. " | " .. file.path,
                TextColor3 = Color3.fromRGB(155, 150, 170),
                TextSize = 9,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd
            }, row)

            local insertButton = create("TextButton", {
                Position = UDim2.new(1, -78, 0.5, -14),
                Size = UDim2.fromOffset(70, 28),
                Text = "IMPORT",
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1),
                BackgroundColor3 = Color3.fromRGB(88, 72, 112),
                BorderSizePixel = 0
            }, row)
            corner(insertButton, 6)

            insertButton.Activated:Connect(function()
                status.Text = "File terpilih: " .. file.name
                warn("[PUNAKAWAN] File path:", file.path)
                warn("[PUNAKAWAN] Tombol ini belum memasukkan model; API impor Delta perlu dikonfirmasi.")
            end)
        end
    end

    status.Text = "Status: Ready | Files: "
        .. tostring(#allFiles)
        .. " | Shown: "
        .. tostring(displayed)
end

--==============================================================
-- EVENTS
--==============================================================

scanButton.Activated:Connect(function()
    status.Text = "Scanning files..."

    task.spawn(function()
        local ok, err = pcall(scanFiles)

        if not ok then
            status.Text = "Scan error: " .. tostring(err)
            warn("[PUNAKAWAN] Scan error:", err)
            return
        end

        refreshList()

        if #allFiles == 0 then
            status.Text = "Files: 0 | Periksa path penyimpanan Delta."
        end
    end)
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(refreshList)

minimizeButton.Activated:Connect(function()
    main.Visible = false
end)

closeButton.Activated:Connect(function()
    gui:Destroy()
end)

-- Floating reopen button
local reopenButton = create("TextButton", {
    Name = "ReopenButton",
    Position = UDim2.new(0, 20, 0.5, -25),
    Size = UDim2.fromOffset(50, 50),
    Text = "PC",
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    TextColor3 = Color3.new(1, 1, 1),
    BackgroundColor3 = Color3.fromRGB(83, 64, 120),
    BorderSizePixel = 0,
    Visible = false
}, gui)
corner(reopenButton, 25)

minimizeButton.Activated:Connect(function()
    main.Visible = false
    reopenButton.Visible = true
end)

reopenButton.Activated:Connect(function()
    main.Visible = true
    reopenButton.Visible = false
end)

-- Initial scan
task.delay(1, function()
    if gui.Parent then
        scanButton:Activate()
    end
end)

print("[PUNAKAWAN] Community Importer GUI loaded.")
