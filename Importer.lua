--==================================================
-- PUNAKAWAN STUDIO LITE FILE IMPORTER
-- GUI + FILE SCANNER + FILE TYPE TABS
--==================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local GUI_NAME = "PunakawanImporterGUI"
local DEFAULT_PATH = "/storage/emulated/0/Delta/Workspace/"

local C = {
    bg = Color3.fromRGB(18, 18, 25),
    panel = Color3.fromRGB(31, 29, 43),
    purple = Color3.fromRGB(145, 75, 255),
    white = Color3.fromRGB(245, 245, 255),
    gray = Color3.fromRGB(165, 165, 180),
    green = Color3.fromRGB(75, 225, 130),
    red = Color3.fromRGB(255, 75, 95)
}

--==================================================
-- EXECUTOR API
--==================================================

local function getAPI(name)
    local envs = {}

    pcall(function()
        if type(getgenv) == "function" then
            table.insert(envs, getgenv())
        end
    end)

    pcall(function()
        if type(getfenv) == "function" then
            table.insert(envs, getfenv(0))
        end
    end)

    table.insert(envs, _G)

    for _, env in ipairs(envs) do
        local ok, value = pcall(function()
            return env[name]
        end)

        if ok and type(value) == "function" then
            return value
        end
    end

    return nil
end

local listfilesAPI = getAPI("listfiles")

--==================================================
-- CLEAN OLD GUI
--==================================================

local player = Players.LocalPlayer
if not player then
    warn("[Punakawan] Player tidak ditemukan.")
    return
end

local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild(GUI_NAME)
if old then
    old:Destroy()
end

--==================================================
-- GUI ROOT
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 340, 0, 445)
main.Position = UDim2.new(0.5, -170, 0.5, -222)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = C.purple
stroke.Thickness = 2
stroke.Parent = main

--==================================================
-- UI HELPERS
--==================================================

local function newLabel(parent, name, text, pos, size, color, textSize)
    local obj = Instance.new("TextLabel")
    obj.Name = name
    obj.Position = pos
    obj.Size = size
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = color or C.white
    obj.TextSize = textSize or 12
    obj.Font = Enum.Font.Gotham
    obj.Parent = parent
    return obj
end

local function newButton(parent, name, text, pos, size, color)
    local obj = Instance.new("TextButton")
    obj.Name = name
    obj.Position = pos
    obj.Size = size
    obj.BackgroundColor3 = color or C.panel
    obj.BorderSizePixel = 0
    obj.Text = text
    obj.TextColor3 = C.white
    obj.TextSize = 11
    obj.Font = Enum.Font.GothamBold
    obj.Parent = parent

    Instance.new("UICorner", obj).CornerRadius = UDim.new(0, 6)
    return obj
end

--==================================================
-- HEADER
--==================================================

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 43)
header.BackgroundColor3 = Color3.fromRGB(43, 28, 65)
header.BorderSizePixel = 0
header.Active = true
header.Parent = main

newLabel(
    header, "Title", "PUNAKAWAN COMMUNITY | IMPORTER",
    UDim2.new(0, 12, 0, 0),
    UDim2.new(1, -105, 1, 0),
    C.white, 12
)

local minimize = newButton(
    header, "Minimize", "—",
    UDim2.new(1, -72, 0, 7),
    UDim2.new(0, 27, 0, 28),
    C.panel
)

local close = newButton(
    header, "Close", "X",
    UDim2.new(1, -38, 0, 7),
    UDim2.new(0, 28, 0, 28),
    C.red
)

--==================================================
-- STATUS
--==================================================

local status = newLabel(
    main, "Status", "Pilih jenis file, lalu tekan SCAN.",
    UDim2.new(0, 12, 0, 49),
    UDim2.new(1, -24, 0, 34),
    C.gray, 10
)
status.BackgroundColor3 = C.panel
status.BackgroundTransparency = 0
status.TextWrapped = true

Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

--==================================================
-- FOLDER PATH
--==================================================

local pathBox = Instance.new("TextBox")
pathBox.Name = "FolderPath"
pathBox.Position = UDim2.new(0, 12, 0, 87)
pathBox.Size = UDim2.new(1, -24, 0, 32)
pathBox.BackgroundColor3 = C.panel
pathBox.BorderSizePixel = 0
pathBox.Text = DEFAULT_PATH
pathBox.TextColor3 = C.white
pathBox.TextSize = 10
pathBox.Font = Enum.Font.Gotham
pathBox.ClearTextOnFocus = false
pathBox.Parent = main

