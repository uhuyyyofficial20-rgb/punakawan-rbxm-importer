--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER v4
-- Model (RBXM/RBXMX/RBXL/RBXLX) + Lagu + Toolbox
-- Delta Executor -> Roblox (Studio Lite)
--==============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--==============================================================
-- CONFIGURATION
--==============================================================

-- Posisi spawn Studio Lite. Model akan diletakkan di X/Z ini,
-- dengan sisi bawah model menempel di permukaan baseplate.
local SPAWN_POSITION = Vector3.new(0, 0.5, 0)

-- true = jika ada SpawnLocation di Workspace, pakai posisinya
-- (bukan SPAWN_POSITION di atas)
local USE_SPAWNLOCATION = false

-- false = tiap import mendarat di titik yang sama (baseplate),
-- true  = import berikutnya ditumpuk di atas import sebelumnya
local STACK_ON_PREVIOUS = false

-- Folder yang dipindai (relatif terhadap folder workspace executor)
local ROOT_PATHS = { "", ".", "workspace", "Workspace" }
local MAX_DEPTH = 20

-- Ukuran GUI (dalam skala layar, dibatasi min/maks supaya tidak menutupi layar)
local GUI_SCALE = Vector2.new(0.62, 0.9)
local GUI_MIN = Vector2.new(370, 340)
local GUI_MAX = Vector2.new(480, 560)

-- Kecepatan gradien RGB (putaran warna per detik)
local RGB_SPEED = 0.2

-- Kategori Toolbox untuk Model (Creator Store)
local TOOLBOX_CATEGORY = 10

-- GAMBAR GUI SENDIRI -------------------------------------------
-- Taruh file png/jpg di folder Workspace Delta lalu tulis namanya,
-- atau isi Asset ID ("rbxassetid://123"). Kosong/tidak ada = transparan.
local LOGO_FILE = "punakawan_logo.png"
local LOGO_ASSET_ID = ""
local BG_FILE = "punakawan_bg.png"
local BG_ASSET_ID = ""

local MODEL_EXT = { rbxm = true, rbxmx = true, rbxl = true, rbxlx = true }
local PLACE_EXT = { rbxl = true, rbxlx = true }
local AUDIO_EXT = { mp3 = true, ogg = true, wav = true, flac = true }

--==============================================================
-- EXECUTOR API
--==============================================================

local function getAPI(name)
    local ok, value = pcall(function()
        return getgenv()[name]
    end)
    if ok and typeof(value) == "function" then
        return value
    end

    ok, value = pcall(function()
        return _G[name]
    end)
    if ok and typeof(value) == "function" then
        return value
    end

    ok, value = pcall(function()
        return getfenv()[name]
    end)
    if ok and typeof(value) == "function" then
        return value
    end

    return nil
end

local listfilesAPI = getAPI("listfiles")
local isfileAPI = getAPI("isfile")
local isfolderAPI = getAPI("isfolder")
local getcustomassetAPI = getAPI("getcustomasset") or getAPI("getsynasset")
local gethuiAPI = getAPI("gethui")

local requestAPI = getAPI("request") or getAPI("http_request")
if not requestAPI then
    local ok, fn = pcall(function()
        return syn.request
    end)
    if ok and typeof(fn) == "function" then
        requestAPI = fn
    end
end

--==============================================================
-- UTILITIES
--==============================================================

local function normalizePath(path)
    local p = tostring(path)
    p = p:gsub("\\", "/")
    p = p:gsub("/+", "/")
    p = p:gsub("^%./", "")
    p = p:gsub("/$", "")
    return p
end

local function getExtension(path)
    return string.lower(tostring(path):match("%.([^%.\\/]+)$") or "")
end

local function baseNameOf(path)
    return tostring(path):match("([^/]+)%.[^%.]+$") or tostring(path):match("([^/]+)$") or "Imported"
end

local function trim(s)
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function pathExists(path)
    if isfileAPI then
        local ok, result = pcall(isfileAPI, path)
        if ok and result then
            return true
        end
    end
    return false
end

local function folderExists(path)
    if isfolderAPI then
        local ok, result = pcall(isfolderAPI, path)
        if ok and result then
            return true
        end
    end
    return false
end

local function resolveImage(file, assetId)
    if assetId and assetId ~= "" then
        return assetId
    end

    if file and file ~= "" and getcustomassetAPI and pathExists(file) then
        local ok, url = pcall(getcustomassetAPI, file)
        if ok and type(url) == "string" and url ~= "" then
            return url
        end
    end

    return nil
end

local logoImage = resolveImage(LOGO_FILE, LOGO_ASSET_ID)
local bgImage = resolveImage(BG_FILE, BG_ASSET_ID)

--==============================================================
-- THEME
--==============================================================

local THEME = {
    bg = Color3.fromRGB(13, 13, 20),
    header = Color3.fromRGB(19, 19, 29),
    panel = Color3.fromRGB(23, 23, 35),
    item = Color3.fromRGB(33, 33, 49),
    itemSelected = Color3.fromRGB(74, 60, 150),
    button = Color3.fromRGB(37, 37, 55),
    text = Color3.fromRGB(238, 238, 248),
    muted = Color3.fromRGB(150, 150, 176),
}

local panelTransparency = bgImage and 0.6 or 0.7

--==============================================================
-- GRADIEN RGB BERGERAK
--==============================================================

local rgbGradients = {}

