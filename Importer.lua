--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER
-- Mobile File Scanner
-- Supported: RBXM, RBXMX, RBXL, RBXLX
--==============================================================

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local CONFIG = {
    TITLE = "PUNAKAWAN COMMUNITY IMPORTER",
    MAX_FOLDERS = 300,
    SCAN_DELAY = 0.03,

    FOLDERS = {
        "Delta/Workspace",
        "Delta\\Workspace",
        "Workspace",
        "workspace",
        "Delta",
    },
}

--==============================================================
-- EXECUTOR API
--==============================================================

local function GetFunction(name)
    local function checkEnvironment(env)
        if type(env) == "table" and type(env[name]) == "function" then
            return env[name]
        end
        return nil
    end

    local ok, result = pcall(function()
        if type(getgenv) == "function" then
            local fn = checkEnvironment(getgenv())
            if fn then
                return fn
            end
        end

        if type(getfenv) == "function" then
            local fn = checkEnvironment(getfenv(0))
            if fn then
                return fn
            end
        end

        return checkEnvironment(_G)
    end)

    if ok then
        return result
    end

    return nil
end

local listfilesAPI = GetFunction("listfiles")
local isfolderAPI = GetFunction("isfolder")
local isfileAPI = GetFunction("isfile")

--==============================================================
-- GUI ROOT
--==============================================================

local previous = PlayerGui:FindFirstChild("PunakawanCommunityImporter")
if previous then
    previous:Destroy()
end

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

local function Corner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = object
    return c
end

