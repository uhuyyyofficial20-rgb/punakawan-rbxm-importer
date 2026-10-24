--========================================================--
--       PUNAKAWAN COMMUNITY IMPORTER
--       GUI FILE BROWSER FOR DELTA
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

local Player = Players.LocalPlayer
if not Player then
    warn("[PUNAKAWAN] LocalPlayer unavailable.")
    return
end

local PlayerGui = Player:WaitForChild("PlayerGui")

--========================================================--
-- CLEAN OLD GUI
--========================================================--

local OldGUI = PlayerGui:FindFirstChild("PunakawanImporter")
if OldGUI then
    OldGUI:Destroy()
end

--========================================================--
-- GUI HELPERS
--========================================================--

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

--========================================================--
-- SCREEN GUI
--========================================================--

local ScreenGui = Create("ScreenGui", {
    Name = "PunakawanImporter",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999
}, PlayerGui)

--========================================================--
-- MAIN WINDOW
--========================================================--

local Main = Create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0.88, 0, 0, 470),
    BackgroundColor3 = CONFIG.BACKGROUND,
    BorderSizePixel = 0,
    ClipsDescendants = true
}, ScreenGui)

Create("UISizeConstraint", {
    MinSize = Vector2.new(280, 430),
    MaxSize = Vector2.new(500, 520)
}, Main)

Corner(Main, 14)
Stroke(Main, CONFIG.ACCENT, 1.5)

--========================================================--
-- HEADER
--========================================================--

local Header = Create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 65),
    BackgroundColor3 = CONFIG.PANEL,
    BorderSizePixel = 0
}, Main)