local function buildRainbow(shift)
    local keypoints = {}
    for i = 0, 6 do
        keypoints[#keypoints + 1] = ColorSequenceKeypoint.new(
            i / 6,
            Color3.fromHSV((i / 6 + shift) % 1, 0.85, 1)
        )
    end
    return ColorSequence.new(keypoints)
end

local function addRGB(parent)
    local gradient = Instance.new("UIGradient")
    gradient.Color = buildRainbow(0)
    gradient.Parent = parent
    table.insert(rgbGradients, gradient)
    return gradient
end

local function rgbStroke(inst, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = thickness or 1.5
    stroke.Transparency = transparency or 0
    stroke.Parent = inst
    addRGB(stroke)
    return stroke
end

--==============================================================
-- GUI DASAR
--==============================================================

local function applyTextShadow(inst)
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inst.TextStrokeColor3 = Color3.new(0, 0, 0)
        inst.TextStrokeTransparency = 0.45
    end
end

local guiParent = PlayerGui
if gethuiAPI then
    local ok, hui = pcall(gethuiAPI)
    if ok and typeof(hui) == "Instance" then
        guiParent = hui
    end
end

for _, container in ipairs({ PlayerGui, guiParent }) do
    local old = container:FindFirstChild("PunawakanCommunityImporter")
    if old then
        old:Destroy()
    end
end

local oldMusic = SoundService:FindFirstChild("PunawakanMusic")
if oldMusic then
    oldMusic:Destroy()
end

local connections = {}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PunawakanCommunityImporter"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = guiParent

local function corner(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = inst
    return c
end

-- Tombol buka ---------------------------------------------------
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.fromOffset(54, 54)
OpenButton.Position = UDim2.new(0, 15, 0.5, -27)
OpenButton.AutoButtonColor = false
OpenButton.BackgroundTransparency = 1
OpenButton.Parent = ScreenGui
corner(OpenButton, 12)
rgbStroke(OpenButton, 2, 0.1)

if logoImage then
    OpenButton.Text = ""
    local logo = Instance.new("ImageLabel")
    logo.Name = "Logo"
    logo.Size = UDim2.fromScale(1, 1)
    logo.BackgroundTransparency = 1
    logo.Image = logoImage
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = OpenButton
    corner(logo, 12)
else
    OpenButton.Text = "P"
    OpenButton.TextColor3 = Color3.new(1, 1, 1)
    OpenButton.TextSize = 26
    OpenButton.Font = Enum.Font.GothamBold
end

-- Jendela utama -------------------------------------------------
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.fromScale(GUI_SCALE.X, GUI_SCALE.Y)
Main.BackgroundColor3 = THEME.bg
Main.BackgroundTransparency = bgImage and 1 or 0.6
Main.BorderSizePixel = 0
Main.Visible = false
Main.Parent = ScreenGui
corner(Main, 14)
rgbStroke(Main, 2.5, 0)

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MinSize = GUI_MIN
sizeLimit.MaxSize = GUI_MAX
sizeLimit.Parent = Main

if bgImage then
    local bg = Instance.new("ImageLabel")
    bg.Name = "Background"
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundTransparency = 1
    bg.Image = bgImage
    bg.ScaleType = Enum.ScaleType.Crop
    bg.ZIndex = 0
    bg.Parent = Main
    corner(bg, 14)
end

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = THEME.header
Header.BackgroundTransparency = 0.65
Header.BorderSizePixel = 0
Header.Parent = Main
corner(Header, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "PUNAKAWAN COMMUNITY"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header
addRGB(Title)

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(34, 34)
Minimize.Position = UDim2.new(1, -76, 0, 5)
Minimize.BackgroundTransparency = 1
Minimize.Text = "-"
Minimize.TextColor3 = THEME.text
Minimize.TextSize = 24
Minimize.Font = Enum.Font.GothamBold
Minimize.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(34, 34)
Close.Position = UDim2.new(1, -40, 0, 5)
Close.BackgroundTransparency = 1
Close.Text = "X"
Close.TextColor3 = THEME.text
Close.TextSize = 17
Close.Font = Enum.Font.GothamBold
Close.Parent = Header

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, -28, 0, 2)
HeaderLine.Position = UDim2.fromOffset(14, 44)
HeaderLine.BackgroundColor3 = Color3.new(1, 1, 1)
HeaderLine.BorderSizePixel = 0
HeaderLine.Parent = Main
addRGB(HeaderLine)

-- Tab -----------------------------------------------------------
local TabBar = Instance.new("Frame")
TabBar.Position = UDim2.fromOffset(10, 52)
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.BackgroundTransparency = 1
TabBar.Parent = Main

local tabButtons, tabLines, pages = {}, {}, {}

local TAB_DEFS = {
    { "model", "MODEL" },
    { "music", "LAGU" },
    { "toolbox", "TOOLBOX" },
}

local function switchTab(name)
    for key, page in pairs(pages) do
        page.Visible = (key == name)
    end
    for key, button in pairs(tabButtons) do
        local active = (key == name)
        button.TextColor3 = active and THEME.text or THEME.muted
        tabLines[key].Visible = active
    end
end

for i, def in ipairs(TAB_DEFS) do
    local key, label = def[1], def[2]

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1 / #TAB_DEFS, -4, 1, 0)
    button.Position = UDim2.new((i - 1) / #TAB_DEFS, 2, 0, 0)
    button.BackgroundTransparency = 1
    button.Text = label
    button.TextSize = 13
    button.Font = Enum.Font.GothamBold
    button.TextColor3 = THEME.muted
    button.Parent = TabBar

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = Color3.new(1, 1, 1)
    line.BorderSizePixel = 0
    line.Visible = false
    line.Parent = button
    addRGB(line)

    tabButtons[key] = button
    tabLines[key] = line

    button.Activated:Connect(function()
        switchTab(key)
    end)
end

-- Wadah halaman + status ---------------------------------------
local PagesHolder = Instance.new("Frame")
PagesHolder.Position = UDim2.fromOffset(10, 90)
PagesHolder.Size = UDim2.new(1, -20, 1, -128)
PagesHolder.BackgroundTransparency = 1
PagesHolder.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 30)
Status.Position = UDim2.new(0, 10, 1, -34)
Status.BackgroundTransparency = 1
Status.Text = "Siap."
Status.TextColor3 = THEME.muted
Status.TextSize = 11
Status.Font = Enum.Font.Gotham
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Center
Status.Parent = Main

local function setStatus(text)
    Status.Text = tostring(text)
end

local function newPage(key)
    local frame = Instance.new("Frame")
    frame.Name = key
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.fromScale(1, 1)
    frame.Visible = false
    frame.Parent = PagesHolder
    pages[key] = frame
    return frame
end

-- Pembuat komponen ---------------------------------------------
local function makeButton(parent, text, position, size, primary)
    local button = Instance.new("TextButton")
    button.Position = position
    button.Size = size
    button.AutoButtonColor = true
    button.BackgroundColor3 = THEME.button
    button.BackgroundTransparency = math.max(panelTransparency - 0.1, 0)
    button.Text = text
    button.TextColor3 = THEME.text
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.Parent = parent
    corner(button, 8)

    rgbStroke(button, 1.5, primary and 0.1 or 0.4)

    return button
end

local function makeBox(parent, placeholder, position, size)
    local box = Instance.new("TextBox")
    box.Position = position
    box.Size = size
    box.BackgroundColor3 = THEME.panel
    box.BackgroundTransparency = panelTransparency
    box.TextColor3 = THEME.text
    box.PlaceholderColor3 = THEME.muted
    box.PlaceholderText = placeholder
    box.Text = ""
    box.ClearTextOnFocus = false
    box.TextSize = 13
    box.Font = Enum.Font.Gotham
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Parent = parent
    corner(box, 8)
    rgbStroke(box, 1, 0.5)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = box

    return box
end

local function newList(parent, position, size, onSelect)
    local frame = Instance.new("ScrollingFrame")
    frame.Position = position
    frame.Size = size
    frame.BackgroundColor3 = THEME.panel
    frame.BackgroundTransparency = panelTransparency
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.CanvasSize = UDim2.new()
    frame.Parent = parent
    corner(frame, 8)
    rgbStroke(frame, 1, 0.5)

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 6)
    padding.Parent = frame

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
    end)

    local ctl = { frame = frame, buttons = {}, selectedButton = nil, selected = nil }

    function ctl.clear()
        for _, b in ipairs(ctl.buttons) do
            b:Destroy()
        end
        ctl.buttons = {}
        ctl.selectedButton = nil
        ctl.selected = nil
        frame.CanvasPosition = Vector2.zero
    end

    function ctl.add(entry)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -4, 0, 42)
        button.LayoutOrder = #ctl.buttons + 1
        button.AutoButtonColor = false
        button.BackgroundColor3 = THEME.item
        button.BackgroundTransparency = 0.45
        button.TextColor3 = THEME.text
        button.TextSize = 11
        button.Font = Enum.Font.Gotham
        button.TextWrapped = true
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.Text = "  " .. entry.text
        applyTextShadow(button)
        button.Parent = frame
        corner(button, 7)

        table.insert(ctl.buttons, button)

        local function choose()
            if ctl.selectedButton then
                ctl.selectedButton.BackgroundColor3 = THEME.item
            end
            ctl.selectedButton = button
            ctl.selected = entry.value
            button.BackgroundColor3 = THEME.itemSelected
            onSelect(entry)
        end

        button.Activated:Connect(choose)
        return choose
    end

    function ctl.set(entries)
        ctl.clear()
        for _, entry in ipairs(entries) do
            ctl.add(entry)
        end
    end

    return ctl
