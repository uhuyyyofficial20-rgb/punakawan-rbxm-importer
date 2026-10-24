--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- FILE SCANNER DIAGNOSTIC
-- Formats: RBXM, RBXMX, RBXL, RBXLX
--==============================================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==============================================================
-- EXECUTOR API
--==============================================================

local function getAPI(name)
    local ok, result = pcall(function()
        if type(getgenv) == "function" then
            local env = getgenv()
            if type(env[name]) == "function" then
                return env[name]
            end
        end

        if type(getfenv) == "function" then
            local env = getfenv(0)
            if type(env[name]) == "function" then
                return env[name]
            end
        end

        if type(_G) == "table"
            and type(_G[name]) == "function" then
            return _G[name]
        end
    end)

    if ok then
        return result
    end

    return nil
end

local listfilesFn = getAPI("listfiles")
local isfolderFn = getAPI("isfolder")

--==============================================================
-- GUI
--==============================================================

local previous = playerGui:FindFirstChild("PunakawanCommunityImporter")
if previous then
    previous:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PunakawanCommunityImporter"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 350, 0, 430)
main.Position = UDim2.new(0.5, -175, 0.5, -215)
main.BackgroundColor3 = Color3.fromRGB(23, 20, 36)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(135, 85, 255)
mainStroke.Thickness = 2
mainStroke.Parent = main

local function makeLabel(name, text, position, size, textSize)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Text = text
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(245, 242, 255)
    label.Font = Enum.Font.Gotham
    label.TextSize = textSize or 12
    label.TextWrapped = true
    label.Parent = main
    return label
end

local function makeButton(name, text, position, size, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.Position = position
    button.Size = size
    button.BackgroundColor3 = color or Color3.fromRGB(85, 55, 145)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 11
    button.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    return button
end

makeLabel(
    "Title",
    "PUNAKAWAN COMMUNITY IMPORTER",
    UDim2.new(0, 12, 0, 8),
    UDim2.new(1, -24, 0, 28),
    13
).Font = Enum.Font.GothamBold

makeLabel(
    "Subtitle",
    "Mobile file scanner",
    UDim2.new(0, 12, 0, 36),
    UDim2.new(1, -24, 0, 20),
    10
)

local search = Instance.new("TextBox")
search.Name = "SearchBox"
search.PlaceholderText = "Cari nama file..."
search.Text = ""
search.Position = UDim2.new(0, 12, 0, 62)
search.Size = UDim2.new(1, -24, 0, 34)
search.BackgroundColor3 = Color3.fromRGB(38, 33, 54)
search.TextColor3 = Color3.new(1, 1, 1)
search.PlaceholderColor3 = Color3.fromRGB(170, 165, 185)
search.Font = Enum.Font.Gotham
search.TextSize = 12
search.ClearTextOnFocus = false
search.Parent = main

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 7)
searchCorner.Parent = search

local formats = {"ALL", "RBXM", "RBXMX", "RBXL", "RBXLX"}
local selectedFormat = "ALL"
local formatButtons = {}

for i, format in ipairs(formats) do
    local button = makeButton(
        "Tab" .. format,
        format,
        UDim2.new(0, 12 + (i - 1) * 66, 0, 104),
        UDim2.new(0, 62, 0, 29),
        format == selectedFormat
            and Color3.fromRGB(135, 85, 255)
            or Color3.fromRGB(47, 41, 64)
    )

    button.TextSize = 9
    formatButtons[format] = button
end

local countLabel = makeLabel(
    "FileCount",
    "File ditemukan: 0",
    UDim2.new(0, 12, 0, 140),
    UDim2.new(1, -24, 0, 20),
    11
)
countLabel.TextXAlignment = Enum.TextXAlignment.Left

local fileList = Instance.new("ScrollingFrame")
fileList.Name = "FileList"
fileList.Position = UDim2.new(0, 12, 0, 164)
fileList.Size = UDim2.new(1, -24, 0, 160)
fileList.BackgroundColor3 = Color3.fromRGB(31, 27, 44)
fileList.BorderSizePixel = 0
fileList.ScrollBarThickness = 4
fileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
fileList.CanvasSize = UDim2.new(0, 0, 0, 0)
fileList.Parent = main

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 7)
listCorner.Parent = fileList

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = fileList

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 5)
listPadding.PaddingLeft = UDim.new(0, 5)
listPadding.PaddingRight = UDim.new(0, 5)
listPadding.PaddingBottom = UDim.new(0, 5)
listPadding.Parent = fileList

local status = makeLabel(
    "Status",
    "Tekan SCAN FILE.",
    UDim2.new(0, 12, 0, 330),
    UDim2.new(1, -24, 0, 39),
    10
)
status.TextXAlignment = Enum.TextXAlignment.Left

local scanButton = makeButton(
    "ScanButton",
    "SCAN FILE",
    UDim2.new(0, 12, 0, 374),
    UDim2.new(0.5, -18, 0, 32),
    Color3.fromRGB(105, 65, 190)
)

local importButton = makeButton(
    "ImportButton",
    "IMPORT",
    UDim2.new(0.5, 6, 0, 374),
    UDim2.new(0.5, -18, 0, 32),
    Color3.fromRGB(45, 130, 95)
)

local cancelButton = makeButton(
    "CancelButton",
    "CANCEL",
    UDim2.new(0, 12, 0, 412),
    UDim2.new(1, -24, 0, 25),
    Color3.fromRGB(70, 60, 85)
)

