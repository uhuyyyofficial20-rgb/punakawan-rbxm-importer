--==================================================--
--       PUNAKAWAN COMMUNITY IMPORTER
--       RBXM / RBXMX IMPORTER
--==================================================--

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

-- CONFIGURATION
local CONFIG = {
    Title = "PUNAKAWAN COMMUNITY",
    Subtitle = "RBXM IMPORTER",
    Folder = "Delta/Workspace",
}

-- CLEAN OLD GUI
pcall(function()
    local old = CoreGui:FindFirstChild("PunakawanImporter")
    if old then
        old:Destroy()
    end
end)

-- SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PunakawanImporter"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    ScreenGui.Parent = CoreGui
end)

if not ScreenGui.Parent then
    ScreenGui.Parent = Player:WaitForChild("PlayerGui")
end

-- MAIN FRAME
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 380, 0, 430)
Main.Position = UDim2.new(0.5, -190, 0.5, -215)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(130, 75, 255)
MainStroke.Thickness = 1.5
MainStroke.Parent = Main

-- HEADER
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 75)
Header.BackgroundColor3 = Color3.fromRGB(35, 23, 58)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -55, 0, 32)
Title.Position = UDim2.new(0, 14, 0, 8)
Title.BackgroundTransparency = 1
Title.Text = CONFIG.Title
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -25, 0, 20)
Subtitle.Position = UDim2.new(0, 14, 0, 42)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = CONFIG.Subtitle .. "  •  COMMUNITY EDITION"
Subtitle.TextColor3 = Color3.fromRGB(190, 165, 255)
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

-- CLOSE BUTTON
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 32, 0, 32)
CloseButton.Position = UDim2.new(1, -40, 0, 10)
CloseButton.BackgroundColor3 = Color3.fromRGB(80, 45, 110)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.Parent = Header

Instance.new("UICorner", CloseButton).CornerRadius = UDim.new(0, 8)

CloseButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- SEARCH BOX
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -28, 0, 36)
SearchBox.Position = UDim2.new(0, 14, 0, 88)
SearchBox.BackgroundColor3 = Color3.fromRGB(31, 31, 42)
SearchBox.TextColor3 = Color3.new(1, 1, 1)
SearchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 165)
SearchBox.PlaceholderText = "Cari file RBXM / RBXMX..."
SearchBox.Text = ""
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = Main

Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)

-- SCAN BUTTON
local ScanButton = Instance.new("TextButton")
ScanButton.Size = UDim2.new(1, -28, 0, 36)
ScanButton.Position = UDim2.new(0, 14, 0, 134)
ScanButton.BackgroundColor3 = Color3.fromRGB(112, 64, 220)
ScanButton.Text = "SCAN FILE"
ScanButton.TextColor3 = Color3.new(1, 1, 1)
ScanButton.Font = Enum.Font.GothamBold
ScanButton.TextSize = 13
ScanButton.Parent = Main

Instance.new("UICorner", ScanButton).CornerRadius = UDim.new(0, 8)

-- FILE LIST
local FileList = Instance.new("ScrollingFrame")
FileList.Size = UDim2.new(1, -28, 0, 155)
FileList.Position = UDim2.new(0, 14, 0, 180)
FileList.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
FileList.BorderSizePixel = 0
FileList.ScrollBarThickness = 4
FileList.CanvasSize = UDim2.new(0, 0, 0, 0)
FileList.Parent = Main

Instance.new("UICorner", FileList).CornerRadius = UDim.new(0, 8)

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 5)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = FileList

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 7)
ListPadding.PaddingLeft = UDim.new(0, 7)
ListPadding.PaddingRight = UDim.new(0, 7)
ListPadding.Parent = FileList

-- STATUS
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -28, 0, 25)
Status.Position = UDim2.new(0, 14, 0, 345)
Status.BackgroundTransparency = 1
Status.Text = "Status: Siap"
Status.TextColor3 = Color3.fromRGB(190, 190, 205)
Status.Font = Enum.Font.Gotham
Status.TextSize = 11
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Main

-- IMPORT BUTTON
local ImportButton = Instance.new("TextButton")
ImportButton.Size = UDim2.new(1, -28, 0, 38)
ImportButton.Position = UDim2.new(0, 14, 0, 374)
ImportButton.BackgroundColor3 = Color3.fromRGB(40, 155, 100)
ImportButton.Text = "IMPORT FILE TERPILIH"
ImportButton.TextColor3 = Color3.new(1, 1, 1)
ImportButton.Font = Enum.Font.GothamBold
ImportButton.TextSize = 12
ImportButton.Parent = Main

Instance.new("UICorner", ImportButton).CornerRadius = UDim.new(0, 8)

-- DATA
local Files = {}
local SelectedFile = nil
local FileButtons = {}

local function SetStatus(message, color)
    Status.Text = "Status: " .. tostring(message)
    Status.TextColor3 = color or Color3.fromRGB(190, 190, 205)
end