end

--==============================================================
-- ANIMASI RGB + DRAG
--==============================================================

table.insert(connections, RunService.RenderStepped:Connect(function()
    local sequence = buildRainbow((os.clock() * RGB_SPEED) % 1)
    for i = #rgbGradients, 1, -1 do
        local gradient = rgbGradients[i]
        if gradient.Parent then
            gradient.Color = sequence
        else
            table.remove(rgbGradients, i)
        end
    end
end))

do
    local dragging, dragStart, startPos

    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

--==============================================================
-- PENEMPATAN DI POSISI SPAWN (di atas baseplate)
--==============================================================

local importedModels = {}

local function collectSpawns()
    local spawns = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then
            table.insert(spawns, d)
        end
    end
    return spawns
end

local function placeAtSpawn(model)
    local spawns = collectSpawns()

    local spawnPoint = SPAWN_POSITION
    if USE_SPAWNLOCATION and #spawns > 0 then
        spawnPoint = spawns[1].Position
    end

    local boxCF, boxSize = model:GetBoundingBox()

    -- 1) Permukaan baseplate (jika spawn berada di atasnya)
    local groundY
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate and baseplate:IsA("BasePart") then
        local rel = baseplate.CFrame:PointToObjectSpace(spawnPoint)
        if math.abs(rel.X) <= baseplate.Size.X / 2 and math.abs(rel.Z) <= baseplate.Size.Z / 2 then
            groundY = baseplate.Position.Y + baseplate.Size.Y / 2
        end
    end

    -- 2) Raycast ke bawah (abaikan karakter, spawn pad, dan import lama)
    if not groundY then
        local exclude = {}
        if Player.Character then
            table.insert(exclude, Player.Character)
        end
        for _, s in ipairs(spawns) do
            table.insert(exclude, s)
        end
        if not STACK_ON_PREVIOUS then
            for i = #importedModels, 1, -1 do
                if importedModels[i].Parent then
                    table.insert(exclude, importedModels[i])
                else
                    table.remove(importedModels, i)
                end
            end
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = exclude

        local result = workspace:Raycast(
            Vector3.new(spawnPoint.X, spawnPoint.Y + 500, spawnPoint.Z),
            Vector3.new(0, -1500, 0),
            params
        )

        if result then
            groundY = result.Position.Y
        end
    end

    -- 3) Cadangan: tepat di bawah titik spawn
    if not groundY then
        groundY = spawnPoint.Y - 0.5
    end

    local halfHeight = 0.5 * (
        math.abs(boxCF.RightVector.Y) * boxSize.X
        + math.abs(boxCF.UpVector.Y) * boxSize.Y
        + math.abs(boxCF.LookVector.Y) * boxSize.Z
    )

    local delta = Vector3.new(
        spawnPoint.X - boxCF.Position.X,
        (groundY + halfHeight) - boxCF.Position.Y,
        spawnPoint.Z - boxCF.Position.Z
    )

    model:PivotTo(model:GetPivot() + delta)