Create("TextLabel", {
    Position = UDim2.new(0, 15, 0, 9),
    Size = UDim2.new(1, -115, 0, 23),
    BackgroundTransparency = 1,
    Text = CONFIG.TITLE,
    TextColor3 = CONFIG.TEXT,
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, Header)

Create("TextLabel", {
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
    Font = Enum.Font.GothamBold
}, Header)
Corner(MinimizeButton, 8)

local CloseButton = Create("TextButton", {
    Position = UDim2.new(1, -40, 0, 15),
    Size = UDim2.new(0, 28, 0, 28),
    BackgroundColor3 = Color3.fromRGB(180, 55, 70),
    Text = "×",
    TextColor3 = CONFIG.TEXT,
    TextSize = 20,
    Font = Enum.Font.GothamBold
}, Header)
Corner(CloseButton, 8)

--========================================================--
-- FILE FORMAT TABS
--========================================================--

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

--========================================================--
-- SEARCH BOX
--========================================================--

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

--========================================================--
-- FILE LIST
--========================================================--

local FileList = Create("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 200),
    Size = UDim2.new(1, -24, 0, 140),
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

--========================================================--
-- STATUS
--========================================================--

local Status = Create("TextLabel", {
    Position = UDim2.new(0, 14, 0, 345),
    Size = UDim2.new(1, -28, 0, 24),
    BackgroundTransparency = 1,
    Text = "Status: Ready",
    TextColor3 = CONFIG.MUTED,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd
}, Main)

local function SetStatus(message)
    Status.Text = "Status: " .. message
end

--========================================================--
-- BUTTONS
--========================================================--

local ScanButton = Create("TextButton", {
    Name = "ScanButton",
    Position = UDim2.new(0, 12, 0, 375),
    Size = UDim2.new(1, -24, 0, 32),
    BackgroundColor3 = Color3.fromRGB(50, 50, 70),
    Text = "SCAN FILE  ↻",
    TextColor3 = CONFIG.TEXT,
    TextSize = 12,
    Font = Enum.Font.GothamBold
}, Main)
Corner(ScanButton, 8)

local ImportButton = Create("TextButton", {
    Position = UDim2.new(0, 12, 1, -49),
    Size = UDim2.new(0.58, -10, 0, 36),
    BackgroundColor3 = CONFIG.ACCENT,
    Text = "IMPORT SELECTED",
    TextColor3 = CONFIG.TEXT,
    TextSize = 11,
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

--========================================================--
-- CIRCULAR POPUP BUTTON
--========================================================--

local ReopenButton = Create("TextButton", {
    Name = "Reopen",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.88, 0, 0.72, 0),
    Size = UDim2.new(0, 55, 0, 55),
    BackgroundColor3 = CONFIG.ACCENT,
    Text = "PC",
    TextColor3 = CONFIG.TEXT,
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    Visible = false,
    AutoButtonColor = true
}, ScreenGui)

Corner(ReopenButton, 100)
Stroke(ReopenButton, CONFIG.TEXT, 1)

--========================================================--
-- FILE SCANNER
--========================================================--

local SelectedFile = nil
local FileButtons = {}
local ScanGeneration = 0

local function ClearFileList()
    for _, object in ipairs(FileButtons) do
        object:Destroy()
    end

    table.clear(FileButtons)
    SelectedFile = nil
end

local function GetFiles()
    if type(listfiles) ~= "function" then
        return nil, "Delta API listfiles() unavailable"
    end

    local files = {}
    local visited = {}
    local queue = {CONFIG.FOLDER}
    local head = 1
    local maxFolders = 200
    local scannedFolders = 0

    while head <= #queue and scannedFolders < maxFolders do
        local folder = queue[head]
        head += 1
        scannedFolders += 1

        local ok, result = pcall(function()
            return listfiles(folder)
        end)

        if ok and type(result) == "table" then
            for _, path in ipairs(result) do
                if type(path) == "string" and not visited[path] then
                    visited[path] = true

                    local lower = string.lower(path)

                    if lower:match("%.rbxm$")
                        or lower:match("%.rbxmx$")
                        or lower:match("%.rbxl$")
                        or lower:match("%.rbxlx$") then

                        table.insert(files, path)
                    elseif type(isfolder) == "function" then
                        local folderOK, isDir = pcall(isfolder, path)

                        if folderOK and isDir then
                            table.insert(queue, path)
                        end
                    end
                end
            end
        end
    end

    table.sort(files)
    return files
end

local function RefreshFiles()
    ScanGeneration += 1
    local thisScan = ScanGeneration

    ClearFileList()
    SetStatus("Scanning files...")

    task.spawn(function()
        local files, err = GetFiles()

        if thisScan ~= ScanGeneration or not ScreenGui.Parent then
            return
        end

        if not files then
            SetStatus(err or "Cannot scan files")
            return
        end

        local query = string.lower(SearchBox.Text)
        local extension = "." .. string.lower(CurrentFormat)
        local shown = 0

        for _, path in ipairs(files) do
            local lower = string.lower(path)

            if lower:sub(-#extension) == extension then
                local name = path:gsub("\\", "/"):match("([^/]+)$") or path

                if query == "" or string.find(string.lower(name), query, 1, true) then
                    shown += 1

                    local button = Create("TextButton", {
                        Name = "File_" .. shown,
                        Size = UDim2.new(1, -4, 0, 34),
                        BackgroundColor3 = Color3.fromRGB(42, 42, 57),
                        Text = "  [FILE]  " .. name,
                        TextColor3 = CONFIG.TEXT,
                        TextSize = 12,
                        Font = Enum.Font.Gotham,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        LayoutOrder = shown
                    }, FileList)

                    Corner(button, 6)
                    table.insert(FileButtons, button)

                    local selectedPath = path

                    button.Activated:Connect(function()
                        SelectedFile = selectedPath

                        for _, other in ipairs(FileButtons) do
                            other.BackgroundColor3 = Color3.fromRGB(42, 42, 57)
                        end

                        button.BackgroundColor3 = CONFIG.ACCENT
                        SetStatus("Selected: " .. name)
                    end)
                end
            end
        end

        if shown == 0 then
            SetStatus("No " .. CurrentFormat .. " files found")
        else
            SetStatus(shown .. " " .. CurrentFormat .. " file(s) found")
        end
    end)
end

--========================================================--
-- CREATE FORMAT TABS
--========================================================--

for index, format in ipairs(Formats) do
    local tab = Create("TextButton", {
        Name = "Tab_" .. format.Name,
        BackgroundColor3 = format.Name == CurrentFormat
            and CONFIG.ACCENT or CONFIG.PANEL,
        Text = format.Name,
        TextColor3 = CONFIG.TEXT,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        LayoutOrder = index
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

--========================================================--
-- SEARCH AND SCAN
--========================================================--

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RefreshFiles()
end)

ScanButton.Activated:Connect(function()
    ScanButton.Text = "SCANNING..."

    RefreshFiles()

    task.delay(0.5, function()
        if ScanButton.Parent then
            ScanButton.Text = "SCAN FILE  ↻"
        end
    end)
end)

--========================================================--
-- MINIMIZE / REOPEN / CLOSE
--========================================================--

MinimizeButton.Activated:Connect(function()
    Main.Visible = false
    ReopenButton.Visible = true
end)

ReopenButton.Activated:Connect(function()
    if not ReopenButton:GetAttribute("Dragging") then
        ReopenButton.Visible = false
        Main.Visible = true
    end
end)

CloseButton.Activated:Connect(function()
    ScreenGui:Destroy()
end)

CancelButton.Activated:Connect(function()
    SelectedFile = nil
    SearchBox.Text = ""
    SetStatus("Selection cancelled")
    RefreshFiles()
end)

--========================================================--
-- DRAG MAIN WINDOW
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
-- DRAG CIRCULAR POPUP
--========================================================--

local popupDragging = false
local popupDragStart
local popupStartPosition
local popupMoved = false

ReopenButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        popupDragging = true
        popupMoved = false
        popupDragStart = input.Position
        popupStartPosition = ReopenButton.Position

        ReopenButton:SetAttribute("Dragging", false)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if popupDragging and (
        input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        local delta = input.Position - popupDragStart

        if math.abs(delta.X) > 8 or math.abs(delta.Y) > 8 then
            popupMoved = true
            ReopenButton:SetAttribute("Dragging", true)
        end

        if popupMoved then
            ReopenButton.Position = UDim2.new(
                popupStartPosition.X.Scale,
                popupStartPosition.X.Offset + delta.X,
                popupStartPosition.Y.Scale,
                popupStartPosition.Y.Offset + delta.Y
            )
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then

        popupDragging = false

        if popupMoved then
            task.delay(0.1, function()
                if ReopenButton.Parent then
                    ReopenButton:SetAttribute("Dragging", false)
                end
            end)
        end
    end
end)

--========================================================--
-- IMPORT PLACEHOLDER
--========================================================--

ImportButton.Activated:Connect(function()
    if not SelectedFile then
        SetStatus("Select a file first")
        return
    end

    SetStatus("Selected; compatible import engine required")

    warn("[PUNAKAWAN IMPORTER] Selected file:", SelectedFile)
    warn("[PUNAKAWAN IMPORTER] Reading a file does not import it into Studio.")
end)

--========================================================--
-- START
--========================================================--

RefreshFiles()

print("[PUNAKAWAN COMMUNITY IMPORTER] GUI loaded successfully.")
