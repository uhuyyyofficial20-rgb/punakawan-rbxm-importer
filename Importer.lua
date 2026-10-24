--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- RBXM / RBXMX Importer
-- Delta Executor - Roblox Studio Lite
--==============================================================

local VERSION = "1.0.0"

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

--==============================================================
-- EXECUTOR API
--==============================================================

local function getAPI(name)
    local envs = {}

    if type(getgenv) == "function" then
        pcall(function()
            table.insert(envs, getgenv())
        end)
    end

    if type(getfenv) == "function" then
        pcall(function()
            table.insert(envs, getfenv())
        end)

        pcall(function()
            table.insert(envs, getfenv(0))
        end)
    end

    table.insert(envs, _G)

    for _, env in ipairs(envs) do
        if type(env) == "table" then
            local value = rawget(env, name)

            if value ~= nil then
                return value
            end
        end
    end

    local globalValue

    pcall(function()
        globalValue = _G[name]
    end)

    return globalValue
end

local listfilesAPI = getAPI("listfiles")
local readfileAPI = getAPI("readfile")
local isfolderAPI = getAPI("isfolder")
local isfileAPI = getAPI("isfile")
local getobjectsAPI = getAPI("getobjects")

--==============================================================
-- FILE SCANNER
--==============================================================

local EXTENSIONS = {
    ".rbxm",
    ".rbxmx",
}

local ROOTS = {
    "Delta/Workspace",
    "Delta\\Workspace",
    "Workspace",
    "workspace",
    "Delta",
}

local files = {}
local selectedFile = nil
local activeFilter = "ALL"
local searchText = ""

