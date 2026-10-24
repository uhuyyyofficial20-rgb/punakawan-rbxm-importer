--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- Version: Improved Scanner + Fixed GUI Layout
-- Supported extensions: RBXM, RBXMX, RBXL, RBXLX
--==============================================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local CONFIG = {
    TITLE = "PUNAKAWAN COMMUNITY IMPORTER",

    -- Kemungkinan lokasi folder yang dapat dicoba.
    FOLDERS = {
        "Delta/Workspace",
        "Delta\\Workspace",
        "Workspace",
        "workspace",
        "Delta",
    },

    MAX_FOLDERS = 300,
    SCAN_DELAY = 0.03,
}

--==============================================================
-- EXECUTOR API
--==============================================================

local function GetFunction(name)
    local ok, value = pcall(function()
        if type(getgenv) == "function" then
            local env = getgenv()
            if type(env) == "table" and type(env[name]) == "function" then
                return env[name]
            end
        end

        if type(getfenv) == "function" then
            local env = getfenv(0)
            if type(env) == "table" and type(env[name]) == "function" then
                return env[name]
            end
        end

        if type(_G) == "table" and type(_G[name]) == "function" then
            return _G[name]
        end

        return nil
    end)

    if ok and type(value) == "function" then
        return value
    end

    return nil
end

local listfilesAPI = GetFunction("listfiles")
local isfolderAPI = GetFunction("isfolder")

--==============================================================
-- REMOVE PREVIOUS GUI
--==============================================================

local oldGui = PlayerGui:FindFirstChild("PunakawanCommunityImporter")

if oldGui then
    oldGui:Destroy()
end

--==============================================================
-- GUI ROOT
--==============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PunakawanCommunityImporter"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

--==============================================================
-- GUI HELPERS
--==============================================================

