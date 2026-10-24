--====================================================
-- PUNAKAWAN IMPORTER
-- Black & Purple Edition
-- GUI + File Scanner + Draggable + Minimize + Close
--====================================================

local success, errorMessage = pcall(function()

    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local player = Players.LocalPlayer

    assert(player, "LocalPlayer tidak tersedia")

    local playerGui = player:WaitForChild("PlayerGui")

    --==============================================
    -- REOPEN EXISTING GUI
    --==============================================

    local existing = playerGui:FindFirstChild("PunakawanImporter")

    if existing then
        existing.Enabled = true

        local main = existing:FindFirstChild("Main")
        local toggle = existing:FindFirstChild("ToggleButton")

        if main then
            main.Visible = true
        end

        if toggle then
            toggle.Visible = false
        end

        return
    end

    --==============================================
    -- CONFIGURATION
    --==============================================

    local CONFIG = {
        Folder = "Delta/Workspace/",
        Title = "PUNAKAWAN IMPORTER",
    }

    local COLOR = {
        Background = Color3.fromRGB(19, 16, 27),
        Panel = Color3.fromRGB(34, 28, 45),
        Purple = Color3.fromRGB(145, 65, 255),
        PurpleDark = Color3.fromRGB(83, 42, 135),
        White = Color3.fromRGB(245, 240, 255),
        Gray = Color3.fromRGB(175, 165, 190),
        Red = Color3.fromRGB(220, 65, 85),
        Green = Color3.fromRGB(90, 210, 140),
    }

    --==============================================
    -- HELPERS
    --==============================================

    local function create(className, properties, parent)
        local object = Instance.new(className)

        for key, value in pairs(properties) do
            object[key] = value
        end

        object.Parent = parent
        return object
    end

    local function corner(object, radius)
        create("UICorner", {
            CornerRadius = UDim.new(0, radius or 8)
        }, object)
    end

    local function stroke(object, color, thickness)
        create("UIStroke", {
            Color = color,
            Thickness = thickness or 1,
        }, object)
    end

    local function button(parent, name, text, position, size, bg)
        local object = create("TextButton", {
            Name = name,
            Text = text,
            Position = position,
            Size = size,
            BackgroundColor3 = bg,
            TextColor3 = COLOR.White,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = true,
            BorderSizePixel = 0,
        }, parent)

        corner(object, 8)
        return object
    end

    --==============================================
    -- SCREEN GUI
    --==============================================

    local gui = create("ScreenGui", {
        Name = "PunakawanImporter",
        ResetOnSpawn = false,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)

    --==============================================
    -- MAIN PANEL
    --==============================================

    local main = create("Frame", {
        Name = "Main",
        Size = UDim2.new(0, 340, 0, 430),
        Position = UDim2.new(0.5, -170, 0.5, -215),
        BackgroundColor3 = COLOR.Background,
        BorderSizePixel = 0,
        Active = true,
    }, gui)

    corner(main, 14)
    stroke(main, COLOR.Purple, 1.5)

    --==============================================
    -- HEADER
    --==============================================

    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 65),
        BackgroundColor3 = COLOR.Panel,
        BorderSizePixel = 0,
        Active = true,
    }, main)

    corner(header, 14)

    create("Frame", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -14),
        BackgroundColor3 = COLOR.Panel,
        BorderSizePixel = 0,
    }, header)

    create("TextLabel", {
        Size = UDim2.new(1, -125, 0, 28),
        Position = UDim2.new(0, 12, 0, 7),
        BackgroundTransparency = 1,
        Text = CONFIG.Title,
        TextColor3 = COLOR.White,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    create("TextLabel", {
        Size = UDim2.new(1, -125, 0, 18),
        Position = UDim2.new(0, 12, 0, 35),
        BackgroundTransparency = 1,
        Text = "RBXM / RBXL • MOBILE",
        TextColor3 = COLOR.Gray,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local minimize = button(
        header, "MinimizeButton", "—",
        UDim2.new(1, -76, 0, 16),
        UDim2.new(0, 30, 0, 30),
        COLOR.PurpleDark
    )

    local close = button(
        header, "CloseButton", "X",
        UDim2.new(1, -40, 0, 16),
        UDim2.new(0, 30, 0, 30),
        COLOR.Red
    )

    --==============================================
    -- FLOATING REOPEN BUTTON
    --==============================================

    local toggle = button(
        gui, "ToggleButton", "P",
        UDim2.new(0, 18, 0.5, -26),
        UDim2.new(0, 52, 0, 52),
        COLOR.Purple
    )

    toggle.TextSize = 22
    toggle.Visible = false
    corner(toggle, 26)

    --==============================================
    -- FORMAT SELECTOR
    --==============================================

    create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 22),
        Position = UDim2.new(0, 12, 0, 75),
        BackgroundTransparency = 1,
        Text = "PILIH FORMAT FILE",
        TextColor3 = COLOR.Gray,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    local selectedFormat = "RBXM"

    local rbxmButton = button(
        main, "RBXMButton", "RBXM / RBXMX",
        UDim2.new(0, 12, 0, 101),
        UDim2.new(0, 153, 0, 36),
        COLOR.Purple
    )

    local rbxlButton = button(
        main, "RBXLButton", "RBXL / RBXLX",
        UDim2.new(0, 175, 0, 101),
        UDim2.new(0, 153, 0, 36),
        COLOR.Panel
    )

    --==============================================
    -- FILE LIST
    --==============================================

    create("TextLabel", {
        Size = UDim2.new(1, -100, 0, 24),
        Position = UDim2.new(0, 12, 0, 145),
        BackgroundTransparency = 1,
        Text = "DAFTAR FILE",
        TextColor3 = COLOR.White,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    local refresh = button(
        main, "RefreshButton", "REFRESH",
        UDim2.new(1, -94, 0, 143),
        UDim2.new(0, 82, 0, 27),
        COLOR.PurpleDark
    )

    local list = create("ScrollingFrame", {
        Name = "FileList",
        Position = UDim2.new(0, 12, 0, 175),
        Size = UDim2.new(1, -24, 0, 155),
        BackgroundColor3 = COLOR.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = COLOR.Purple,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    }, main)

    corner(list, 9)

    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, list)

    create("UIPadding", {
        PaddingTop = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        PaddingBottom = UDim.new(0, 7),
    }, list)

    --==============================================
    -- STATUS
    --==============================================

    local status = create("TextLabel", {
        Name = "Status",
        Position = UDim2.new(0, 12, 0, 335),
        Size = UDim2.new(1, -24, 0, 34),
        BackgroundTransparency = 1,
        Text = "Status: Siap.",
        TextColor3 = COLOR.Gray,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, main)

    local importButton = button(
        main, "ImportButton", "IMPORT FILE TERPILIH",
        UDim2.new(0, 12, 0, 377),
        UDim2.new(1, -24, 0, 40),
        COLOR.Purple
    )

    local function setStatus(message, color)
        status.Text = "Status: " .. message
        status.TextColor3 = color or COLOR.Gray
    end

    --==============================================
    -- FILE SCANNER
    --==============================================

    local selectedFile = nil
    local fileButtons = {}

    local function clearList()
        for _, item in ipairs(fileButtons) do
            item:Destroy()
        end

        table.clear(fileButtons)
        selectedFile = nil
    end

    local function getExecutorFunction(name)
        local fn = nil

        pcall(function()
            if type(getgenv) == "function" then
                local env = getgenv()
                if env then
                    fn = env[name]
                end
            end
        end)

        if type(fn) == "function" then
            return fn
        end

        pcall(function()
            if type(getfenv) == "function" then
                fn = getfenv(0)[name]
            end
        end)

        if type(fn) == "function" then
            return fn
        end

        return nil
    end

    local function refreshFiles()
        clearList()

        local listfilesFn = getExecutorFunction("listfiles")

        if not listfilesFn then
            setStatus(
                "Delta tidak menyediakan listfiles().",
                COLOR.Red
            )
            return
        end

        local ok, result = pcall(function()
            return listfilesFn(CONFIG.Folder)
        end)

        if not ok then
            setStatus(
                "Folder tidak bisa dibaca: " .. CONFIG.Folder,
                COLOR.Red
            )
            return
        end

        if type(result) ~= "table" then
            setStatus("Hasil pembacaan folder tidak valid.", COLOR.Red)
            return
        end

        local count = 0

        for _, path in ipairs(result) do
            if type(path) == "string" then
                local lower = path:lower()
                local matched

                if selectedFormat == "RBXM" then
                    matched = lower:match("%.rbxm$")
                        or lower:match("%.rbxmx$")
                else
                    matched = lower:match("%.rbxl$")
                        or lower:match("%.rbxlx$")
                end

                if matched then
                    count += 1

                    local filename = path:match("([^/\\]+)$") or path

                    local item = button(
                        list,
                        "File_" .. count,
                        filename,
                        UDim2.new(),
                        UDim2.new(1, -4, 0, 34),
                        COLOR.Background
                    )

                    item.LayoutOrder = count
                    item.TextSize = 10
                    item.Font = Enum.Font.Gotham
                    item.TextXAlignment = Enum.TextXAlignment.Left

                    table.insert(fileButtons, item)

                    item.MouseButton1Click:Connect(function()
                        selectedFile = path

                        for _, other in ipairs(fileButtons) do
                            other.BackgroundColor3 = COLOR.Background
                        end

                        item.BackgroundColor3 = COLOR.PurpleDark
                        setStatus("Dipilih: " .. filename, COLOR.Green)
                    end)
                end
            end
        end

        list.CanvasSize = UDim2.new(
            0, 0, 0, layout.AbsoluteContentSize.Y + 15
        )

        if count == 0 then
            setStatus(
                "File tidak ditemukan. Periksa folder dan ekstensi.",
                COLOR.Gray
            )
        else
            setStatus(count .. " file ditemukan.", COLOR.Green)
        end
    end

    rbxmButton.MouseButton1Click:Connect(function()
        selectedFormat = "RBXM"
        rbxmButton.BackgroundColor3 = COLOR.Purple
        rbxlButton.BackgroundColor3 = COLOR.Panel
        refreshFiles()
    end)

    rbxlButton.MouseButton1Click:Connect(function()
        selectedFormat = "RBXL"
        rbxlButton.BackgroundColor3 = COLOR.Panel
        rbxmButton.BackgroundColor3 = COLOR.Panel
        refreshFiles()
    end)

    refresh.MouseButton1Click:Connect(refreshFiles)

    importButton.MouseButton1Click:Connect(function()
        if not selectedFile then
            setStatus("Pilih file terlebih dahulu.", COLOR.Red)
            return
        end

        setStatus(
            "Parser impor RBXM/RBXL belum tersedia.",
            Color3.fromRGB(255, 190, 90)
        )
    end)

    --==============================================
    -- MINIMIZE / RESTORE / CLOSE
    --==============================================

    minimize.MouseButton1Click:Connect(function()
        main.Visible = false
        toggle.Visible = true
    end)

    toggle.MouseButton1Click:Connect(function()
        main.Visible = true
        toggle.Visible = false
    end)

    close.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    --==============================================
    -- DRAG WINDOW: TOUCH + MOUSE
    --==============================================

    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil

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

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (
            input == dragInput
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

    --==============================================
    -- INITIALIZE
    --==============================================

    refreshFiles()

end)

if not success then
    warn("[PUNAKAWAN IMPORTER] " .. tostring(errorMessage))
end