local function hasSupportedExtension(path)
    local lower = string.lower(tostring(path))

    for _, ext in ipairs(EXTENSIONS) do
        if lower:sub(-#ext) == ext then
            return true
        end
    end

    return false
end

local function normalizePath(path)
    return tostring(path):gsub("\\", "/")
end

local function scanFiles()
    local found = {}
    local seen = {}

    if type(listfilesAPI) ~= "function" then
        return found, "API listfiles() tidak tersedia."
    end

    local function addFile(path)
        if type(path) ~= "string" then
            return
        end

        path = normalizePath(path)

        if not hasSupportedExtension(path) then
            return
        end

        local key = string.lower(path)

        if not seen[key] then
            seen[key] = true
            table.insert(found, path)
        end
    end

    local function scanDirectory(path, depth)
        if depth > 5 then
            return
        end

        local ok, result = pcall(listfilesAPI, path)

        if not ok or type(result) ~= "table" then
            return
        end

        for _, item in ipairs(result) do
            if type(item) == "string" then
                if hasSupportedExtension(item) then
                    addFile(item)
                elseif type(isfolderAPI) == "function" then
                    local folderOK, isFolder = pcall(isfolderAPI, item)

                    if folderOK and isFolder then
                        scanDirectory(item, depth + 1)
                    end
                end
            end
        end
    end

    -- Coba daftar file dari root executor.
    pcall(function()
        local result = listfilesAPI()

        if type(result) == "table" then
            for _, item in ipairs(result) do
                if type(item) == "string" then
                    if hasSupportedExtension(item) then
                        addFile(item)
                    elseif type(isfolderAPI) == "function" then
                        local ok, isFolder = pcall(isfolderAPI, item)

                        if ok and isFolder then
                            scanDirectory(item, 0)
                        end
                    end
                end
            end
        end
    end)

    -- Coba direktori yang umum digunakan.
    for _, root in ipairs(ROOTS) do
        scanDirectory(root, 0)
    end

    table.sort(found, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return found
end

--==============================================================
-- IMPORT ENGINE
--==============================================================

local function importModel(path)
    if type(readfileAPI) ~= "function" then
        return false, "API readfile() tidak tersedia."
    end

    local readOK, contents = pcall(readfileAPI, path)

    if not readOK or type(contents) ~= "string" then
        return false, "Gagal membaca file:\n" .. tostring(contents)
    end

    if #contents == 0 then
        return false, "File kosong."
    end

    local extension = string.lower(path):match("(%.[^./\\]+)$")

    if extension ~= ".rbxm" and extension ~= ".rbxmx" then
        return false, "Gunakan file RBXM atau RBXMX."
    end

    if type(getobjectsAPI) ~= "function" then
        return false,
            "API getobjects() tidak tersedia.\n" ..
            "File terbaca, tetapi belum ada API pemuat model."
    end

    -- Beberapa executor menerima ID/aset, bukan jalur lokal.
    -- Percobaan ini hanya dilakukan untuk mengetahui apakah
    -- executor mendukung jalur lokal; tidak menganggap sukses
    -- jika hasilnya bukan daftar Instance.
    local loadOK, result = pcall(getobjectsAPI, path)

    if loadOK and type(result) == "table" and #result > 0 then
        local imported = 0
        local failures = {}

        for _, object in ipairs(result) do
            if typeof(object) == "Instance" then
                local parentOK, parentError = pcall(function()
                    object.Parent = workspace
                end)

                if parentOK then
                    imported = imported + 1
                else
                    table.insert(failures, tostring(parentError))
                end
            end
        end

        if imported > 0 then
            return true, "Berhasil memasukkan " .. imported .. " objek ke Workspace."
        end

        return false,
            "API pemuatan mengembalikan data, tetapi tidak ada Instance " ..
            "yang berhasil dimasukkan.\n" .. table.concat(failures, "\n")
    end

    return false,
        "File berhasil dibaca (" .. #contents .. " byte), " ..
        "tetapi Delta tidak menghasilkan objek Roblox dari jalur file ini.\n\n" ..
        "Kemungkinan getobjects() tidak mendukung RBXM lokal. " ..
        "Diperlukan parser RBXM/RBXMX atau API pemuat lokal yang kompatibel."
end

--==============================================================
-- GUI
--==============================================================

pcall(function()
    local old = CoreGui:FindFirstChild("PunakawanImporter")
    if old then
        old:Destroy()
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "PunakawanImporter"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentOK = pcall(function()
    gui.Parent = CoreGui
end)

if not parentOK then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 370, 0, 450)
main.Position = UDim2.new(0.5, -185, 0.5, -225)
main.BackgroundColor3 = Color3.fromRGB(23, 20, 35)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(145, 80, 255)
stroke.Thickness = 1.5
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 0, 42)
title.Position = UDim2.new(0, 12, 0, 4)
title.BackgroundTransparency = 1
title.Text = "PUNAKAWAN COMMUNITY"
title.TextColor3 = Color3.fromRGB(205, 170, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.new(0, 34, 0, 30)
minimize.Position = UDim2.new(1, -44, 0, 9)
minimize.BackgroundColor3 = Color3.fromRGB(67, 45, 105)
minimize.Text = "—"
minimize.TextColor3 = Color3.new(1, 1, 1)
minimize.TextSize = 18
minimize.Font = Enum.Font.GothamBold
minimize.Parent = main

Instance.new("UICorner", minimize).CornerRadius = UDim.new(0, 7)

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -24, 0, 20)
subtitle.Position = UDim2.new(0, 12, 0, 43)
subtitle.BackgroundTransparency = 1
subtitle.Text = "RBXM / RBXMX IMPORTER  |  v" .. VERSION
subtitle.TextColor3 = Color3.fromRGB(160, 150, 180)
subtitle.TextSize = 11
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = main

local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -24, 0, 34)
search.Position = UDim2.new(0, 12, 0, 72)
search.BackgroundColor3 = Color3.fromRGB(36, 31, 51)
search.PlaceholderText = "Cari nama file..."
search.PlaceholderColor3 = Color3.fromRGB(150, 140, 165)
search.Text = ""
search.TextColor3 = Color3.new(1, 1, 1)
search.TextSize = 13
search.Font = Enum.Font.Gotham
search.ClearTextOnFocus = false
search.Parent = main

Instance.new("UICorner", search).CornerRadius = UDim.new(0, 7)

local filterBar = Instance.new("Frame")
filterBar.Size = UDim2.new(1, -24, 0, 30)
filterBar.Position = UDim2.new(0, 12, 0, 114)
filterBar.BackgroundTransparency = 1
filterBar.Parent = main

local filterLayout = Instance.new("UIListLayout")
filterLayout.FillDirection = Enum.FillDirection.Horizontal
filterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
filterLayout.Padding = UDim.new(0, 5)
filterLayout.Parent = filterBar

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -24, 0, 200)
list.Position = UDim2.new(0, 12, 0, 151)
list.BackgroundColor3 = Color3.fromRGB(31, 27, 43)
list.BorderSizePixel = 0
list.ScrollBarThickness = 5
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.Parent = main

Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.PaddingLeft = UDim.new(0, 6)
listPadding.PaddingRight = UDim.new(0, 6)
listPadding.Parent = list

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 35)
status.Position = UDim2.new(0, 12, 0, 357)
status.BackgroundTransparency = 1
status.Text = "Tekan SCAN untuk mencari file."
status.TextColor3 = Color3.fromRGB(190, 180, 210)
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main

