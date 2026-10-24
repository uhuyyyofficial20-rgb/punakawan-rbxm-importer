--========================================================--
--       PUNAKAWAN COMMUNITY IMPORTER
--       Created for PUNAKAWAN COMMUNITY
--       GUI File Browser for Delta
--========================================================--

local CONFIG = {
    TITLE = "PUNAKAWAN COMMUNITY",
    SUBTITLE = "RBX FILE IMPORTER",
    FOLDER = "Workspace",
    ACCENT = Color3.fromRGB(145, 75, 255),
    BACKGROUND = Color3.fromRGB(20, 20, 28),
    PANEL = Color3.fromRGB(30, 30, 42),
    TEXT = Color3.fromRGB(245, 245, 255),
    MUTED = Color3.fromRGB(155, 155, 175)
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Remove previous GUI
local OldGUI = PlayerGui:FindFirstChild("PunakawanImporter")
if OldGUI then
    OldGUI:Destroy()
end

--========================================================--
-- GUI CREATION
--========================================================--

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PunakawanImporter"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local function Create(className, properties, parent)
    local object = Instance.new(className)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

local function Corner(object, radius)
    Create("UICorner", {
        CornerRadius = UDim.new(0, radius)
    }, object)
end

local function Stroke(object, color, thickness)
    Create("UIStroke", {
        Color = color,
        Thickness = thickness,
        Transparency = 0.15
    }, object)
end

local Main = Create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0.88, 0, 0, 440),
    BackgroundColor3 = CONFIG.BACKGROUND,
    BorderSizePixel = 0,
    ClipsDescendants = true
}, ScreenGui)

Create("UISizeConstraint", {
    MinSize = Vector2.new(280, 350),
    MaxSize = Vector2.new(500, 520)
}, Main)

Corner(Main, 14)
Stroke(Main, CONFIG.ACCENT, 1.5)

-- Header
local Header = Create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 65),
    BackgroundColor3 = CONFIG.PANEL,
    BorderSizePixel = 0
}, Main)

local Title = Create("TextLabel", {
    Position = UDim2.new(0, 15, 0, 9),
    Size = UDim2.new(1, -115, 0, 23),
    BackgroundTransparency = 1,
    Text = CONFIG.TITLE,
    TextColor3 = CONFIG.TEXT,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

local Subtitle = Create("TextLabel", {
    Position = UDim2.new(0, 15, 0, 34),
    Size = UDim2.new(1, -115, 0, 17),
    BackgroundTransparency = 1,
    Text = CONFIG.SUBTITLE,
    TextColor3 = CONFIG.MUTED,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

local MinimizeButton = Create("TextButton", {
    Position = UDim2.new(1, -76, 0, 15),
    Size = UDim2.new(0, 28, 0, 28),
    BackgroundColor3 = CONFIG.BACKGROUND,
    Text = "—",
    TextColor3 = CONFIG.TEXT,
    TextSize = 17,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true
}, Header)
Corner(MinimizeButton, 8)

local CloseButton = Create("TextButton", {
    Position = UDim2.new(1, -40, 0, 15),
    Size = UDim2.new(0, 28, 0, 28),
    BackgroundColor3 = Color3.fromRGB(180, 55, 70),
    Text = "×",
    TextColor3 = CONFIG.TEXT,
    TextSize = 20,
    Font = Enum.Font.GothamBold,
    AutoButtonColor = true
}, Header)
Corner(CloseButton, 8)

-- File format tabs
local TabHolder = Create("Frame", {
    Position = UDim2.new(0, 12, 0, 77),
    Size = UDim2.new(1, -24, 0, 70),
    BackgroundTransparency = 1
}, Main)

Create("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 30),
    CellPadding = UDim2.new(0, 8, 0, 7),
    FillDirectionMaxCells = 2,
    SortOrder = Enum.SortOrder.LayoutOrder
}, TabHolder)

local Formats = {
    {Name = "RBXM", Extension = ".rbxm"},
    {Name = "RBXMX", Extension = ".rbxmx"},
    {Name = "RBXL", Extension = ".rbxl"},
    {Name = "RBXLX", Extension = ".rbxlx"}
}

local CurrentFormat = "RBXM"
local Tabs = {}

-- Search
local SearchBox = Create("TextBox", {
    Position = UDim2.new(0, 12, 0, 154),
    Size = UDim2.new(1, -24, 0, 36),
    BackgroundColor3 = CONFIG.PANEL,
    PlaceholderText = "Search files...",
    PlaceholderColor3 = CONFIG.MUTED,
    Text = "",
    TextColor3 = CONFIG.TEXT,
    TextSize = 13,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false
}, Main)
Corner(SearchBox, 8)

-- File list
local FileList = Create("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 200),
    Size = UDim2.new(1, -24, 0, 145),
    BackgroundColor3 = CONFIG.PANEL,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = CONFIG.ACCENT,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y
}, Main)
Corner(FileList, 8)

Create("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder
}, FileList)

Create("UIPadding", {
    PaddingTop = UDim.new(0, 7),
    PaddingBottom = UDim.new(0, 7),
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7)
}, FileList)

local Status = Create("TextLabel", {
    Position = UDim2.new(0, 14, 0, 352),
    Size = UDim2.new(1, -28, 0, 24),
    BackgroundTransparency = 1,
    Text = "Status: Ready",
    TextColor3 = CONFIG.MUTED,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd
}, Main)