local function ClearFiles()
    for _, object in ipairs(FileList:GetChildren()) do
        if object:IsA("TextButton") then
            object:Destroy()
        end
    end

    table.clear(FileButtons)
end

local function IsSupportedFile(name)
    local lower = string.lower(name)

    return lower:match("%.rbxm$")
        or lower:match("%.rbxmx$")
end

local function RenderFiles()
    ClearFiles()

    local query = string.lower(SearchBox.Text)
    local order = 0

    for _, filePath in ipairs(Files) do
        local fileName = filePath:match("[^/\\]+$") or filePath

        if query == "" or string.find(string.lower(fileName), query, 1, true) then
            order += 1

            local Button = Instance.new("TextButton")
            Button.Name = "FileItem"
            Button.Size = UDim2.new(1, -5, 0, 32)
            Button.BackgroundColor3 = Color3.fromRGB(39, 39, 52)
            Button.Text = "  " .. fileName
            Button.TextColor3 = Color3.fromRGB(225, 225, 240)
            Button.TextXAlignment = Enum.TextXAlignment.Left
            Button.Font = Enum.Font.Gotham
            Button.TextSize = 11
            Button.LayoutOrder = order
            Button.Parent = FileList

            Instance.new("UICorner", Button).CornerRadius = UDim.new(0, 6)

            Button.MouseButton1Click:Connect(function()
                SelectedFile = filePath

                for _, item in ipairs(FileButtons) do
                    item.BackgroundColor3 = Color3.fromRGB(39, 39, 52)
                end

                Button.BackgroundColor3 = Color3.fromRGB(90, 55, 150)
                SetStatus("Dipilih: " .. fileName)
            end)

            table.insert(FileButtons, Button)
        end
    end

    FileList.CanvasSize = UDim2.new(0, 0, 0, order * 37 + 10)

    if order == 0 then
        SetStatus("File tidak ditemukan")
    else
        SetStatus(order .. " file ditemukan")
    end
end

-- SCAN FILES
local function ScanFiles()
    if type(listfiles) ~= "function" then
        SetStatus("Delta tidak mendukung listfiles()", Color3.fromRGB(255, 100, 100))
        return
    end

    table.clear(Files)
    SelectedFile = nil

    SetStatus("Memindai folder...")

    local success, result = pcall(function()
        return listfiles(CONFIG.Folder)
    end)

    if not success or type(result) ~= "table" then
        SetStatus("Folder tidak dapat dibaca", Color3.fromRGB(255, 100, 100))
        return
    end

    for _, path in ipairs(result) do
        if type(path) == "string" and IsSupportedFile(path) then
            table.insert(Files, path)
        end
    end

    table.sort(Files)
    RenderFiles()
end

ScanButton.MouseButton1Click:Connect(ScanFiles)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    RenderFiles()
end)

-- IMPORT FILE
local function ImportSelectedFile()
    if not SelectedFile then
        SetStatus("Pilih file terlebih dahulu", Color3.fromRGB(255, 190, 80))
        return
    end

    local fileName = SelectedFile:match("[^/\\]+$") or SelectedFile

    if type(readfile) ~= "function" then
        SetStatus("Delta tidak mendukung readfile()", Color3.fromRGB(255, 100, 100))
        return
    end

    local readSuccess, fileData = pcall(function()
        return readfile(SelectedFile)
    end)

    if not readSuccess or type(fileData) ~= "string" then
        SetStatus("Gagal membaca file", Color3.fromRGB(255, 100, 100))
        return
    end

    -- This GUI reads the selected file, but reading bytes does
    -- not itself import a model into the Studio Lite editor.
    local lowerName = string.lower(fileName)

    if lowerName:match("%.rbxm$") or lowerName:match("%.rbxmx$") then
        SetStatus("File terbaca; perlu API importer Studio Lite", Color3.fromRGB(255, 190, 80))

        warn("[PUNAKAWAN COMMUNITY IMPORTER] File:", fileName)
        warn("[PUNAKAWAN COMMUNITY IMPORTER] Bytes:", #fileData)
        warn("[PUNAKAWAN COMMUNITY IMPORTER] File berhasil dibaca, tetapi belum dimasukkan ke editor.")
    else
        SetStatus("Format file tidak didukung", Color3.fromRGB(255, 100, 100))
    end
end

ImportButton.MouseButton1Click:Connect(ImportSelectedFile)

-- FOOTER
local Footer = Instance.new("TextLabel")
Footer.Size = UDim2.new(1, -28, 0, 15)
Footer.Position = UDim2.new(0, 14, 1, -17)
Footer.BackgroundTransparency = 1
Footer.Text = "PUNAKAWAN COMMUNITY ©"
Footer.TextColor3 = Color3.fromRGB(120, 120, 140)
Footer.Font = Enum.Font.Gotham
Footer.TextSize = 9
Footer.Parent = Main

SetStatus("Siap digunakan")

print("PUNAKAWAN COMMUNITY IMPORTER loaded")
