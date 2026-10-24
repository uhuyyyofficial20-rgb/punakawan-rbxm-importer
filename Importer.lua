--==================================================
-- PUNAKAWAN COMMUNITY | IMPORTER
-- GUI file scanner untuk Delta / Roblox Studio Lite
--==================================================

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local FOLDER_PATH = "/storage/emulated/0/Delta/Workspace"

local PURPLE = Color3.fromRGB(145, 65, 255)
local DARK = Color3.fromRGB(18, 17, 24)
local PANEL = Color3.fromRGB(31, 29, 40)
local WHITE = Color3.fromRGB(245, 245, 250)
local GREEN = Color3.fromRGB(65, 200, 130)
local RED = Color3.fromRGB(255, 75, 95)

local selectedTab = "RBXM"
local selectedFile = nil
local allFiles = {}
local minimized = false

-- Hapus GUI lama agar tidak duplikat
pcall(function()
    CoreGui:FindFirstChild("PunakawanImporter"):Destroy()
end)

local GUI = Instance.new("ScreenGui")
GUI.Name = "PunakawanImporter"
GUI.ResetOnSpawn = false
GUI.IgnoreGuiInset = true
GUI.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 470, 0, 620)
Main.Position = UDim2.new(0.5, -235, 0.5, -310)
Main.BackgroundColor3 = DARK
Main.BorderSizePixel = 0
Main.Parent = GUI

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 18)

local Border = Instance.new("UIStroke")
Border.Color = PURPLE
Border.Thickness = 2
Border.Parent = Main

local function make(class, name, parent, props)
    local obj = Instance.new(class)
    obj.Name = name

    for property, value in pairs(props or {}) do
        obj[property] = value
    end

    obj.Parent = parent
    return obj
end

local Header = make("Frame", "Header", Main, {
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundColor3 = Color3.fromRGB(27, 23, 38),
    BorderSizePixel = 0
})

Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

make("TextLabel", "Title", Header, {
    Position = UDim2.new(0, 18, 0, 0),
    Size = UDim2.new(1, -135, 1, 0),
    BackgroundTransparency = 1,
    Text = "PUNAKAWAN COMMUNITY | IMPORTER",
    TextColor3 = WHITE,
    TextSize = 14,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left
})

local Minimize = make("TextButton", "Minimize", Header, {
    Position = UDim2.new(1, -100, 0, 12),
    Size = UDim2.new(0, 36, 0, 36),
    BackgroundColor3 = PANEL,
    Text = "—",
    TextColor3 = WHITE,
    TextSize = 20,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
})

Instance.new("UICorner", Minimize).CornerRadius = UDim.new(0, 9)

local Close = make("TextButton", "Close", Header, {
    Position = UDim2.new(1, -52, 0, 12),
    Size = UDim2.new(0, 36, 0, 36),
    BackgroundColor3 = RED,
    Text = "X",
    TextColor3 = WHITE,
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
})

Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 9)

local Status = make("TextLabel", "Status", Main, {
    Position = UDim2.new(0, 18, 0, 70),
    Size = UDim2.new(1, -36, 0, 48),
    BackgroundColor3 = PANEL,
    Text = "Siap. Tekan SCAN untuk mencari file.",
    TextColor3 = WHITE,
    TextSize = 12,
    TextWrapped = true,
    Font = Enum.Font.Gotham,
    BorderSizePixel = 0
})

Instance.new("UICorner", Status).CornerRadius = UDim.new(0, 10)

local Search = make("TextBox", "Search", Main, {
    Position = UDim2.new(0, 162, 0, 178),
    Size = UDim2.new(1, -180, 0, 44),
    BackgroundColor3 = PANEL,
    PlaceholderText = "Cari file...",
    Text = "",
    TextColor3 = WHITE,
    PlaceholderColor3 = Color3.fromRGB(150, 145, 160),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
    BorderSizePixel = 0
})

Instance.new("UICorner", Search).CornerRadius = UDim.new(0, 9)

local Scan = make("TextButton", "Scan", Main, {
    Position = UDim2.new(0, 18, 0, 178),
    Size = UDim2.new(0, 132, 0, 44),
    BackgroundColor3 = PURPLE,
    Text = "SCAN",
    TextColor3 = WHITE,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
})