end

--==============================================================
-- IMPOR OBJEK (dipakai file lokal & Toolbox)
--==============================================================

local SERVICE_NAMES = {
    Lighting = true, ServerScriptService = true, ServerStorage = true,
    ReplicatedStorage = true, ReplicatedFirst = true, StarterGui = true,
    StarterPack = true, StarterPlayer = true, SoundService = true,
    Teams = true, Chat = true, TextChatService = true, MaterialService = true,
}

-- Isi sebuah service dari file dipindahkan ke service yang sama di game ini
local function mergeIntoLocalService(serviceObj, report)
    local okService, realService = pcall(function()
        return game:GetService(serviceObj.ClassName)
    end)

    local children = serviceObj:GetChildren()

    if not okService or not realService then
        report.failed += #children
        return
    end

    for _, child in ipairs(children) do
        -- ScreenGui dari StarterGui juga ditampilkan langsung di PlayerGui
        if serviceObj.ClassName == "StarterGui" and child:IsA("LayerCollector") then
            pcall(function()
                child:Clone().Parent = PlayerGui
            end)
        end

        local ok = pcall(function()
            child.Parent = realService
        end)

        if ok and child.Parent == realService then
            report.services += 1
        else
            report.failed += 1
        end
    end
end

-- Mengumpulkan SEMUA objek (tidak ada yang dibuang)
local function collectImportables(objects, report)
    local list = {}

    for _, obj in ipairs(objects) do
        if typeof(obj) == "Instance" then
            if obj.ClassName == "DataModel" then
                for _, service in ipairs(obj:GetChildren()) do
                    if service.ClassName == "Workspace" then
                        for _, child in ipairs(service:GetChildren()) do
                            table.insert(list, child)
                        end
                    else
                        mergeIntoLocalService(service, report)
                    end
                end
            elseif obj.ClassName == "Workspace" then
                for _, child in ipairs(obj:GetChildren()) do
                    table.insert(list, child)
                end
            elseif SERVICE_NAMES[obj.ClassName] then
                mergeIntoLocalService(obj, report)
            else
                table.insert(list, obj)
            end
        end
    end

    return list
end

local function wrapObjects(items, name, report)
    local container = Instance.new("Model")
    container.Name = name

    for _, item in ipairs(items) do
        if item:IsA("LayerCollector") then
            -- ScreenGui dll. harus di PlayerGui agar tampil
            local ok = pcall(function()
                item.Parent = PlayerGui
            end)
            if ok and item.Parent == PlayerGui then
                report.gui += 1
            else
                report.failed += 1
            end
        else
            local ok = pcall(function()
                item.Parent = container
            end)
            if not ok or item.Parent ~= container then
                report.failed += 1
            end
        end
    end

    return container
end

