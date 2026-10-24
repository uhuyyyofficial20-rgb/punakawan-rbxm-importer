--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- GitHub Edition
-- Supported formats: RBXM, RBXMX, RBXL, RBXLX
--==============================================================

repeat task.wait() until game:IsLoaded()

local CONFIG = {
    TITLE = "PUNAKAWAN COMMUNITY IMPORTER",
    FOLDER_PATHS = {
        "Delta/Workspace",
        "Workspace",
        "workspace",
        "Delta",
    },
    MAX_FOLDERS = 300,
    SCAN_DELAY = 0.05,
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--==============================================================
-- EXECUTOR API CHECK
--==============================================================

local function APIAvailable(name)
    local ok, result = pcall(function()
        return type(getfenv()[name]) == "function"
    end)

    if ok and result then
        return true
    end

    local ok2, result2 = pcall(function()
        return type(_G[name]) == "function"
    end)

    return ok2 and result2
end

local function GetAPI(name)
    local ok, fn = pcall(function()
        return getfenv()[name]
    end)

    if ok and type(fn) == "function" then
        return fn
    end

    if type(_G[name]) == "function" then
        return _G[name]
    end

    return nil
end

local listfilesAPI = GetAPI("listfiles")
local isfolderAPI = GetAPI("isfolder")

--==============================================================
-- GUI
--==============================================================

local oldGui = PlayerGui:FindFirstChild("PunakawanCommunityImporter")
if oldGui then
    oldGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PunakawanCommunityImporter"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 370, 0, 440)
Main.Position = UDim2.new(0.5, -185, 0.5, -220)
Main.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(135, 85, 255)
MainStroke.Thickness = 1.5
MainStroke.Parent = Main

local function MakeLabel(parent, name, text, size, position, textSize)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Text = text
    label.Size = size
    label.Position = position
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(245, 242, 255)
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = textSize or 13
    label.Parent = parent
    return label
end

local function MakeButton(parent, name, text, size, position, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = text
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color or Color3.fromRGB(70, 48, 120)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.AutoButtonColor = true
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    return button
end

MakeLabel(
    Main,
    "Title",
    CONFIG.TITLE,
    UDim2.new(1, -90, 0, 35),
    UDim2.new(0, 12, 0, 5),
    14
).TextXAlignment = Enum.TextXAlignment.Left

local MinimizeButton = MakeButton(
    Main,
    "MinimizeButton",
    "—",
    UDim2.new(0, 30, 0, 27),
    UDim2.new(1, -70, 0, 8),
    Color3.fromRGB(65, 52, 100)
)

local CloseButton = MakeButton(
    Main,
    "CloseButton",
    "X",
    UDim2.new(0, 30, 0, 27),
    UDim2.new(1, -36, 0, 8),
    Color3.fromRGB(125, 45, 65)
)

MakeLabel(
    Main,
    "Subtitle",
    "Import manager • Local file scanner",
    UDim2.new(1, -24, 0, 20),
    UDim2.new(0, 12, 0, 39),
    10
).TextXAlignment = Enum.TextXAlignment.Left

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchBox"
SearchBox.PlaceholderText = "Cari nama file..."
SearchBox.Text = ""
SearchBox.Size = UDim2.new(1, -24, 0, 34)
SearchBox.Position = UDim2.new(0, 12, 0, 66)
SearchBox.BackgroundColor3 = Color3.fromRGB(36, 32, 51)
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.PlaceholderColor3 = Color3.fromRGB(165, 158, 185)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = Main

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 7)
SearchCorner.Parent = SearchBox

local FormatFrame = Instance.new("Frame")
FormatFrame.Name = "FormatTabs"
FormatFrame.Size = UDim2.new(1, -24, 0, 32)
FormatFrame.Position = UDim2.new(0, 12, 0, 108)
FormatFrame.BackgroundTransparency = 1
FormatFrame.Parent = Main

local FormatLayout = Instance.new("UIListLayout")
FormatLayout.FillDirection = Enum.FillDirection.Horizontal
FormatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
FormatLayout.VerticalAlignment = Enum.VerticalAlignment.Center
FormatLayout.Padding = UDim.new(0, 5)
FormatLayout.Parent = FormatFrame

local formats = {"ALL", "RBXM", "RBXMX", "RBXL", "RBXLX"}
local selectedFormat = "ALL"
local formatButtons = {}

for _, formatName in ipairs(formats) do
    local button = Instance.new("TextButton")
    button.Name = formatName .. "Tab"
    button.Text = formatName
    button.Size = UDim2.new(0, 63, 0, 29)
    button.BackgroundColor3 = formatName == selectedFormat
        and Color3.fromRGB(135, 85, 255)
        or Color3.fromRGB(45, 40, 62)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 10
    button.Parent = FormatFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button

    formatButtons[formatName] = button
end

local FileCount = MakeLabel(
    Main,
    "FileCount",
    "File ditemukan: 0",
    UDim2.new(1, -24, 0, 20),
    UDim2.new(0, 12, 0, 147),
    11
)
FileCount.TextXAlignment = Enum.TextXAlignment.Left

local FileList = Instance.new("ScrollingFrame")
FileList.Name = "FileList"
FileList.Size = UDim2.new(1, -24, 0, 175)
FileList.Position = UDim2.new(0, 12, 0, 170)
FileList.BackgroundColor3 = Color3.fromRGB(30, 27, 43)
FileList.BorderSizePixel = 0
FileList.ScrollBarThickness = 4
FileList.CanvasSize = UDim2.new(0, 0, 0, 0)
FileList.Parent = Main

local ListCorner = Instance.new("UICorner")
ListCorner.CornerRadius = UDim.new(0, 7)
ListCorner.Parent = FileList

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 4)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = FileList

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 6)
ListPadding.PaddingBottom = UDim.new(0, 6)
ListPadding.PaddingLeft = UDim.new(0, 6)
ListPadding.PaddingRight = UDim.new(0, 6)
ListPadding.Parent = FileList