local scanButton = Instance.new("TextButton")
scanButton.Size = UDim2.new(0.48, -8, 0, 38)
scanButton.Position = UDim2.new(0, 12, 1, -48)
scanButton.BackgroundColor3 = Color3.fromRGB(85, 49, 145)
scanButton.Text = "SCAN FILE"
scanButton.TextColor3 = Color3.new(1, 1, 1)
scanButton.TextSize = 13
scanButton.Font = Enum.Font.GothamBold
scanButton.Parent = main

Instance.new("UICorner", scanButton).CornerRadius = UDim.new(0, 8)

local importButton = Instance.new("TextButton")
importButton.Size = UDim2.new(0.48, -8, 0, 38)
importButton.Position = UDim2.new(0.52, -4, 1, -48)
importButton.BackgroundColor3 = Color3.fromRGB(130, 75, 220)
importButton.Text = "IMPORT"
importButton.TextColor3 = Color3.new(1, 1, 1)
importButton.TextSize = 13
importButton.Font = Enum.Font.GothamBold
importButton.Parent = main

Instance.new("UICorner", importButton).CornerRadius = UDim.new(0, 8)

--==============================================================
-- FILE LIST
--==============================================================

local function clearList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function refreshList()
    clearList()

    local displayed = 0

    for _, path in ipairs(files) do
        local lower = string.lower(path)
        local ext = lower:match("(%.[^./\\]+)$")
        local matchesFilter =
            activeFilter == "ALL" or
            (activeFilter == "RBXM" and ext == ".rbxm") or
            (activeFilter == "RBXMX" and ext == ".rbxmx")

        local matchesSearch =
            searchText == "" or
            string.find(lower, string.lower(searchText), 1, true) ~= nil

        if matchesFilter and matchesSearch then
            displayed = displayed + 1

            local button = Instance.new("TextButton")
            button.Name = "File_" .. displayed
            button.Size = UDim2.new(1, -4, 0, 34)
            button.BackgroundColor3 =
                selectedFile == path
                and Color3.fromRGB(93, 58, 135)
                or Color3.fromRGB(43, 37, 57)
            button.Text = "  " .. path
            button.TextColor3 = Color3.fromRGB(235, 230, 245)
            button.TextSize = 11
            button.Font = Enum.Font.Gotham
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.TextTruncate = Enum.TextTruncate.AtEnd
            button.LayoutOrder = displayed
            button.Parent = list

            Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

            button.Activated:Connect(function()
                selectedFile = path
                status.Text = "Dipilih: " .. path
                refreshList()
            end)
        end
    end

    if displayed == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -4, 0, 42)
        empty.BackgroundTransparency = 1
        empty.Text = "Tidak ada file yang cocok."
        empty.TextColor3 = Color3.fromRGB(160, 150, 180)
        empty.TextSize = 12
        empty.Font = Enum.Font.Gotham
        empty.Parent = list
    end

    task.defer(function()
        list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
    end)
end

local filters = {"ALL", "RBXM", "RBXMX"}

for _, filterName in ipairs(filters) do
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 80, 0, 28)
    button.BackgroundColor3 = Color3.fromRGB(55, 45, 75)
    button.Text = filterName
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 11
    button.Font = Enum.Font.GothamBold
    button.Parent = filterBar

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

    button.Activated:Connect(function()
        activeFilter = filterName
        refreshList()
    end)
end

search:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = search.Text
    refreshList()
end)

--==============================================================
-- BUTTON ACTIONS
--==============================================================

scanButton.Activated:Connect(function()
    scanButton.Text = "SCANNING..."

    local result, err = scanFiles()
    files = result or {}

    if #files > 0 then
        status.Text = "Ditemukan " .. #files .. " file RBXM/RBXMX."
    else
        status.Text = err or "Tidak ditemukan file RBXM/RBXMX."
    end

    scanButton.Text = "SCAN FILE"
    refreshList()
end)

importButton.Activated:Connect(function()
    if not selectedFile then
        status.Text = "Pilih file RBXM atau RBXMX terlebih dahulu."
        return
    end

    importButton.Text = "MEMUAT..."

    local ok, message = importModel(selectedFile)

    status.Text = message
    importButton.Text = "IMPORT"
end)

local minimized = false

minimize.Activated:Connect(function()
    minimized = not minimized

    for _, child in ipairs(main:GetChildren()) do
        if child ~= title and child ~= minimize and child ~= corner and child ~= stroke then
            child.Visible = not minimized
        end
    end

    main.Size = minimized
        and UDim2.new(0, 250, 0, 48)
        or UDim2.new(0, 370, 0, 450)

    minimize.Text = minimized and "+" or "—"
end)

--==============================================================
-- DRAG WINDOW
--==============================================================

local UserInputService = game:GetService("UserInputService")

local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
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

status.Text = "Importer siap. Tekan SCAN FILE."
refreshList()