Instance.new("UICorner", pathBox).CornerRadius = UDim.new(0, 6)

--==================================================
-- FILE TYPE TABS
--==================================================

local currentType = "RBXM"

local tabs = {
    {
        id = "RBXM",
        text = "RBXM",
        x = 12,
        w = 96
    },
    {
        id = "RBXL",
        text = "RBXL",
        x = 116,
        w = 96
    },
    {
        id = "OTHER",
        text = "OTHER",
        x = 220,
        w = 96
    }
}

local tabButtons = {}

for _, info in ipairs(tabs) do
    local button = newButton(
        main,
        info.id .. "Tab",
        info.text,
        UDim2.new(0, info.x, 0, 127),
        UDim2.new(0, info.w, 0, 32),
        info.id == currentType and C.purple or C.panel
    )

    tabButtons[info.id] = button
end

--==================================================
-- SCAN + SEARCH
--==================================================

local scanButton = newButton(
    main, "Scan", "SCAN",
    UDim2.new(0, 12, 0, 166),
    UDim2.new(0, 95, 0, 32),
    C.purple
)

local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Position = UDim2.new(0, 117, 0, 166)
searchBox.Size = UDim2.new(1, -129, 0, 32)
searchBox.BackgroundColor3 = C.panel
searchBox.BorderSizePixel = 0
searchBox.Text = ""
searchBox.PlaceholderText = "Cari file..."
searchBox.TextColor3 = C.white
searchBox.PlaceholderColor3 = C.gray
searchBox.TextSize = 10
searchBox.Font = Enum.Font.Gotham
searchBox.ClearTextOnFocus = false
searchBox.Parent = main

Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)

--==================================================
-- FILE LIST
--==================================================

local fileList = Instance.new("ScrollingFrame")
fileList.Name = "FileList"
fileList.Position = UDim2.new(0, 12, 0, 205)
fileList.Size = UDim2.new(1, -24, 0, 165)
fileList.BackgroundColor3 = C.panel
fileList.BorderSizePixel = 0
fileList.ScrollBarThickness = 4
fileList.ScrollBarImageColor3 = C.purple
fileList.CanvasSize = UDim2.new(0, 0, 0, 0)
fileList.Parent = main

Instance.new("UICorner", fileList).CornerRadius = UDim.new(0, 6)

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = fileList

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingLeft = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)
padding.Parent = fileList

layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    fileList.CanvasSize = UDim2.new(
        0, 0, 0, layout.AbsoluteContentSize.Y + 12
    )
end)

--==================================================
-- SELECTED FILE + IMPORT BUTTON
--==================================================

local selectedFile = nil

local selectedLabel = newLabel(
    main, "SelectedFile", "File dipilih: belum ada",
    UDim2.new(0, 12, 0, 377),
    UDim2.new(1, -24, 0, 22),
    C.gray, 10
)

selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.TextTruncate = Enum.TextTruncate.AtEnd

local importButton = newButton(
    main, "ImportButton", "IMPORT FILE",
    UDim2.new(0, 12, 0, 405),
    UDim2.new(1, -24, 0, 30),
    C.purple
)

--==================================================
-- REOPEN BUTTON
--==================================================

local reopen = newButton(
    gui, "Reopen", "📂",
    UDim2.new(0, 15, 0.5, -25),
    UDim2.new(0, 50, 0, 50),
    C.purple
)

reopen.Visible = false
reopen.TextSize = 22

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

--==================================================
-- DRAG: TOUCH + MOUSE
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

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
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

--==================================================
-- FILE EXTENSIONS
--==================================================

local function getFileType(path)
    local lower = string.lower(path)

    if lower:match("%.rbxm$") or lower:match("%.rbxmx$") then
        return "RBXM"
    end

    if lower:match("%.rbxl$") or lower:match("%.rbxlx$") then
        return "RBXL"
    end

    if lower:match("%.lua$")
    or lower:match("%.luau$")
    or lower:match("%.json$")
    or lower:match("%.anim$")
    or lower:match("%.model$") then
        return "OTHER"
    end

    return nil
end

--==================================================
-- FILE RENDERING
--==================================================

local foundFiles = {}

local function clearRows()
    for _, child in ipairs(fileList:GetChildren()) do
        if child:IsA("TextButton") or child.Name == "Empty" then
            child:Destroy()
        end
    end