local Status = MakeLabel(
    Main,
    "Status",
    "Tekan SCAN FILE untuk memulai.",
    UDim2.new(1, -24, 0, 24),
    UDim2.new(0, 12, 0, 350),
    10
)
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextWrapped = true

local ScanButton = MakeButton(
    Main,
    "ScanButton",
    "SCAN FILE",
    UDim2.new(0.48, -8, 0, 35),
    UDim2.new(0, 12, 0, 390),
    Color3.fromRGB(105, 65, 190)
)

local ImportButton = MakeButton(
    Main,
    "ImportButton",
    "IMPORT",
    UDim2.new(0.48, -8, 0, 35),
    UDim2.new(0.52, -4, 0, 390),
    Color3.fromRGB(45, 130, 95)
)

local CancelButton = MakeButton(
    Main,
    "CancelButton",
    "CANCEL",
    UDim2.new(1, -24, 0, 28),
    UDim2.new(0, 12, 1, -33),
    Color3.fromRGB(70, 60, 85)
)

--==============================================================
-- FLOATING REOPEN BUTTON
--==============================================================

local ReopenButton = Instance.new("TextButton")
ReopenButton.Name = "ReopenButton"
ReopenButton.Size = UDim2.new(0, 52, 0, 52)
ReopenButton.Position = UDim2.new(0, 20, 0.5, -26)
ReopenButton.BackgroundColor3 = Color3.fromRGB(105, 65, 190)
ReopenButton.Text = "P"
ReopenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ReopenButton.TextSize = 22
ReopenButton.Font = Enum.Font.GothamBlack
ReopenButton.Visible = false
ReopenButton.Active = true
ReopenButton.Parent = ScreenGui

local ReopenCorner = Instance.new("UICorner")
ReopenCorner.CornerRadius = UDim.new(1, 0)
ReopenCorner.Parent = ReopenButton

local ReopenStroke = Instance.new("UIStroke")
ReopenStroke.Color = Color3.fromRGB(190, 150, 255)
ReopenStroke.Thickness = 2
ReopenStroke.Parent = ReopenButton

--==============================================================
-- DRAG SUPPORT
--==============================================================

local function MakeDraggable(object, dragHandle)
    dragHandle = dragHandle or object

    local dragging = false
    local dragStart
    local startPosition
    local inputObject

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = object.Position
            inputObject = input

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
            or input == inputObject
        ) then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)
end

MakeDraggable(Main, Main)
MakeDraggable(ReopenButton, ReopenButton)

--==============================================================
-- FILE SCANNER
--==============================================================

local allFiles = {}
local selectedFile = nil
local scanning = false

local function IsSupportedFile(path)
    local lower = string.lower(path)

    return lower:match("%.rbxm$")
        or lower:match("%.rbxmx$")
        or lower:match("%.rbxl$")
        or lower:match("%.rbxlx$")
end

local function GetExtension(path)
    local lower = string.lower(path)

    if lower:match("%.rbxmx$") then return "RBXMX" end
    if lower:match("%.rbxlx$") then return "RBXLX" end
    if lower:match("%.rbxm$") then return "RBXM" end
    if lower:match("%.rbxl$") then return "RBXL" end

    return ""
end

local function GetFileName(path)
    return path:match("[^/\\]+$") or path
end

