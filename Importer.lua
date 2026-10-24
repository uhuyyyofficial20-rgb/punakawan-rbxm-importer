--====================================================
-- PUNAKAWAN RBXM IMPORTER
-- Mobile GUI + Workspace File Scanner
--====================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local GUI_NAME = "PunakawanImporterGUI"
local TARGET_PATH = "/storage/emulated/0/Delta/Workspace/"

local COLORS = {
    Background = Color3.fromRGB(18, 18, 25),
    Panel = Color3.fromRGB(31, 29, 43),
    Purple = Color3.fromRGB(145, 75, 255),
    White = Color3.fromRGB(245, 245, 255),
    Gray = Color3.fromRGB(165, 165, 180),
    Green = Color3.fromRGB(75, 225, 130),
    Red = Color3.fromRGB(255, 75, 95)
}

--====================================================
-- DETEKSI API EXECUTOR
--====================================================

local function getExecutorAPI(name)
    local environments = {}

    pcall(function()
        if type(getgenv) == "function" then
            table.insert(environments, getgenv())
        end
    end)

    pcall(function()
        if type(getfenv) == "function" then
            table.insert(environments, getfenv(0))
        end
    end)

    table.insert(environments, _G)

    for _, env in ipairs(environments) do
        local ok, value = pcall(function()
            return env[name]
        end)

        if ok and type(value) == "function" then
            return value
        end
    end

    return nil
end

local listfilesAPI = getExecutorAPI("listfiles")

--====================================================
-- HAPUS GUI LAMA
--====================================================

local player = Players.LocalPlayer

if not player then
    warn("[Punakawan] LocalPlayer tidak tersedia.")
    return
end

local playerGui = player:WaitForChild("PlayerGui")

local oldGUI = playerGui:FindFirstChild(GUI_NAME)

if oldGUI then
    oldGUI:Destroy()
end

--====================================================
-- SCREEN GUI
--====================================================

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 330, 0, 410)
main.Position = UDim2.new(0.5, -165, 0.5, -205)
main.BackgroundColor3 = COLORS.Background
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local outline = Instance.new("UIStroke")
outline.Color = COLORS.Purple
outline.Thickness = 2
outline.Parent = main

--====================================================
-- HEADER
--====================================================

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 45)
header.BackgroundColor3 = Color3.fromRGB(43, 28, 65)
header.BorderSizePixel = 0
header.Active = true
header.Parent = main

local title = Instance.new("TextLabel")
title.Position = UDim2.new(0, 12, 0, 0)
title.Size = UDim2.new(1, -110, 1, 0)
title.BackgroundTransparency = 1
title.Text = "PUNAKAWAN | IMPORTER"
title.TextColor3 = COLORS.White
title.TextSize = 12
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local function createButton(parent, name, text, pos, size, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Position = pos
    button.Size = size
    button.Text = text
    button.TextColor3 = COLORS.White
    button.TextSize = 16
    button.Font = Enum.Font.GothamBold
    button.BackgroundColor3 = color
    button.BorderSizePixel = 0
    button.Parent = parent

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)

    return button
end

local minimize = createButton(
    header, "Minimize", "—",
    UDim2.new(1, -72, 0, 8),
    UDim2.new(0, 27, 0, 28),
    COLORS.Panel
)

local close = createButton(
    header, "Close", "X",
    UDim2.new(1, -38, 0, 8),
    UDim2.new(0, 28, 0, 28),
    COLORS.Red
)

--====================================================
-- STATUS
--====================================================

local status = Instance.new("TextLabel")
status.Position = UDim2.new(0, 12, 0, 53)
status.Size = UDim2.new(1, -24, 0, 42)
status.BackgroundColor3 = COLORS.Panel
status.BorderSizePixel = 0
status.Text = "Folder: Delta/Workspace"
status.TextColor3 = COLORS.Gray
status.TextSize = 11
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.Parent = main

Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

--====================================================
-- PATH
--====================================================

local pathBox = Instance.new("TextBox")
pathBox.Position = UDim2.new(0, 12, 0, 102)
pathBox.Size = UDim2.new(1, -24, 0, 35)
pathBox.BackgroundColor3 = COLORS.Panel
pathBox.BorderSizePixel = 0
pathBox.Text = TARGET_PATH
pathBox.TextColor3 = COLORS.White
pathBox.TextSize = 10
pathBox.Font = Enum.Font.Gotham
pathBox.ClearTextOnFocus = false
pathBox.Parent = main

Instance.new("UICorner", pathBox).CornerRadius = UDim.new(0, 6)

--====================================================
-- SCAN BUTTON
--====================================================

local scanButton = createButton(
    main, "Scan", "SCAN FILE",
    UDim2.new(0, 12, 0, 146),
    UDim2.new(1, -24, 0, 36),
    COLORS.Purple
)

scanButton.TextSize = 12

--====================================================
-- SEARCH
--====================================================