Instance.new("UICorner", Scan).CornerRadius = UDim.new(0, 9)

local Tabs = make("Frame", "Tabs", Main, {
    Position = UDim2.new(0, 18, 0, 130),
    Size = UDim2.new(1, -36, 0, 40),
    BackgroundTransparency = 1
})

local tabNames = {"RBXM", "RBXL", "OTHER"}
local tabButtons = {}

for i, tabName in ipairs(tabNames) do
    local button = make("TextButton", tabName, Tabs, {
        Position = UDim2.new((i - 1) / 3, 0, 0, 0),
        Size = UDim2.new(1 / 3, -7, 1, 0),
        BackgroundColor3 = tabName == selectedTab and PURPLE or PANEL,
        Text = tabName,
        TextColor3 = WHITE,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0
    })

    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 9)

    tabButtons[tabName] = button

    button.MouseButton1Click:Connect(function()
        selectedTab = tabName
        selectedFile = nil

        for name, tabButton in pairs(tabButtons) do
            tabButton.BackgroundColor3 =
                name == selectedTab and PURPLE or PANEL
        end

        Status.Text = "Kategori: " .. selectedTab
        Status.TextColor3 = WHITE

        -- Perbarui daftar dari hasil pemindaian terakhir
        if Scan then
            task.defer(function()
                Search:ReleaseFocus()
                -- Render dipanggil setelah fungsi dibuat
                if _G.PunakawanRenderFiles then
                    _G.PunakawanRenderFiles()
                end
            end)
        end
    end)
end

local List = make("ScrollingFrame", "FileList", Main, {
    Position = UDim2.new(0, 18, 0, 228),
    Size = UDim2.new(1, -36, 0, 260),
    BackgroundColor3 = Color3.fromRGB(14, 14, 19),
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    ScrollBarImageColor3 = PURPLE,
    CanvasSize = UDim2.new(0, 0, 0, 0)
})

Instance.new("UICorner", List).CornerRadius = UDim.new(0, 10)

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 7)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = List

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0, 8)
Padding.PaddingLeft = UDim.new(0, 8)
Padding.PaddingRight = UDim.new(0, 8)
Padding.PaddingBottom = UDim.new(0, 8)
Padding.Parent = List

local SelectedLabel = make("TextLabel", "SelectedLabel", Main, {
    Position = UDim2.new(0, 18, 0, 496),
    Size = UDim2.new(1, -36, 0, 32),
    BackgroundTransparency = 1,
    Text = "Belum ada file dipilih.",
    TextColor3 = GREEN,
    TextSize = 12,
    TextWrapped = true,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left
})

local Import = make("TextButton", "Import", Main, {
    Position = UDim2.new(0, 18, 0, 548),
    Size = UDim2.new(1, -36, 0, 42),
    BackgroundColor3 = PURPLE,
    Text = "IMPORT FILE",
    TextColor3 = WHITE,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0
})

Instance.new("UICorner", Import).CornerRadius = UDim.new(0, 10)

-- Tombol buka kembali saat GUI diminimalkan
local Reopen = make("TextButton", "Reopen", GUI, {
    Position = UDim2.new(0, 15, 0.4, 0),
    Size = UDim2.new(0, 55, 0, 55),
    BackgroundColor3 = PURPLE,
    Text = "P",
    TextColor3 = WHITE,
    TextSize = 22,
    Font = Enum.Font.GothamBold,
    Visible = false,
    BorderSizePixel = 0
})

Instance.new("UICorner", Reopen).CornerRadius = UDim.new(1, 0)

-- Drag GUI dengan mouse atau sentuhan
do
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
        if not dragging then return end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

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
end

local function getExtension(name)
    return string.lower(name:match("%.([^%.]+)$") or "")
end

local function belongsToTab(name)
    local ext = getExtension(name)

    if selectedTab == "RBXM" then
        return ext == "rbxm" or ext == "rbxmx"
    elseif selectedTab == "RBXL" then
        return ext == "rbxl" or ext == "rbxlx"
    else
        return ext ~= "rbxm"
            and ext ~= "rbxmx"
            and ext ~= "rbxl"
            and ext ~= "rbxlx"
    end