local function ScanFiles()
    if type(listfilesAPI) ~= "function" then
        return nil, "Delta tidak menyediakan listfiles()."
    end

    local found = {}
    local seenFiles = {}
    local seenFolders = {}
    local queue = {}

    for _, folder in ipairs(CONFIG.FOLDER_PATHS) do
        table.insert(queue, folder)
    end

    local head = 1
    local scanned = 0

    while head <= #queue and scanned < CONFIG.MAX_FOLDERS do
        local folder = queue[head]
        head += 1

        if not seenFolders[folder] then
            seenFolders[folder] = true
            scanned += 1

            local ok, result = pcall(function()
                return listfilesAPI(folder)
            end)

            if ok and type(result) == "table" then
                for _, path in ipairs(result) do
                    if type(path) == "string" then
                        if IsSupportedFile(path) then
                            if not seenFiles[path] then
                                seenFiles[path] = true
                                table.insert(found, path)
                            end
                        elseif type(isfolderAPI) == "function" then
                            local folderOK, isDir = pcall(function()
                                return isfolderAPI(path)
                            end)

                            if folderOK and isDir and not seenFolders[path] then
                                table.insert(queue, path)
                            end
                        end
                    end
                end
            end

            task.wait(CONFIG.SCAN_DELAY)
        end
    end

    table.sort(found, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return found
end

local function ClearFileList()
    for _, child in ipairs(FileList:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function RefreshFileList()
    ClearFileList()

    local visibleCount = 0
    local searchText = string.lower(SearchBox.Text)

    for _, path in ipairs(allFiles) do
        local extension = GetExtension(path)
        local name = GetFileName(path)

        local formatMatches = selectedFormat == "ALL"
            or extension == selectedFormat

        local searchMatches = searchText == ""
            or string.find(string.lower(name), searchText, 1, true) ~= nil

        if formatMatches and searchMatches then
            visibleCount += 1

            local button = Instance.new("TextButton")
            button.Name = "File_" .. visibleCount
            button.Size = UDim2.new(1, -2, 0, 34)
            button.BackgroundColor3 = Color3.fromRGB(45, 40, 62)
            button.Text = "  [" .. extension .. "]  " .. name
            button.TextColor3 = Color3.fromRGB(240, 235, 255)
            button.TextSize = 11
            button.Font = Enum.Font.Gotham
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.TextTruncate = Enum.TextTruncate.AtEnd
            button.LayoutOrder = visibleCount
            button.Parent = FileList

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 5)
            corner.Parent = button

            button.MouseButton1Click:Connect(function()
                selectedFile = path
                Status.Text = "Dipilih: " .. name

                for _, item in ipairs(FileList:GetChildren()) do
                    if item:IsA("TextButton") then
                        item.BackgroundColor3 = Color3.fromRGB(45, 40, 62)
                    end
                end

                button.BackgroundColor3 = Color3.fromRGB(105, 65, 150)
            end)
        end
    end

    FileCount.Text = "File ditemukan: " .. visibleCount
    FileList.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 12)

    if visibleCount == 0 then
        Status.Text = "Tidak ada file yang cocok dengan filter."
    end
end

local function RefreshFiles()
    if scanning then
        return
    end

    scanning = true
    selectedFile = nil
    Status.Text = "Memindai folder file..."

    task.spawn(function()
        local result, err = ScanFiles()

        if result then
            allFiles = result
            RefreshFileList()

            if #allFiles > 0 then
                Status.Text = "Pemindaian selesai. File ditemukan: " .. #allFiles
            else
                Status.Text = "File tidak ditemukan. Periksa lokasi dan akses Delta."
            end
        else
            allFiles = {}
            RefreshFileList()
            Status.Text = err or "Gagal memindai folder."
        end

        scanning = false
    end)
end

--==============================================================
-- BUTTON EVENTS
--==============================================================

ScanButton.MouseButton1Click:Connect(RefreshFiles)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RefreshFileList()
end)

for formatName, button in pairs(formatButtons) do
    button.MouseButton1Click:Connect(function()
        selectedFormat = formatName

        for name, tab in pairs(formatButtons) do
            tab.BackgroundColor3 = name == selectedFormat
                and Color3.fromRGB(135, 85, 255)
                or Color3.fromRGB(45, 40, 62)
        end

        selectedFile = nil
        RefreshFileList()
    end)
end

MinimizeButton.MouseButton1Click:Connect(function()
    Main.Visible = false
    ReopenButton.Visible = true
end)

ReopenButton.MouseButton1Click:Connect(function()
    Main.Visible = true
    ReopenButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

CancelButton.MouseButton1Click:Connect(function()
    selectedFile = nil
    Status.Text = "Pilihan file dibatalkan."
end)

ImportButton.MouseButton1Click:Connect(function()
    if not selectedFile then
        Status.Text = "Pilih file terlebih dahulu."
        return
    end

    Status.Text = "File terpilih: " .. GetFileName(selectedFile)
        .. ". Fungsi import belum tersedia di script ini."
end)

--==============================================================
-- STARTUP
--==============================================================

if not listfilesAPI then
    Status.Text = "API listfiles tidak tersedia. Scan file tidak dapat dilakukan."
else
    task.delay(0.5, RefreshFiles)
end