local function importObjects(objects, isPlace, baseName)
    local report = { services = 0, failed = 0, gui = 0 }
    local items = collectImportables(objects, report)

    local target

    if #items == 1 and items[1]:IsA("Model") and not isPlace then
        target = items[1]
    elseif #items > 0 then
        target = wrapObjects(items, "Import_" .. baseName, report)
    end

    local placed = 0
    local placeNote = ""

    if target and (#target:GetChildren() > 0 or (target:IsA("Model") and #items == 1)) then
        local placedOK, placeErr = pcall(placeAtSpawn, target)
        target.Parent = workspace
        table.insert(importedModels, target)
        placed = #items
        if not placedOK then
            placeNote = " | gagal diposisikan: " .. tostring(placeErr)
        end
    elseif target then
        target:Destroy()
    end

    if placed == 0 and report.services == 0 and report.gui == 0 then
        return false, "Tidak ada objek yang bisa dimasukkan dari file ini."
    end

    local parts = {}
    if placed > 0 then
        table.insert(parts, placed .. " objek di posisi spawn")
    end
    if report.services > 0 then
        table.insert(parts, report.services .. " objek ke service (Lighting/ReplicatedStorage/dll.)")
    end
    if report.gui > 0 then
        table.insert(parts, report.gui .. " GUI ke PlayerGui")
    end

    local message = "BERHASIL: " .. table.concat(parts, ", ") .. ". Script ikut masuk apa adanya."

    if report.failed > 0 then
        message = message .. " | " .. report.failed .. " objek ditolak Roblox (mis. Terrain)."
    end

    return true, message .. placeNote
end

--==============================================================
-- PEMINDAI FILE (model + lagu)
--==============================================================

local modelFiles, audioFiles = {}, {}
local scanning = false

local function scanDirectory(folderPath, depth, visited, counter)
    if depth > MAX_DEPTH or not listfilesAPI then
        return
    end

    folderPath = normalizePath(folderPath)

    if visited[folderPath] then
        return
    end
    visited[folderPath] = true

    local arg = folderPath ~= "" and folderPath or "."

    local ok, entries = pcall(listfilesAPI, arg)
    if not ok or type(entries) ~= "table" then
        if folderPath == "" then
            ok, entries = pcall(listfilesAPI, "")
        end
        if not ok or type(entries) ~= "table" then
            return
        end
    end

    for _, entry in ipairs(entries) do
        local path = normalizePath(entry)
        local ext = getExtension(path)

        if MODEL_EXT[ext] then
            modelFiles[path] = true
        elseif AUDIO_EXT[ext] then
            audioFiles[path] = true
        elseif folderExists(path) then
            scanDirectory(path, depth + 1, visited, counter)
        end

        counter.n += 1
        if counter.n % 25 == 0 then
            task.wait()
        end
    end
end

--==============================================================
-- HALAMAN 1: MODEL
--==============================================================

local ModelPage = newPage("model")

local ModelSearch = makeBox(ModelPage, "Cari file RBXM / RBXL...", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32))
local ModelScan = makeButton(ModelPage, "SCAN FILE", UDim2.fromOffset(0, 38), UDim2.new(0.5, -3, 0, 32), true)
local ModelFilter = makeButton(ModelPage, "FILTER: ALL", UDim2.new(0.5, 3, 0, 38), UDim2.new(0.5, -3, 0, 32))

local modelList = newList(
    ModelPage,
    UDim2.fromOffset(0, 76),
    UDim2.new(1, 0, 1, -122),
    function(entry)
        setStatus("Dipilih: " .. entry.value)
    end
)

local ModelImport = makeButton(ModelPage, "IMPORT FILE TERPILIH", UDim2.new(0, 0, 1, -38), UDim2.new(1, 0, 0, 38), true)

local MODEL_FILTERS = { "ALL", "RBXM", "RBXMX", "RBXL", "RBXLX" }
local modelFilterIndex = 1

local function renderModels()
    local query = string.lower(ModelSearch.Text)
    local mode = MODEL_FILTERS[modelFilterIndex]
    local paths = {}

    for path in pairs(modelFiles) do
        local ext = string.upper(getExtension(path))
        if (mode == "ALL" or ext == mode) and string.find(string.lower(path), query, 1, true) then
            table.insert(paths, path)
        end
    end

    table.sort(paths)

    local entries = {}
    for _, path in ipairs(paths) do
        table.insert(entries, { text = path, value = path })
    end

    modelList.set(entries)
    return #entries
end

--==============================================================
-- HALAMAN 2: LAGU
--==============================================================

local MusicPage = newPage("music")

local MusicSearch = makeBox(MusicPage, "Cari lagu (mp3 / ogg)...", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32))
local MusicScan = makeButton(MusicPage, "SCAN LAGU", UDim2.fromOffset(0, 38), UDim2.new(0.5, -3, 0, 32), true)
local LoopButton = makeButton(MusicPage, "LOOP: OFF", UDim2.new(0.5, 3, 0, 38), UDim2.new(0.5, -3, 0, 32))

local songList = newList(
    MusicPage,
    UDim2.fromOffset(0, 76),
    UDim2.new(1, 0, 1, -156),
    function(entry)
        setStatus("Lagu dipilih: " .. entry.value)
    end
)

local PlayButton = makeButton(MusicPage, "PLAY", UDim2.new(0, 0, 1, -74), UDim2.new(0.5, -3, 0, 34), true)
local StopButton = makeButton(MusicPage, "STOP", UDim2.new(0.5, 3, 1, -74), UDim2.new(0.5, -3, 0, 34))

local VolDown = makeButton(MusicPage, "VOL -", UDim2.new(0, 0, 1, -34), UDim2.new(0.3, -4, 0, 34))
local VolLabel = Instance.new("TextLabel")
VolLabel.Position = UDim2.new(0.3, 0, 1, -34)
VolLabel.Size = UDim2.new(0.4, 0, 0, 34)
VolLabel.BackgroundTransparency = 1
VolLabel.TextColor3 = THEME.text
VolLabel.TextSize = 12
VolLabel.Font = Enum.Font.GothamBold
VolLabel.Text = "VOLUME 50%"
VolLabel.Parent = MusicPage
local VolUp = makeButton(MusicPage, "VOL +", UDim2.new(0.7, 4, 1, -34), UDim2.new(0.3, -4, 0, 34))