--==============================================================
-- DRAG GUI
--==============================================================

local dragging = false
local dragStart
local startPosition

main.InputBegan:Connect(function(input)
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

--==============================================================
-- SCANNER
--==============================================================

local allFiles = {}
local selectedFile

local function getExtension(path)
    local lower = string.lower(path)

    if lower:match("%.rbxmx$") then return "RBXMX" end
    if lower:match("%.rbxlx$") then return "RBXLX" end
    if lower:match("%.rbxm$") then return "RBXM" end
    if lower:match("%.rbxl$") then return "RBXL" end

    return nil
end

local function getFileName(path)
    return path:match("[^/\\]+$") or path
end

local function scanFiles()
    if type(listfilesFn) ~= "function" then
        return nil, "API listfiles tidak tersedia di Delta."
    end

    local pathsToTry = {
        "Delta/Workspace",
        "Delta\\Workspace",
        "Workspace",
        "workspace",
        "Delta",
    }

    local results = {}
    local seenFiles = {}
    local seenFolders = {}
    local queue = {}

    for _, path in ipairs(pathsToTry) do
        table.insert(queue, path)
    end

    local index = 1
    local scanned = 0
    local readable = 0

    while index <= #queue and scanned < 300 do
        local folder = queue[index]
        index += 1

        if not seenFolders[folder] then
            seenFolders[folder] = true
            scanned += 1

            local ok, entries = pcall(function()
                return listfilesFn(folder)
            end)

            if ok and type(entries) == "table" then
                readable += 1

                for _, path in ipairs(entries) do
                    if type(path) == "string" then
                        if getExtension(path) then
                            if not seenFiles[path] then
                                seenFiles[path] = true
                                table.insert(results, path)
                            end
                        elseif type(isfolderFn) == "function" then
                            local folderOK, isDir = pcall(function()
                                return isfolderFn(path)
                            end)

                            if folderOK and isDir and not seenFolders[path] then
                                table.insert(queue, path)
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return results, nil, readable
end

local function clearList()
    for _, child in ipairs(fileList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function refreshList()
    clearList()

    local visible = 0
    local query = string.lower(search.Text)

    for _, path in ipairs(allFiles) do
        local ext = getExtension(path)
        local name = getFileName(path)

        if ext and
            (selectedFormat == "ALL" or ext == selectedFormat) and
            (query == "" or string.find(string.lower(name), query, 1, true)) then

            visible += 1

            local row = Instance.new("TextButton")
            row.Name = "File" .. visible
            row.Size = UDim2.new(1, -2, 0, 32)
            row.BackgroundColor3 = Color3.fromRGB(48, 41, 66)
            row.TextColor3 = Color3.new(1, 1, 1)
            row.Text = "[" .. ext .. "] " .. name
            row.TextSize = 10
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextTruncate = Enum.TextTruncate.AtEnd
            row.Font = Enum.Font.Gotham
            row.LayoutOrder = visible
            row.Parent = fileList

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 5)
            corner.Parent = row

            row.MouseButton1Click:Connect(function()
                selectedFile = path
                status.Text = "Dipilih: " .. name

                for _, child in ipairs(fileList:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.BackgroundColor3 = Color3.fromRGB(48, 41, 66)
                    end
                end

                row.BackgroundColor3 = Color3.fromRGB(105, 65, 150)
            end)
        end
    end

    countLabel.Text = "File ditemukan: " .. visible
end

local busy = false

scanButton.MouseButton1Click:Connect(function()
    if busy then
        return
    end

    busy = true
    selectedFile = nil
    status.Text = "Memindai folder..."

    task.spawn(function()
        local ok, files, err, readable = pcall(scanFiles)

        if not ok then
            allFiles = {}
            refreshList()
            status.Text = "Kesalahan: " .. tostring(files)

        elseif type(files) == "table" then
            allFiles = files
            refreshList()

            if #files > 0 then
                status.Text = "Selesai: " .. #files .. " file ditemukan."
            elseif (readable or 0) == 0 then
                status.Text = "Folder tidak bisa dibaca oleh API Delta."
            else
                status.Text = "Folder terbaca, file model tidak ditemukan."
            end
        else
            allFiles = {}
            refreshList()
            status.Text = err or "Pemindaian gagal."
        end

        busy = false
    end)
end)

search:GetPropertyChangedSignal("Text"):Connect(refreshList)

for name, button in pairs(formatButtons) do
    button.MouseButton1Click:Connect(function()
        selectedFormat = name

        for format, tab in pairs(formatButtons) do
            tab.BackgroundColor3 =
                format == selectedFormat
                and Color3.fromRGB(135, 85, 255)
                or Color3.fromRGB(47, 41, 64)
        end

        selectedFile = nil
        refreshList()
    end)
end

cancelButton.MouseButton1Click:Connect(function()
    selectedFile = nil
    status.Text = "Pilihan dibatalkan."
end)

importButton.MouseButton1Click:Connect(function()
    if not selectedFile then
        status.Text = "Pilih file terlebih dahulu."
        return
    end

    status.Text =
        "File dipilih: " .. getFileName(selectedFile)
        .. ". Import membutuhkan mekanisme yang didukung Delta/Studio."
end)

print("[PUNAKAWAN] listfiles:", type(listfilesFn))
print("[PUNAKAWAN] isfolder:", type(isfolderFn))

if not listfilesFn then
    status.Text = "API file tidak tersedia. Scanner tidak dapat berjalan."
end