end

local function renderFiles()
    clearRows()

    local count = 0
    local query = string.lower(searchBox.Text)

    for _, path in ipairs(foundFiles) do
        if getFileType(path) == currentType then
            local name = path:gsub("\\", "/"):match("([^/]+)$") or path

            if query == "" or string.find(string.lower(name), query, 1, true) then
                count += 1

                local row = newButton(
                    fileList,
                    "FileRow" .. count,
                    name,
                    UDim2.new(),
                    UDim2.new(1, -5, 0, 38),
                    path == selectedFile and C.purple or C.bg
                )

                row.LayoutOrder = count
                row.TextXAlignment = Enum.TextXAlignment.Left
                row.TextSize = 10

                row.Activated:Connect(function()
                    selectedFile = path
                    selectedLabel.Text = "Dipilih: " .. name
                    selectedLabel.TextColor3 = C.green
                    renderFiles()
                end)
            end
        end
    end

    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Name = "Empty"
        empty.Size = UDim2.new(1, -10, 0, 50)
        empty.BackgroundTransparency = 1
        empty.Text = "Tidak ada file pada kategori ini."
        empty.TextColor3 = C.gray
        empty.TextSize = 10
        empty.Font = Enum.Font.Gotham
        empty.Parent = fileList
    end

    status.Text = count .. " file pada kategori " .. currentType
    status.TextColor3 = C.gray
end

--==================================================
-- TAB HANDLERS
--==================================================

local function setType(newType)
    currentType = newType

    for id, button in pairs(tabButtons) do
        button.BackgroundColor3 = id == currentType and C.purple or C.panel
    end

    selectedFile = nil
    selectedLabel.Text = "File dipilih: belum ada"

    renderFiles()
end

tabButtons.RBXM.Activated:Connect(function()
    setType("RBXM")
end)

tabButtons.RBXL.Activated:Connect(function()
    setType("RBXL")
end)

tabButtons.OTHER.Activated:Connect(function()
    setType("OTHER")
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(renderFiles)

--==================================================
-- SCAN FOLDER
--==================================================

scanButton.Activated:Connect(function()
    if type(listfilesAPI) ~= "function" then
        status.Text = "API listfiles tidak tersedia."
        status.TextColor3 = C.red
        return
    end

    scanButton.Text = "..."
    status.Text = "Memindai folder..."
    status.TextColor3 = C.gray

    table.clear(foundFiles)
    selectedFile = nil
    selectedLabel.Text = "File dipilih: belum ada"

    local ok, files = pcall(function()
        return listfilesAPI(pathBox.Text)
    end)

    if not ok or type(files) ~= "table" then
        scanButton.Text = "SCAN"
        status.Text = "Folder tidak dapat dibaca."
        status.TextColor3 = C.red
        renderFiles()
        return
    end

    local seen = {}

    for _, path in ipairs(files) do
        if type(path) == "string" and getFileType(path) then
            if not seen[path] then
                seen[path] = true
                table.insert(foundFiles, path)
            end
        end
    end

    table.sort(foundFiles, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    scanButton.Text = "SCAN"
    renderFiles()
end)

--==================================================
-- IMPORT HANDLER
--==================================================

importButton.Activated:Connect(function()
    if not selectedFile then
        status.Text = "Pilih file terlebih dahulu."
        status.TextColor3 = C.red
        return
    end

    local fileType = getFileType(selectedFile)

    if fileType == "RBXM" then
        status.Text = "RBXM dipilih. Parser/importer kompatibel diperlukan."
        status.TextColor3 = C.red

    elseif fileType == "RBXL" then
        status.Text = "RBXL adalah file place. Buka melalui fitur Studio yang mendukungnya."
        status.TextColor3 = C.red

    else
        status.Text = "File terpilih bukan model/place yang bisa diimpor langsung."
        status.TextColor3 = C.red
    end

    warn("[Punakawan] Import belum dilakukan:", selectedFile)
end)

--==================================================
-- INITIAL STATUS
--==================================================

if type(listfilesAPI) == "function" then
    status.Text = "Pilih kategori, kemudian tekan SCAN."
    status.TextColor3 = C.green
else
    status.Text = "API listfiles tidak tersedia di executor."
    status.TextColor3 = C.red
end

print("[Punakawan] Importer GUI loaded.")