local function AddCorner(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = object
    return corner
end

local function AddStroke(object, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(135, 85, 255)
    stroke.Thickness = thickness or 1
    stroke.Parent = object
    return stroke
end

local function CreateLabel(parent, name, text, size, position, textSize)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Text = text
    label.Size = size
    label.Position = position
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(245, 242, 255)
    label.Font = Enum.Font.Gotham
    label.TextSize = textSize or 12
    label.TextWrapped = true
    label.Parent = parent
    return label
end

local function CreateButton(parent, name, text, size, position, color)
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

    AddCorner(button, 7)

    return button
end

--==============================================================
-- MAIN WINDOW
--==============================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 370, 0, 470)
Main.Position = UDim2.new(0.5, -185, 0.5, -235)
Main.BackgroundColor3 = Color3.fromRGB(22, 20, 34)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

AddCorner(Main, 14)
AddStroke(Main, Color3.fromRGB(135, 85, 255), 2)

-- Header
local Title = CreateLabel(
    Main,
    "Title",
    CONFIG.TITLE,
    UDim2.new(1, -105, 0, 32),
    UDim2.new(0, 12, 0, 7),
    13
)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextTruncate = Enum.TextTruncate.AtEnd
Title.Font = Enum.Font.GothamSemibold

local MinimizeButton = CreateButton(
    Main,
    "MinimizeButton",
    "—",
    UDim2.new(0, 30, 0, 28),
    UDim2.new(1, -70, 0, 8),
    Color3.fromRGB(65, 52, 100)
)

local CloseButton = CreateButton(
    Main,
    "CloseButton",
    "X",
    UDim2.new(0, 30, 0, 28),
    UDim2.new(1, -36, 0, 8),
    Color3.fromRGB(125, 45, 65)
)

local Subtitle = CreateLabel(
    Main,
    "Subtitle",
    "Import manager • Local file scanner",
    UDim2.new(1, -24, 0, 20),
    UDim2.new(0, 12, 0, 39),
    10
)
Subtitle.TextXAlignment = Enum.TextXAlignment.Left

-- Search box
local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchBox"
SearchBox.PlaceholderText = "Cari nama file..."
SearchBox.Text = ""
SearchBox.Size = UDim2.new(1, -24, 0, 36)
SearchBox.Position = UDim2.new(0, 12, 0, 65)
SearchBox.BackgroundColor3 = Color3.fromRGB(36, 32, 51)
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.PlaceholderColor3 = Color3.fromRGB(165, 158, 185)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = Main

AddCorner(SearchBox, 7)

--==============================================================
-- FORMAT TABS
--==============================================================

local FormatFrame = Instance.new("Frame")
FormatFrame.Name = "FormatTabs"
FormatFrame.Size = UDim2.new(1, -24, 0, 32)
FormatFrame.Position = UDim2.new(0, 12, 0, 109)
FormatFrame.BackgroundTransparency = 1
FormatFrame.Parent = Main

local FormatLayout = Instance.new("UIListLayout")
FormatLayout.FillDirection = Enum.FillDirection.Horizontal
FormatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
FormatLayout.VerticalAlignment = Enum.VerticalAlignment.Center
FormatLayout.Padding = UDim.new(0, 5)
FormatLayout.Parent = FormatFrame

local Formats = {"ALL", "RBXM", "RBXMX", "RBXL", "RBXLX"}
local SelectedFormat = "ALL"
local FormatButtons = {}

for _, formatName in ipairs(Formats) do
    local button = CreateButton(
        FormatFrame,
        formatName .. "Tab",
        formatName,
        UDim2.new(0, 63, 0, 29),
        UDim2.new(),
        formatName == SelectedFormat
            and Color3.fromRGB(135, 85, 255)
            or Color3.fromRGB(45, 40, 62)
    )

    button.TextSize = 10
    FormatButtons[formatName] = button
end

--==============================================================
-- FILE LIST
--==============================================================

local FileCount = CreateLabel(
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
FileList.Size = UDim2.new(1, -24, 0, 178)
FileList.Position = UDim2.new(0, 12, 0, 171)
FileList.BackgroundColor3 = Color3.fromRGB(30, 27, 43)
FileList.BorderSizePixel = 0
FileList.ScrollBarThickness = 4
FileList.CanvasSize = UDim2.new(0, 0, 0, 0)
FileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
FileList.ScrollingDirection = Enum.ScrollingDirection.Y
FileList.Parent = Main

AddCorner(FileList, 8)

local FileListLayout = Instance.new("UIListLayout")
FileListLayout.Padding = UDim.new(0, 4)
FileListLayout.SortOrder = Enum.SortOrder.LayoutOrder
FileListLayout.Parent = FileList

local FilePadding = Instance.new("UIPadding")
FilePadding.PaddingTop = UDim.new(0, 6)
FilePadding.PaddingBottom = UDim.new(0, 6)
FilePadding.PaddingLeft = UDim.new(0, 6)
FilePadding.PaddingRight = UDim.new(0, 6)
FilePadding.Parent = FileList

-- Status
local Status = CreateLabel(
    Main,
    "Status",
    "Tekan SCAN FILE untuk memulai.",
    UDim2.new(1, -24, 0, 35),
    UDim2.new(0, 12, 0, 354),
    10
)
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Center

-- Bottom buttons: separated rows, no overlap
local ScanButton = CreateButton(
    Main,
    "ScanButton",
    "SCAN FILE",
    UDim2.new(0.5, -16, 0, 34),
    UDim2.new(0, 12, 0, 394),
    Color3.fromRGB(105, 65, 190)
)

local ImportButton = CreateButton(
    Main,
    "ImportButton",
    "IMPORT",
    UDim2.new(0.5, -16, 0, 34),
    UDim2.new(0.5, 4, 0, 394),
    Color3.fromRGB(45, 130, 95)
)

local CancelButton = CreateButton(
    Main,
    "CancelButton",
    "CANCEL",
    UDim2.new(1, -24, 0, 27),
    UDim2.new(0, 12, 0, 434),
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

AddCorner(ReopenButton, 26)
AddStroke(ReopenButton, Color3.fromRGB(190, 150, 255), 2)

--==============================================================
-- DRAG SUPPORT
--==============================================================

local function MakeDraggable(object, handle)
    handle = handle or object

    local dragging = false
    local dragStart
    local startPosition

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = object.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

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

local AllFiles = {}
local SelectedFile = nil
local IsScanning = false

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
        return nil,
            "API listfiles() tidak tersedia. Delta harus menyediakan akses file."
    end

    local found = {}
    local seenFiles = {}
    local seenFolders = {}
    local queue = {}

    for _, folder in ipairs(CONFIG.FOLDERS) do
        table.insert(queue, folder)
    end

    local head = 1
    local scannedFolders = 0
    local successfulFolders = 0

    while head <= #queue and scannedFolders < CONFIG.MAX_FOLDERS do
        local folder = queue[head]
        head += 1

        if not seenFolders[folder] then
            seenFolders[folder] = true
            scannedFolders += 1

            local ok, result = pcall(function()
                return listfilesAPI(folder)
            end)

            if ok and type(result) == "table" then
                successfulFolders += 1

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

    return found, nil, successfulFolders
end

--==============================================================
-- REFRESH FILE LIST
--==============================================================

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
    local search = string.lower(SearchBox.Text)

    for _, path in ipairs(AllFiles) do
        local extension = GetExtension(path)
        local name = GetFileName(path)

        local formatMatches =
            SelectedFormat == "ALL" or extension == SelectedFormat

        local searchMatches =
            search == ""
            or string.find(string.lower(name), search, 1, true) ~= nil

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

            AddCorner(button, 5)

            button.MouseButton1Click:Connect(function()
                SelectedFile = path
                Status.Text = "File dipilih: " .. name

                for _, item in ipairs(FileList:GetChildren()) do
                    if item:IsA("TextButton") then
                        item.BackgroundColor3 =
                            Color3.fromRGB(45, 40, 62)
                    end
                end

                button.BackgroundColor3 =
                    Color3.fromRGB(105, 65, 150)
            end)
        end
    end

    FileCount.Text = "File ditemukan: " .. visibleCount

    if visibleCount == 0 then
        FileList.CanvasPosition = Vector2.new(0, 0)
    end
end

--==============================================================
-- SCAN BUTTON ACTION
--==============================================================

local function RefreshFiles()
    if IsScanning then
        return
    end

    IsScanning = true
    SelectedFile = nil
    Status.Text = "Memindai folder Delta..."

    task.spawn(function()
        local ok, result, err, successfulFolders = pcall(ScanFiles)

        if not ok then
            AllFiles = {}
            RefreshFileList()
            Status.Text = "Kesalahan pemindaian: " .. tostring(result)

        elseif type(result) == "table" then
            AllFiles = result
            RefreshFileList()

            if #AllFiles > 0 then
                Status.Text = "Selesai. Ditemukan " .. #AllFiles .. " file."
            elseif (successfulFolders or 0) == 0 then
                Status.Text =
                    "Folder tidak bisa diakses. Periksa API dan path Delta."
            else
                Status.Text =
                    "Folder terbaca, tetapi file model tidak ditemukan."
            end
        else
            AllFiles = {}
            RefreshFileList()
            Status.Text = err or "Pemindaian gagal."
        end

        IsScanning = false
    end)
end

--==============================================================
-- EVENTS
--==============================================================

ScanButton.MouseButton1Click:Connect(RefreshFiles)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RefreshFileList()
end)

for formatName, button in pairs(FormatButtons) do
    button.MouseButton1Click:Connect(function()
        SelectedFormat = formatName

        for name, tab in pairs(FormatButtons) do
            tab.BackgroundColor3 =
                name == SelectedFormat
                and Color3.fromRGB(135, 85, 255)
                or Color3.fromRGB(45, 40, 62)
        end

        SelectedFile = nil
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
    SelectedFile = nil
    Status.Text = "Pilihan file dibatalkan."
end)

ImportButton.MouseButton1Click:Connect(function()
    if not SelectedFile then
        Status.Text = "Pilih file terlebih dahulu."
        return
    end

    Status.Text =
        "File terpilih: " .. GetFileName(SelectedFile)
        .. ". Proses impor belum diimplementasikan."
end)

--==============================================================
-- STARTUP
--==============================================================

if type(listfilesAPI) ~= "function" then
    Status.Text =
        "API listfiles tidak tersedia. File tidak bisa dipindai."
else
    task.delay(0.5, RefreshFiles)
end

print("[PUNAKAWAN COMMUNITY IMPORTER] GUI loaded.")
print("[PUNAKAWAN COMMUNITY IMPORTER] listfiles:", type(listfilesAPI))
print("[PUNAKAWAN COMMUNITY IMPORTER] isfolder:", type(isfolderAPI))