local Music = Instance.new("Sound")
Music.Name = "PunawakanMusic"
Music.Volume = 0.5
Music.Looped = false
Music.Parent = SoundService

local currentSongPath = nil
local musicBusy = false

local function renderSongs()
    local query = string.lower(MusicSearch.Text)
    local paths = {}

    for path in pairs(audioFiles) do
        if string.find(string.lower(path), query, 1, true) then
            table.insert(paths, path)
        end
    end

    table.sort(paths)

    local entries = {}
    for _, path in ipairs(paths) do
        table.insert(entries, { text = path, value = path })
    end

    songList.set(entries)
    return #entries
end

local function refreshVolume()
    VolLabel.Text = "VOLUME " .. math.floor(Music.Volume * 100 + 0.5) .. "%"
end

local function loadAndPlay(path)
    if not getcustomassetAPI then
        setStatus("ERROR: getcustomasset tidak tersedia di executor ini.")
        return
    end

    if not pathExists(path) then
        setStatus("ERROR: file lagu tidak ditemukan: " .. path)
        return
    end

    musicBusy = true
    setStatus("Memuat lagu...")

    local okAsset, assetUrl = pcall(getcustomassetAPI, path)
    if not okAsset or type(assetUrl) ~= "string" or assetUrl == "" then
        setStatus("GAGAL memuat lagu: " .. tostring(assetUrl))
        musicBusy = false
        return
    end

    Music:Stop()
    Music.SoundId = assetUrl

    local started = os.clock()
    while not Music.IsLoaded and os.clock() - started < 10 do
        task.wait(0.1)
    end

    if not Music.IsLoaded then
        setStatus("GAGAL: lagu tidak bisa dimuat (coba format mp3 atau ogg).")
        musicBusy = false
        return
    end

    currentSongPath = path
    Music:Play()
    setStatus("Memutar: " .. baseNameOf(path))
    musicBusy = false
end

PlayButton.Activated:Connect(function()
    if musicBusy then
        return
    end

    local selected = songList.selected

    if selected and selected ~= currentSongPath then
        task.spawn(loadAndPlay, selected)
    elseif currentSongPath then
        if Music.IsPaused then
            Music:Resume()
        elseif Music.IsPlaying then
            Music:Pause()
            setStatus("Dijeda: " .. baseNameOf(currentSongPath))
        else
            Music:Play()
        end
    else
        setStatus("Pilih lagu terlebih dahulu (tekan SCAN LAGU).")
    end
end)

StopButton.Activated:Connect(function()
    Music:Stop()
    setStatus("Lagu dihentikan.")
end)

LoopButton.Activated:Connect(function()
    Music.Looped = not Music.Looped
    LoopButton.Text = "LOOP: " .. (Music.Looped and "ON" or "OFF")
end)

VolDown.Activated:Connect(function()
    Music.Volume = math.max(0, math.floor(Music.Volume * 10 + 0.5) / 10 - 0.1)
    refreshVolume()
end)

VolUp.Activated:Connect(function()
    Music.Volume = math.min(1, math.floor(Music.Volume * 10 + 0.5) / 10 + 0.1)
    refreshVolume()
end)

table.insert(connections, Music.Played:Connect(function() PlayButton.Text = "PAUSE" end))
table.insert(connections, Music.Resumed:Connect(function() PlayButton.Text = "PAUSE" end))
table.insert(connections, Music.Paused:Connect(function() PlayButton.Text = "PLAY" end))
table.insert(connections, Music.Stopped:Connect(function() PlayButton.Text = "PLAY" end))
table.insert(connections, Music.Ended:Connect(function() PlayButton.Text = "PLAY" end))

--==============================================================
-- HALAMAN 3: TOOLBOX
--==============================================================

local ToolboxPage = newPage("toolbox")

local ToolboxSearch = makeBox(ToolboxPage, "Cari model / tempel Asset ID...", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32))
local ToolboxGo = makeButton(ToolboxPage, "CARI", UDim2.fromOffset(0, 38), UDim2.new(0.5, -3, 0, 32), true)
local ToolboxMore = makeButton(ToolboxPage, "MUAT LAGI", UDim2.new(0.5, 3, 0, 38), UDim2.new(0.5, -3, 0, 32))

local toolboxList = newList(
    ToolboxPage,
    UDim2.fromOffset(0, 76),
    UDim2.new(1, 0, 1, -122),
    function(entry)
        setStatus("Dipilih: " .. entry.text)
    end
)

local ToolboxImport = makeButton(ToolboxPage, "IMPORT MODEL TERPILIH", UDim2.new(0, 0, 1, -38), UDim2.new(1, 0, 0, 38), true)

local function httpGetJson(url)
    if not requestAPI then
        return nil, "fungsi request tidak tersedia di executor ini"
    end

    local ok, res = pcall(requestAPI, {
        Url = url,
        Method = "GET",
        Headers = { ["Accept"] = "application/json" },
    })

    if not ok then
        return nil, tostring(res)
    end
    if type(res) ~= "table" then
        return nil, "respon tidak valid"
    end

    local code = res.StatusCode or res.status_code
    local body = res.Body or res.body

    if type(code) == "number" and code >= 400 then
        return nil, "HTTP " .. code
    end
    if type(body) ~= "string" or body == "" then
        return nil, "respon kosong"
    end

    local okJson, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not okJson then
        return nil, "respon bukan JSON"
    end

    return data