local function Stroke(object, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(135, 85, 255)
    s.Thickness = thickness or 1
    s.Parent = object
    return s
end

local function Label(parent, name, text, size, position, textSize)
    local obj = Instance.new("TextLabel")
    obj.Name = name
    obj.Text = text
    obj.Size = size
    obj.Position = position
    obj.BackgroundTransparency = 1
    obj.TextColor3 = Color3.fromRGB(245, 242, 255)
    obj.Font = Enum.Font.Gotham
    obj.TextSize = textSize or 12
    obj.TextWrapped = true
    obj.Parent = parent
    return obj
end

local function Button(parent, name, text, size, position, color)
    local obj = Instance.new("TextButton")
    obj.Name = name
    obj.Text = text
    obj.Size = size
    obj.Position = position
    obj.BackgroundColor3 = color or Color3.fromRGB(70, 48, 120)
    obj.TextColor3 = Color3.fromRGB(255, 255, 255)
    obj.Font = Enum.Font.GothamSemibold
    obj.TextSize = 12
    obj.AutoButtonColor = true
    obj.Parent = parent
    Corner(obj, 7)
    return obj
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

Corner(Main, 14)
Stroke(Main, Color3.fromRGB(135, 85, 255), 2)

local Title = Label(
    Main, "Title", CONFIG.TITLE,
    UDim2.new(1, -105, 0, 32),
    UDim2.new(0, 12, 0, 7), 13
)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextTruncate = Enum.TextTruncate.AtEnd
Title.Font = Enum.Font.GothamSemibold

local MinimizeButton = Button(
    Main, "MinimizeButton", "—",
    UDim2.new(0, 30, 0, 28),
    UDim2.new(1, -70, 0, 8),
    Color3.fromRGB(65, 52, 100)
)

local CloseButton = Button(
    Main, "CloseButton", "X",
    UDim2.new(0, 30, 0, 28),
    UDim2.new(1, -36, 0, 8),
    Color3.fromRGB(125, 45, 65)
)

local Subtitle = Label(
    Main, "Subtitle",
    "Import manager • Local file scanner",
    UDim2.new(1, -24, 0, 20),
    UDim2.new(0, 12, 0, 39), 10
)
Subtitle.TextXAlignment = Enum.TextXAlignment.Left

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
Corner(SearchBox, 7)

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

for _, format in ipairs(Formats) do
    local b = Button(
        FormatFrame, format .. "Tab", format,
        UDim2.new(0, 63, 0, 29),
        UDim2.new(),
        format == SelectedFormat
            and Color3.fromRGB(135, 85, 255)
            or Color3.fromRGB(45, 40, 62)
    )

    b.TextSize = 10
    FormatButtons[format] = b
end

--==============================================================
-- FILE LIST
--==============================================================

local FileCount = Label(
    Main, "FileCount", "File ditemukan: 0",
    UDim2.new(1, -24, 0, 20),
    UDim2.new(0, 12, 0, 147), 11
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
Corner(FileList, 8)

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

local Status = Label(
    Main, "Status", "Tekan SCAN FILE untuk memulai.",
    UDim2.new(1, -24, 0, 35),
    UDim2.new(0, 12, 0, 354), 10
)
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Center

local ScanButton = Button(
    Main, "ScanButton", "SCAN FILE",
    UDim2.new(0.5, -16, 0, 34),
    UDim2.new(0, 12, 0, 394),
    Color3.fromRGB(105, 65, 190)
)

local ImportButton = Button(
    Main, "ImportButton", "IMPORT",
    UDim2.new(0.5, -16, 0, 34),
    UDim2.new(0.5, 4, 0, 394),
    Color3.fromRGB(45, 130, 95)
)

local CancelButton = Button(
    Main, "CancelButton", "CANCEL",
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
Corner(ReopenButton, 26)
Stroke(ReopenButton, Color3.fromRGB(190, 150, 255), 2)

--==============================================================
-- DRAG
--==============================================================

local function MakeDraggable(object)
    local dragging = false
    local dragStart
    local startPosition

    object.InputBegan:Connect(function(input)
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
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
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

MakeDraggable(Main)
MakeDraggable(ReopenButton)

--==============================================================
-- SCANNER
--==============================================================

local AllFiles = {}
local SelectedFile = nil
local IsScanning = false

local function Supported(path)
    local p = string.lower(path)
    return p:match("%.rbxm$")
        or p:match("%.rbxmx$")
        or p:match("%.rbxl$")
        or p:match("%.rbxlx$")
end

local function Extension(path)
    local p = string.lower(path)
    if p:match("%.rbxmx$") then return "RBXMX" end
    if p:match("%.rbxlx$") then return "RBXLX" end
    if p:match("%.rbxm$") then return "RBXM" end
    if p:match("%.rbxl$") then return "RBXL" end
    return ""
end

local function FileName(path)
    return path:match("[^/\\]+$") or path
end

local function ScanFiles()
    if type(listfilesAPI) ~= "function" then
        return nil, "API listfiles() tidak tersedia di Delta."
    end

    local files = {}
    local seenFiles = {}
    local seenFolders = {}
    local queue = {}

    for _, path in ipairs(CONFIG.FOLDERS) do
        table.insert(queue, path)
    end

    local index = 1
    local foldersScanned = 0
    local foldersReadable = 0

    while index <= #queue and foldersScanned < CONFIG.MAX_FOLDERS do
        local folder = queue[index]
        index += 1

        if not seenFolders[folder] then
            seenFolders[folder] = true
            foldersScanned += 1

            local ok, result = pcall(function()
                return listfilesAPI(folder)
            end)

            if ok and type(result) == "table" then
                foldersReadable += 1

                for _, path in ipairs(result) do
                    if type(path) == "string" then
                        if Supported(path) then
                            if not seenFiles[path] then
                                seenFiles[path] = true
                                table.insert(files, path)
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

    table.sort(files, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return files, nil, foldersReadable
end

--==============================================================
-- RENDER FILES
--==============================================================

local function ClearList()
    for _, child in ipairs(FileList:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function RefreshList()
    ClearList()

    local count = 0
    local query = string.lower(SearchBox.Text)

    for _, path in ipairs(AllFiles) do
        local ext = Extension(path)
        local name = FileName(path)

        local formatOK =
            SelectedFormat == "ALL" or SelectedFormat == ext

        local searchOK =
            query == ""
            or string.find(string.lower(name), query, 1, true) ~= nil

        if formatOK and searchOK then
            count += 1

            local row = Button(
                FileList,
                "File_" .. count,
                "  [" .. ext .. "]  " .. name,
                UDim2.new(1, -2, 0, 34),
                UDim2.new(),
                Color3.fromRGB(45, 40, 62)
            )

            row.TextSize = 11
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextTruncate = Enum.TextTruncate.AtEnd
            row.LayoutOrder = count

            row.MouseButton1Click:Connect(function()
                SelectedFile = path
                Status.Text = "Dipilih: " .. name

                for _, item in ipairs(FileList:GetChildren()) do
                    if item:IsA("TextButton") then
                        item.BackgroundColor3 =
                            Color3.fromRGB(45, 40, 62)
                    end
                end

                row.BackgroundColor3 =
                    Color3.fromRGB(105, 65, 150)
            end)
        end
    end

    FileCount.Text = "File ditemukan: " .. count
end

--==============================================================
-- SCAN ACTION
--==============================================================

local function RefreshFiles()
    if IsScanning then
        return
    end

    IsScanning = true
    SelectedFile = nil
    Status.Text = "Memindai file di folder Delta..."

    task.spawn(function()
        local callOK, files, err, readable = pcall(ScanFiles)

        if not callOK then
            AllFiles = {}
            RefreshList()
            Status.Text = "Kesalahan pemindaian: " .. tostring(files)

        elseif type(files) == "table" then
            AllFiles = files
            RefreshList()

            if #AllFiles > 0 then
                Status.Text = "Pemindaian selesai: " .. #AllFiles .. " file."
            elseif (readable or 0) == 0 then
                Status.Text =
                    "Tidak bisa membaca folder. API/path Delta tidak cocok."
            else
                Status.Text =
                    "Folder terbaca, tetapi tidak ada file model yang cocok."
            end
        else
            AllFiles = {}
            RefreshList()
            Status.Text = err or "Pemindaian gagal."
        end

        IsScanning = false
    end)
end

--==============================================================
-- EVENTS
--==============================================================

ScanButton.MouseButton1Click:Connect(RefreshFiles)

SearchBox:GetPropertyChangedSignal("Text"):Connect(RefreshList)

for name, button in pairs(FormatButtons) do
    button.MouseButton1Click:Connect(function()
        SelectedFormat = name

        for formatName, tab in pairs(FormatButtons) do
            tab.BackgroundColor3 =
                formatName == SelectedFormat
                and Color3.fromRGB(135, 85, 255)
                or Color3.fromRGB(45, 40, 62)
        end

        SelectedFile = nil
        RefreshList()
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
        "Terpilih: " .. FileName(SelectedFile)
        .. ". Proses impor belum tersedia."
end)

--==============================================================
-- START
--==============================================================

print("==========================================")
print("[PUNAKAWAN] Importer GUI berhasil dibuat.")
print("[PUNAKAWAN] listfiles:", type(listfilesAPI))
print("[PUNAKAWAN] isfolder:", type(isfolderAPI))
print("[PUNAKAWAN] isfile:", type(isfileAPI))
print("==========================================")

if type(listfilesAPI) == "function" then
    task.delay(0.5, RefreshFiles)
else
    Status.Text =
        "Delta tidak menyediakan listfiles(). Pemindaian file tidak tersedia."
end