end

local function renderFiles()
    for _, child in ipairs(List:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local count = 0
    local query = string.lower(Search.Text)

    for _, path in ipairs(allFiles) do
        local filename = path:gsub("\\", "/"):match("([^/]+)$") or path

        if belongsToTab(filename)
            and string.find(string.lower(filename), query, 1, true) then

            count += 1

            local button = make("TextButton", "File_" .. count, List, {
                Size = UDim2.new(1, -4, 0, 48),
                BackgroundColor3 = path == selectedFile
                    and PURPLE or Color3.fromRGB(24, 23, 30),
                Text = filename,
                TextColor3 = WHITE,
                TextSize = 12,
                Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BorderSizePixel = 0,
                LayoutOrder = count
            })

            make("UIPadding", "TextPadding", button, {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8)
            })

            Instance.new("UICorner", button).CornerRadius =
                UDim.new(0, 8)

            button.MouseButton1Click:Connect(function()
                selectedFile = path
                SelectedLabel.Text = "Dipilih: " .. filename
                Status.Text = "File dipilih: " .. filename
                renderFiles()
            end)
        end
    end

    if count == 0 then
        make("TextLabel", "Empty", List, {
            Size = UDim2.new(1, -4, 0, 45),
            BackgroundTransparency = 1,
            Text = "Tidak ada file di kategori ini.",
            TextColor3 = Color3.fromRGB(165, 160, 175),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            LayoutOrder = 1
        })
    end

    task.defer(function()
        List.CanvasSize = UDim2.new(
            0, 0, 0, Layout.AbsoluteContentSize.Y + 16
        )
    end)
end

_G.PunakawanRenderFiles = renderFiles

Scan.MouseButton1Click:Connect(function()
    if type(listfiles) ~= "function" then
        Status.Text = "ERROR: Delta tidak menyediakan fungsi listfiles()."
        Status.TextColor3 = RED
        return
    end

    local ok, result = pcall(listfiles, FOLDER_PATH)

    if not ok or type(result) ~= "table" then
        Status.Text = "Folder tidak dapat dibaca: " .. FOLDER_PATH
        Status.TextColor3 = RED
        return
    end

    allFiles = result
    selectedFile = nil
    SelectedLabel.Text = "Belum ada file dipilih."

    Status.Text = "Pemindaian selesai: " .. #allFiles .. " file ditemukan."
    Status.TextColor3 = GREEN

    renderFiles()
end)

Search:GetPropertyChangedSignal("Text"):Connect(renderFiles)

Import.MouseButton1Click:Connect(function()
    if not selectedFile then
        Status.Text = "Pilih file terlebih dahulu."
        Status.TextColor3 = RED
        return
    end

    local filename =
        selectedFile:gsub("\\", "/"):match("([^/]+)$") or selectedFile

    local ext = getExtension(filename)

    if ext == "rbxm" or ext == "rbxmx" then
        Status.Text =
            "File terpilih: " .. filename ..
            "\nImpor belum dijalankan. Diperlukan parser RBXM kompatibel."
    elseif ext == "rbxl" or ext == "rbxlx" then
        Status.Text =
            "RBXL adalah file tempat. Tidak bisa dimasukkan sebagai model biasa."
    else
        Status.Text =
            "Format file ini belum didukung untuk impor ke Workspace."
    end

    Status.TextColor3 = RED

    warn("[Punakawan] Import belum dilakukan: " .. filename)
end)

Minimize.MouseButton1Click:Connect(function()
    minimized = true
    Main.Visible = false
    Reopen.Visible = true
end)

Reopen.MouseButton1Click:Connect(function()
    minimized = false
    Main.Visible = true
    Reopen.Visible = false
end)

Close.MouseButton1Click:Connect(function()
    GUI:Destroy()
    _G.PunakawanRenderFiles = nil
end)

renderFiles()

print("[Punakawan] Importer GUI berhasil dimuat.")
print("[Punakawan] Folder: " .. FOLDER_PATH)