end

local function toolboxSearch(keyword, page)
    local url = string.format(
        "https://apis.roblox.com/toolbox-service/v1/marketplace/%d?limit=30&pageNumber=%d&keyword=%s",
        TOOLBOX_CATEGORY, page, HttpService:UrlEncode(keyword)
    )

    local data, err = httpGetJson(url)
    local results = {}

    if data and type(data.data) == "table" then
        local ids = {}
        for _, entry in ipairs(data.data) do
            local id = tonumber(entry.id or entry.assetId)
            if id then
                table.insert(ids, id)
            end
        end

        if #ids > 0 then
            local info = {}
            local detailUrl = "https://apis.roblox.com/toolbox-service/v1/items/details?assetIds="
                .. table.concat(ids, "%2C")
            local details = httpGetJson(detailUrl)

            if type(details) == "table" and type(details.data) == "table" then
                for _, d in ipairs(details.data) do
                    local a = type(d.asset) == "table" and d.asset or d
                    local id = tonumber(a.id)
                    if id then
                        info[id] = {
                            name = a.name,
                            creator = type(d.creator) == "table" and d.creator.name or nil,
                        }
                    end
                end
            end

            for _, id in ipairs(ids) do
                local i = info[id] or {}
                table.insert(results, {
                    id = id,
                    name = i.name or ("Asset " .. id),
                    creator = i.creator,
                })
            end
        end
    end

    if #results > 0 then
        return results
    end

    -- Cadangan: InsertService:GetFreeModelsAsync
    local ok, pagesResult = pcall(function()
        return InsertService:GetFreeModelsAsync(keyword, page)
    end)

    if ok and type(pagesResult) == "table" and pagesResult[1]
        and type(pagesResult[1].Results) == "table" then
        for _, r in ipairs(pagesResult[1].Results) do
            table.insert(results, { id = r.AssetId, name = r.Name, creator = r.CreatorName })
        end
        if #results > 0 then
            return results
        end
    end

    if data and #results == 0 then
        return results
    end

    return nil, err or "tidak ada hasil"
end

local tbKeyword, tbPage, tbBusy = "", 0, false

local function addToolboxResults(results)
    for _, r in ipairs(results) do
        local label = r.name .. "  [" .. tostring(r.id) .. "]"
        if r.creator then
            label = label .. "  - " .. tostring(r.creator)
        end
        toolboxList.add({ text = label, value = r.id })
    end
end

local function runToolboxSearch(append)
    if tbBusy then
        return
    end

    local keyword = append and tbKeyword or trim(ToolboxSearch.Text)

    if keyword == "" then
        setStatus("Ketik kata kunci atau tempel Asset ID.")
        return
    end

    -- Jika hanya angka -> anggap Asset ID langsung
    if not append and keyword:match("^%d+$") then
        tbKeyword = ""
        toolboxList.clear()
        local choose = toolboxList.add({ text = "Asset ID " .. keyword, value = tonumber(keyword) })
        choose()
        setStatus("Asset ID siap diimpor: " .. keyword)
        return
    end

    tbBusy = true

    if append then
        tbPage += 1
    else
        tbKeyword = keyword
        tbPage = 0
        toolboxList.clear()
    end

    setStatus("Mencari di Toolbox...")

    task.spawn(function()
        local results, err = toolboxSearch(tbKeyword, tbPage)

        if not results then
            if append then
                tbPage -= 1
            end
            setStatus("Pencarian gagal: " .. tostring(err))
        elseif #results == 0 then
            if append then
                tbPage -= 1
            end
            setStatus("Tidak ada hasil lagi untuk \"" .. tbKeyword .. "\".")
        else
            addToolboxResults(results)
            setStatus("Halaman " .. (tbPage + 1) .. ": " .. #results .. " hasil. Pilih lalu IMPORT.")
        end

        tbBusy = false
    end)
end

ToolboxGo.Activated:Connect(function()
    runToolboxSearch(false)
end)

ToolboxMore.Activated:Connect(function()
    if tbKeyword == "" then
        setStatus("Lakukan pencarian dulu.")
        return
    end
    runToolboxSearch(true)
end)

ToolboxSearch.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        runToolboxSearch(false)
    end
end)

--==============================================================
-- MEMUAT FILE / ASSET
--==============================================================

local function loadFile(path)
    if not getcustomassetAPI then
        return nil, "getcustomasset tidak tersedia di executor ini."
    end

    local okAsset, assetUrl = pcall(getcustomassetAPI, path)
    if not okAsset or type(assetUrl) ~= "string" or assetUrl == "" then
        return nil, "getcustomasset gagal: " .. tostring(assetUrl)
    end

    local ok, objects = pcall(function()
        return game:GetObjects(assetUrl)
    end)
    if ok and type(objects) == "table" and #objects > 0 then
        return objects
    end
    local err1 = tostring(objects)

    local ok2, single = pcall(function()
        return InsertService:LoadLocalAsset(assetUrl)
    end)
    if ok2 and typeof(single) == "Instance" then
        return { single }
    end

    return nil, "GetObjects: " .. err1 .. " | LoadLocalAsset: " .. tostring(single)