local ImportButton = Create("TextButton", {
    Position = UDim2.new(0, 12, 1, -49),
    Size = UDim2.new(0.58, -10, 0, 36),
    BackgroundColor3 = CONFIG.ACCENT,
    Text = "IMPORT SELECTED",
    TextColor3 = CONFIG.TEXT,
    TextSize = 12,
    Font = Enum.Font.GothamBold
}, Main)
Corner(ImportButton, 8)

local CancelButton = Create("TextButton", {
    Position = UDim2.new(0.58, 7, 1, -49),
    Size = UDim2.new(0.42, -19, 0, 36),
    BackgroundColor3 = Color3.fromRGB(65, 65, 82),
    Text = "CANCEL",
    TextColor3 = CONFIG.TEXT,
    TextSize = 12,
    Font = Enum.Font.GothamBold
}, Main)
Corner(CancelButton, 8)

-- Minimized popup button
local ReopenButton = Create("TextButton", {
    Name = "Reopen",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.8, 0),
    Size = UDim2.new(0, 165, 0, 42),
    BackgroundColor3 = CONFIG.ACCENT,
    Text = "PUNAKAWAN IMPORTER",
    TextColor3 = CONFIG.TEXT,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    Visible = false
}, ScreenGui)
Corner(ReopenButton, 12)

--========================================================--
-- DRAGGABLE WINDOW
--========================================================--

local dragging = false
local dragStart
local startPosition

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart

        Main.Position = UDim2.new(
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

--========================================================--
-- FILE BROWSER
--========================================================--

local SelectedFile = nil
local FileButtons = {}

local function ClearFileList()
    for _, object in ipairs(FileButtons) do
        object:Destroy()
    end

    table.clear(FileButtons)
    SelectedFile = nil
end

local function SetStatus(message)
    Status.Text = "Status: " .. message
end

local function GetFiles()
    local files = {}

    -- Delta/executor-specific file API.
    if type(listfiles) ~= "function" then
        return nil, "Executor does not provide listfiles()"
    end

    local ok, result = pcall(function()
        return listfiles(CONFIG.FOLDER)
    end)

    if not ok or type(result) ~= "table" then
        return nil, "Cannot read Delta/Workspace"
    end

    for _, path in ipairs(result) do
        if type(path) == "string" then
            local lower = string.lower(path)
            local extension = "." .. string.lower(CurrentFormat)

            if lower:sub(-#extension) == extension then
                table.insert(files, path)
            end
        end
    end

    table.sort(files)
    return files
end

local function RefreshFiles()
    ClearFileList()

    local files, err = GetFiles()

    if not files then
        SetStatus(err)
        return
    end

    local query = string.lower(SearchBox.Text)
    local shown = 0

    for _, path in ipairs(files) do
        local name = path:gsub("\\", "/"):match("([^/]+)$") or path

        if query == "" or string.find(string.lower(name), query, 1, true) then
            shown = shown + 1

            local button = Create("TextButton", {
                Name = "File_" .. shown,
                Size = UDim2.new(1, -4, 0, 34),
                BackgroundColor3 = Color3.fromRGB(42, 42, 57),
                Text = "  📦  " .. name,
                TextColor3 = CONFIG.TEXT,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                LayoutOrder = shown
            }, FileList)

            Corner(button, 6)
            table.insert(FileButtons, button)

            button.Activated:Connect(function()
                SelectedFile = path

                for _, other in ipairs(FileButtons) do
                    other.BackgroundColor3 = Color3.fromRGB(42, 42, 57)
                end

                button.BackgroundColor3 = CONFIG.ACCENT
                SetStatus("Selected: " .. name)
            end)
        end
    end

    if shown == 0 then
        SetStatus("No " .. CurrentFormat .. " files found")
    else
        SetStatus(tostring(shown) .. " file(s) found")
    end
end

for _, format in ipairs(Formats) do
    local tab = Create("TextButton", {
        Name = "Tab_" .. format.Name,
        BackgroundColor3 = format.Name == CurrentFormat
            and CONFIG.ACCENT or CONFIG.PANEL,
        Text = format.Name,
        TextColor3 = CONFIG.TEXT,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        LayoutOrder = table.find(Formats, format)
    }, TabHolder)

    Corner(tab, 7)
    Tabs[format.Name] = tab

    tab.Activated:Connect(function()
        CurrentFormat = format.Name

        for name, other in pairs(Tabs) do
            other.BackgroundColor3 =
                name == CurrentFormat and CONFIG.ACCENT or CONFIG.PANEL
        end

        RefreshFiles()
    end)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(RefreshFiles)

--========================================================--
-- BUTTONS
--========================================================--

MinimizeButton.Activated:Connect(function()
    Main.Visible = false
    ReopenButton.Visible = true
end)

ReopenButton.Activated:Connect(function()
    ReopenButton.Visible = false
    Main.Visible = true
end)

CloseButton.Activated:Connect(function()
    ScreenGui:Destroy()
end)

CancelButton.Activated:Connect(function()
    SelectedFile = nil
    SearchBox.Text = ""
    RefreshFiles()
    SetStatus("Selection cancelled")
end)

ImportButton.Activated:Connect(function()
    if not SelectedFile then
        SetStatus("Select a file first")
        return
    end

    -- Reading a file does NOT import a Roblox model.
    -- Actual import requires a compatible importer/API.
    SetStatus("File selected; compatible import engine required")
    warn("[PUNAKAWAN IMPORTER] Selected:", SelectedFile)
end)

RefreshFiles()

print("[PUNAKAWAN COMMUNITY IMPORTER] GUI loaded")