local searchBox = Instance.new("TextBox")
searchBox.Position = UDim2.new(0, 12, 0, 190)
searchBox.Size = UDim2.new(1, -24, 0, 32)
searchBox.BackgroundColor3 = COLORS.Panel
searchBox.BorderSizePixel = 0
searchBox.Text = ""
searchBox.PlaceholderText = "Cari file..."
searchBox.TextColor3 = COLORS.White
searchBox.PlaceholderColor3 = COLORS.Gray
searchBox.TextSize = 11
searchBox.Font = Enum.Font.Gotham
searchBox.ClearTextOnFocus = false
searchBox.Parent = main

Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)

--====================================================
-- FILE LIST
--====================================================

local fileList = Instance.new("ScrollingFrame")
fileList.Position = UDim2.new(0, 12, 0, 230)
fileList.Size = UDim2.new(1, -24, 1, -242)
fileList.BackgroundColor3 = COLORS.Panel
fileList.BorderSizePixel = 0
fileList.ScrollBarThickness = 4
fileList.ScrollBarImageColor3 = COLORS.Purple
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

--====================================================
-- REOPEN BUTTON
--====================================================

local reopen = createButton(
    gui, "Reopen", "📂",
    UDim2.new(0, 15, 0.5, -25),
    UDim2.new(0, 50, 0, 50),
    COLORS.Purple
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

--====================================================
-- DRAG GUI
--====================================================

local dragging = false
local dragStart
local startPosition

header.InputBegan:Connect(function(input)
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

--====================================================
-- EKSTENSI FILE
--====================================================

local extensions = {
    ".rbxm", ".rbxmx",
    ".rbxl", ".rbxlx",
    ".lua", ".luau",
    ".model", ".anim", ".json"
}

local function isRobloxFile(path)
    local lower = string.lower(path)

    for _, ext in ipairs(extensions) do
        if lower:sub(-#ext) == ext then
            return true
        end
    end

    return false
end

--====================================================
-- FILE LIST RENDER
--====================================================

local foundFiles = {}

local function renderFiles()
    for _, child in ipairs(fileList:GetChildren()) do
        if child:IsA("TextButton") or child.Name == "EmptyMessage" then
            child:Destroy()
        end
    end

    local query = string.lower(searchBox.Text)
    local count = 0

    for _, path in ipairs(foundFiles) do
        local name = path:gsub("\\", "/"):match("([^/]+)$") or path

        if query == "" or string.find(string.lower(name), query, 1, true) then
            count += 1

            local row = createButton(
                fileList,
                "File_" .. count,
                name,
                UDim2.new(),
                UDim2.new(1, -5, 0, 42),
                COLORS.Background
            )

            row.LayoutOrder = count
            row.TextSize = 10
            row.TextXAlignment = Enum.TextXAlignment.Left

            row.Activated:Connect(function()
                status.Text = "Dipilih: " .. name
                status.TextColor3 = COLORS.Green
            end)
        end
    end

    if count == 0 then
        local empty = Instance.new("TextLabel")
        empty.Name = "EmptyMessage"
        empty.Size = UDim2.new(1, -10, 0, 55)
        empty.BackgroundTransparency = 1
        empty.Text = "File belum ditemukan."
        empty.TextColor3 = COLORS.Gray
        empty.TextSize = 11
        empty.Font = Enum.Font.Gotham
        empty.Parent = fileList
    end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(renderFiles)

--====================================================
-- SCANNER
--====================================================

scanButton.Activated:Connect(function()
    if type(listfilesAPI) ~= "function" then
        status.Text = "API listfiles tidak tersedia."
        status.TextColor3 = COLORS.Red
        return
    end

    scanButton.Text = "MEMINDAI..."
    status.Text = "Membaca folder..."
    status.TextColor3 = COLORS.Gray

    table.clear(foundFiles)

    local ok, files = pcall(function()
        return listfilesAPI(pathBox.Text)
    end)

    if not ok or type(files) ~= "table" then
        scanButton.Text = "SCAN FILE"
        status.Text = "Folder tidak dapat dibaca."
        status.TextColor3 = COLORS.Red
        renderFiles()
        return
    end

    local seen = {}

    for _, path in ipairs(files) do
        if type(path) == "string" and isRobloxFile(path) then
            if not seen[path] then
                seen[path] = true
                table.insert(foundFiles, path)
            end
        end
    end

    table.sort(foundFiles)

    renderFiles()
    scanButton.Text = "SCAN FILE"

    if #foundFiles > 0 then
        status.Text = "Ditemukan " .. #foundFiles .. " file."
        status.TextColor3 = COLORS.Green
    else
        status.Text = "0 file ditemukan di folder ini."
        status.TextColor3 = COLORS.Red
    end
end)

--====================================================
-- SELESAI
--====================================================

if type(listfilesAPI) == "function" then
    status.Text = "Siap memindai Delta/Workspace."
    status.TextColor3 = COLORS.Green
else
    status.Text = "Executor tidak menyediakan listfiles()."
    status.TextColor3 = COLORS.Red
end

print("[Punakawan Importer] GUI loaded.")