end

local function loadToolboxAsset(id)
    local ok, objects = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if ok and type(objects) == "table" and #objects > 0 then
        return objects
    end
    local err1 = tostring(objects)

    local ok2, model = pcall(function()
        return InsertService:LoadAsset(id)
    end)
    if ok2 and typeof(model) == "Instance" then
        return { model }
    end

    return nil, "GetObjects: " .. err1 .. " | LoadAsset: " .. tostring(model)
end

--==============================================================
-- AKSI: SCAN, FILTER, IMPORT
--==============================================================

local importing = false

local function scanFiles()
    if scanning then
        return
    end

    if not listfilesAPI then
        setStatus("ERROR: API listfiles tidak tersedia di executor ini.")
        return
    end

    scanning = true
    ModelScan.Text = "MEMINDAI..."
    MusicScan.Text = "MEMINDAI..."
    setStatus("Memindai folder workspace executor...")

    table.clear(modelFiles)
    table.clear(audioFiles)

    task.spawn(function()
        local visited, counter = {}, { n = 0 }

        for _, root in ipairs(ROOT_PATHS) do
            pcall(scanDirectory, root, 0, visited, counter)
        end

        local modelCount, audioCount = 0, 0
        for _ in pairs(modelFiles) do modelCount += 1 end
        for _ in pairs(audioFiles) do audioCount += 1 end

        renderModels()
        renderSongs()

        setStatus("Scan selesai: " .. modelCount .. " model, " .. audioCount .. " lagu.")

        ModelScan.Text = "SCAN FILE"
        MusicScan.Text = "SCAN LAGU"
        scanning = false
    end)
end

ModelScan.Activated:Connect(scanFiles)
MusicScan.Activated:Connect(scanFiles)

ModelSearch:GetPropertyChangedSignal("Text"):Connect(function()
    setStatus("Ditampilkan " .. renderModels() .. " file.")
end)

MusicSearch:GetPropertyChangedSignal("Text"):Connect(function()
    setStatus("Ditampilkan " .. renderSongs() .. " lagu.")
end)

ModelFilter.Activated:Connect(function()
    modelFilterIndex = modelFilterIndex % #MODEL_FILTERS + 1
    ModelFilter.Text = "FILTER: " .. MODEL_FILTERS[modelFilterIndex]
    setStatus("Ditampilkan " .. renderModels() .. " file.")
end)

ModelImport.Activated:Connect(function()
    if importing then
        return
    end

    local path = modelList.selected
    if not path then
        setStatus("Pilih file terlebih dahulu.")
        return
    end

    if not pathExists(path) then
        setStatus("ERROR: file tidak ditemukan: " .. path)
        return
    end

    importing = true
    local isPlace = PLACE_EXT[getExtension(path)] == true
    setStatus(isPlace and "Membaca file place, file besar butuh waktu..." or "Membaca file model...")

    task.spawn(function()
        local objects, err = loadFile(path)

        if not objects then
            setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local _, message = importObjects(objects, isPlace, baseNameOf(path))
            setStatus(message)
        end

        importing = false
    end)
end)

ToolboxImport.Activated:Connect(function()
    if importing then
        return
    end

    local id = toolboxList.selected
    if not id then
        setStatus("Pilih model Toolbox terlebih dahulu.")
        return
    end

    importing = true
    setStatus("Mengunduh model " .. tostring(id) .. " dari Toolbox...")

    task.spawn(function()
        local objects, err = loadToolboxAsset(id)

        if not objects then
            setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local _, message = importObjects(objects, false, "Toolbox_" .. tostring(id))
            setStatus(message)
        end

        importing = false
    end)
end)

--==============================================================
-- TOMBOL JENDELA
--==============================================================

OpenButton.Activated:Connect(function()
    Main.Visible = not Main.Visible
end)

Minimize.Activated:Connect(function()
    Main.Visible = false
end)

Close.Activated:Connect(function()
    Music:Stop()
    Music:Destroy()
    ScreenGui:Destroy()
end)

ScreenGui.Destroying:Connect(function()
    for _, c in ipairs(connections) do
        c:Disconnect()
    end
end)

--==============================================================
-- STARTUP
--==============================================================

for _, d in ipairs(ScreenGui:GetDescendants()) do
    applyTextShadow(d)
end

refreshVolume()
switchTab("model")
Main.Visible = true

local missing = {}
if not listfilesAPI then table.insert(missing, "listfiles") end
if not isfileAPI then table.insert(missing, "isfile") end
if not getcustomassetAPI then table.insert(missing, "getcustomasset") end
if not requestAPI then table.insert(missing, "request (Toolbox pakai cadangan)") end

if #missing > 0 then
    setStatus("API tidak tersedia: " .. table.concat(missing, ", "))
else
    setStatus("Siap. Tekan SCAN FILE untuk mencari model & lagu.")
end

print("======================================")
print("PUNAKAWAN COMMUNITY IMPORTER v4")
print("listfiles:", listfilesAPI ~= nil)
print("isfile:", isfileAPI ~= nil)
print("getcustomasset:", getcustomassetAPI ~= nil)
print("request:", requestAPI ~= nil)
print("logo image:", logoImage ~= nil, "| bg image:", bgImage ~= nil)
print("======================================")
