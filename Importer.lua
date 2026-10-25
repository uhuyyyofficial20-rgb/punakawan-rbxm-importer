--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER v5.1 (FIXED)
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

local SPAWN_POSITION = Vector3.new(0, 0.5, 0)
local USE_SPAWNLOCATION = false
local STACK_ON_PREVIOUS = false

local ROOT_PATHS = { "", ".", "workspace", "Workspace" }
local MAX_DEPTH = 20

local RUN_SCRIPTS_DEFAULT = false

local EXPORT_SCRIPT_FILES = true
local SCRIPT_EXPORT_FOLDER = "PunawakanScripts"

local API_HOSTS = { "apis.roblox.com", "apis.roproxy.com" }
local ASSET_HOSTS = { "assetdelivery.roblox.com", "assetdelivery.roproxy.com" }
local THUMB_HOSTS = { "thumbnails.roblox.com", "thumbnails.roproxy.com" }

local GUI_SCALE = Vector2.new(0.62, 0.9)
local GUI_MIN = Vector2.new(370, 340)
local GUI_MAX = Vector2.new(480, 560)

local RGB_SPEED = 0.2

local TOOLBOX_CATEGORY = 10

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
local readfileAPI = getAPI("readfile")
local writefileAPI = getAPI("writefile")
local makefolderAPI = getAPI("makefolder")
local setscriptsourceAPI = getAPI("setscriptsource")
local sethiddenpropertyAPI = getAPI("sethiddenproperty")

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

-- Daftar variasi path yang akan dicoba ketika membaca file.
-- Beberapa executor kadang butuh "./" prefix, kadang butuh "workspace/" prefix.
local function fileVariants(path)
    local p = normalizePath(path)
    local list, seen = {}, {}

    local function add(v)
        if v and v ~= "" and not seen[v] then
            seen[v] = true
            list[#list + 1] = v
        end
    end

    add(p)

    local stripped = p:match("^[Ww]orkspace/(.+)$")
    if stripped then
        add(stripped)
        add("./" .. stripped)
    end

    add("./" .. p)
    add("workspace/" .. p)
    add("Workspace/" .. p)

    return list
end

-- Mengembalikan path yang benar-benar bisa dibaca, atau nil.
local function findFile(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    for _, variant in ipairs(fileVariants(path)) do
        if isfileAPI then
            local ok, result = pcall(isfileAPI, variant)
            if ok and result then
                return variant
            end
        end
        if readfileAPI then
            local ok, data = pcall(readfileAPI, variant)
            if ok and type(data) == "string" and #data > 0 then
                return variant
            end
        end
    end

    return nil
end

local function pathExists(path)
    return findFile(path) ~= nil
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

    if file and file ~= "" and getcustomassetAPI then
        local resolved = findFile(file)
        if resolved then
            local ok, url = pcall(getcustomassetAPI, resolved)
            if ok and type(url) == "string" and url ~= "" then
                return url
            end
        end
    end

    return nil
end

local logoImage = resolveImage(LOGO_FILE, LOGO_ASSET_ID)
local bgImage = resolveImage(BG_FILE, BG_ASSET_ID)

--==============================================================
-- PARSER FILE
--==============================================================

local RbxParser
do
--@@PARSER_BEGIN
RbxParser = {}

RbxParser.yield = function() end

local sbyte, ssub, schar = string.byte, string.sub, string.char

local function u32(s, p)
    local a, b, c, d = sbyte(s, p, p + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

local yieldCounter = 0
local function tick(n)
    yieldCounter = yieldCounter + n
    if yieldCounter > 400000 then
        yieldCounter = 0
        RbxParser.yield()
    end
end

local function lz4Decompress(src)
    local out, n = {}, 0
    local i, len = 1, #src

    while i <= len do
        local token = sbyte(src, i)
        i = i + 1

        local lit = math.floor(token / 16)
        if lit == 15 then
            local b
            repeat
                b = sbyte(src, i)
                i = i + 1
                lit = lit + b
            until b ~= 255
        end

        for j = 0, lit - 1 do
            out[n + j + 1] = sbyte(src, i + j)
        end
        n = n + lit
        i = i + lit
        tick(lit)

        if i > len then
            break
        end

        local offset = sbyte(src, i) + sbyte(src, i + 1) * 256
        i = i + 2

        local ml = token % 16
        if ml == 15 then
            local b
            repeat
                b = sbyte(src, i)
                i = i + 1
                ml = ml + b
            until b ~= 255
        end
        ml = ml + 4

        local from = n - offset
        for j = 1, ml do
            out[n + j] = out[from + j]
        end
        n = n + ml
        tick(ml)
    end

    local parts = {}
    for k = 1, n, 2048 do
        parts[#parts + 1] = schar(table.unpack(out, k, math.min(k + 2047, n)))
    end
    return table.concat(parts)
end

local function readIntArray(data, pos, count)
    local arr = {}
    for i = 0, count - 1 do
        local b0 = sbyte(data, pos + i)
        local b1 = sbyte(data, pos + count + i)
        local b2 = sbyte(data, pos + 2 * count + i)
        local b3 = sbyte(data, pos + 3 * count + i)
        local x = b0 * 16777216 + b1 * 65536 + b2 * 256 + b3
        if x % 2 == 1 then
            arr[i + 1] = -((x + 1) / 2)
        else
            arr[i + 1] = x / 2
        end
    end
    tick(count * 4)
    return arr, pos + count * 4
end

local function accumulate(arr)
    for i = 2, #arr do
        arr[i] = arr[i] + arr[i - 1]
    end
    return arr
end

local function readString(data, pos)
    local l = u32(data, pos)
    return ssub(data, pos + 4, pos + 3 + l), pos + 4 + l
end

function RbxParser.parseBinary(data)
    if ssub(data, 1, 8) ~= "<roblox!" then
        return nil, "bukan file RBXM/RBXL biner"
    end

    local classes, inst, roots = {}, {}, {}
    local pos, len = 33, #data

    while pos + 15 <= len do
        local cname = ssub(data, pos, pos + 3)
        local comp = u32(data, pos + 4)
        local unc = u32(data, pos + 8)
        local start = pos + 16
        local chunk

        if comp == 0 then
            chunk = ssub(data, start, start + unc - 1)
            pos = start + unc
        else
            local raw = ssub(data, start, start + comp - 1)
            if ssub(raw, 1, 4) == "\40\181\47\253" then
                return nil, "file memakai kompresi ZSTD (belum didukung)"
            end
            chunk = lz4Decompress(raw)
            pos = start + comp
        end

        if cname == "INST" then
            local classId = u32(chunk, 1)
            local className, p = readString(chunk, 5)
            p = p + 1
            local count = u32(chunk, p)
            p = p + 4
            local refs = readIntArray(chunk, p, count)
            accumulate(refs)

            classes[classId] = { name = className, refs = refs }
            for _, ref in ipairs(refs) do
                inst[ref] = { class = className, name = className, children = {} }
            end

        elseif cname == "PROP" then
            local classId = u32(chunk, 1)
            local propName, p = readString(chunk, 5)
            local typeId = sbyte(chunk, p)
            p = p + 1

            local cls = classes[classId]
            if cls and typeId == 1 then
                local isName = (propName == "Name")
                local isSource = (propName == "Source") and string.find(cls.name, "Script", 1, true) ~= nil

                if isName or isSource then
                    for _, ref in ipairs(cls.refs) do
                        local str
                        str, p = readString(chunk, p)
                        local node = inst[ref]
                        if node then
                            if isName then
                                node.name = str
                            else
                                node.source = str
                            end
                        end
                    end
                end
            end

        elseif cname == "PRNT" then
            local count = u32(chunk, 2)
            local p = 6
            local childRefs, parentRefs
            childRefs, p = readIntArray(chunk, p, count)
            accumulate(childRefs)
            parentRefs, p = readIntArray(chunk, p, count)
            accumulate(parentRefs)

            for i = 1, count do
                local child = inst[childRefs[i]]
                local parentRef = parentRefs[i]
                if child then
                    if parentRef == -1 then
                        roots[#roots + 1] = child
                    else
                        local parent = inst[parentRef]
                        if parent then
                            parent.children[#parent.children + 1] = child
                        end
                    end
                end
            end

        elseif cname == "END\0" then
            break
        end
    end

    return roots
end

local function unescapeXml(s)
    s = s:gsub("&#(%d+);", function(n)
        return utf8.char(tonumber(n))
    end)
    s = s:gsub("&lt;", "<")
    s = s:gsub("&gt;", ">")
    s = s:gsub("&quot;", '"')
    s = s:gsub("&apos;", "'")
    s = s:gsub("&amp;", "&")
    return s
end

local function xmlContent(raw)
    if string.find(raw, "<![CDATA[", 1, true) then
        local parts = {}
        for piece in string.gmatch(raw, "<!%[CDATA%[(.-)%]%]>") do
            parts[#parts + 1] = piece
        end
        return table.concat(parts)
    end
    return unescapeXml(raw)
end

function RbxParser.parseXml(xml)
    local roots, stack = {}, {}
    local pos, len = 1, #xml
    local steps = 0

    while true do
        local lt = string.find(xml, "<", pos, true)
        if not lt then
            break
        end

        steps = steps + 1
        if steps % 20000 == 0 then
            RbxParser.yield()
        end

        if ssub(xml, lt, lt + 3) == "<!--" then
            local e = string.find(xml, "-->", lt, true)
            pos = (e or len) + 3

        elseif ssub(xml, lt, lt + 8) == "<![CDATA[" then
            local e = string.find(xml, "]]>", lt, true)
            pos = (e or len) + 3

        else
            local gt = string.find(xml, ">", lt, true)
            if not gt then
                break
            end

            local tag = ssub(xml, lt + 1, gt - 1)
            local selfClosing = ssub(tag, -1) == "/"
            pos = gt + 1

            if ssub(tag, 1, 5) == "Item " then
                local class = string.match(tag, 'class="([^"]*)"') or "Instance"
                local node = { class = class, name = class, children = {} }
                local top = stack[#stack]
                if top then
                    top.children[#top.children + 1] = node
                else
                    roots[#roots + 1] = node
                end
                if not selfClosing then
                    stack[#stack + 1] = node
                end

            elseif tag == "/Item" then
                stack[#stack] = nil

            elseif not selfClosing and #stack > 0 then
                local closeTag
                local isName = string.match(tag, '^string name="Name"') ~= nil
                local isSource = string.match(tag, '^ProtectedString name="Source"') ~= nil
                    or string.match(tag, '^string name="Source"') ~= nil

                if isName then
                    closeTag = "</string>"
                elseif isSource then
                    closeTag = string.match(tag, "^ProtectedString") and "</ProtectedString>" or "</string>"
                end

                if closeTag then
                    local e = string.find(xml, closeTag, pos, true)
                    if e then
                        local content = xmlContent(ssub(xml, pos, e - 1))
                        local top = stack[#stack]
                        if isName then
                            top.name = content
                        elseif string.find(top.class, "Script", 1, true) then
                            top.source = content
                        end
                        pos = e + #closeTag
                    end
                end
            end
        end
    end

    return roots
end

function RbxParser.parse(data)
    if type(data) ~= "string" or #data < 16 then
        return nil, "isi file kosong"
    end
    if ssub(data, 1, 8) == "<roblox!" then
        return RbxParser.parseBinary(data)
    end
    if string.find(ssub(data, 1, 200), "<roblox", 1, true) then
        return RbxParser.parseXml(data)
    end
    return nil, "format file tidak dikenali"
end

function RbxParser.countScripts(nodes)
    local n = 0
    for _, node in ipairs(nodes) do
        if node.source ~= nil then
            n = n + 1
        end
        n = n + RbxParser.countScripts(node.children)
    end
    return n
end

local function matchLevel(liveList, parsedList, cb, path)
    local groups = {}
    for _, p in ipairs(parsedList) do
        local k = p.class .. "\0" .. p.name
        local g = groups[k]
        if not g then
            g = { i = 0 }
            groups[k] = g
        end
        g[#g + 1] = p
    end

    for _, live in ipairs(liveList) do
        local k = live.ClassName .. "\0" .. live.Name
        local g = groups[k]
        if g then
            g.i = g.i + 1
            local p = g[g.i]
            if p then
                local ppath = path .. "/" .. live.Name
                cb(live, p, ppath)
                matchLevel(live:GetChildren(), p.children, cb, ppath)
            end
        end
    end
end

function RbxParser.match(liveRoots, parsedRoots, cb)
    local live = {}
    for _, o in ipairs(liveRoots) do
        if o.ClassName == "DataModel" then
            for _, c in ipairs(o:GetChildren()) do
                live[#live + 1] = c
            end
        else
            live[#live + 1] = o
        end
    end

    local hits = 0
    local function counting(l, p, path)
        if p.source ~= nil then
            hits = hits + 1
        end
        cb(l, p, path)
    end

    matchLevel(live, parsedRoots, counting, "")

    if hits == 0 then
        local flat = {}
        for _, r in ipairs(parsedRoots) do
            for _, c in ipairs(r.children) do
                flat[#flat + 1] = c
            end
        end
        matchLevel(live, flat, counting, "")
    end

    return hits
end
--@@PARSER_END

end

RbxParser.yield = function()
    task.wait()
end

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
    scrim = Color3.fromRGB(6, 6, 10),
}

-- Saat pakai BG image: panel lebih solid supaya teks tetap jelas
local panelTransparency = bgImage and 0.35 or 0.7

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

-- Text shadow diperkuat agar tetap terbaca di atas BG image
local function applyTextShadow(inst)
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inst.TextStrokeColor3 = Color3.new(0, 0, 0)
        inst.TextStrokeTransparency = bgImage and 0.15 or 0.45
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

for _, name in ipairs({ "PunawakanMusic", "PunawakanAudio", "PunawakanOut", "PunawakanWire" }) do
    local old = SoundService:FindFirstChild(name)
    if old then
        old:Destroy()
    end
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
OpenButton.BackgroundColor3 = THEME.bg
OpenButton.BackgroundTransparency = 0.3
OpenButton.Text = ""
OpenButton.Parent = ScreenGui
corner(OpenButton, 12)
rgbStroke(OpenButton, 2, 0.1)

if logoImage then
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

-- BG image + scrim gelap agar teks tetap kontras
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

    local scrim = Instance.new("Frame")
    scrim.Name = "Scrim"
    scrim.Size = UDim2.fromScale(1, 1)
    scrim.BackgroundColor3 = THEME.scrim
    scrim.BackgroundTransparency = 0.35
    scrim.BorderSizePixel = 0
    scrim.ZIndex = 0
    scrim.Parent = Main
    corner(scrim, 14)
end

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = THEME.header
Header.BackgroundTransparency = bgImage and 0.25 or 0.65
Header.BorderSizePixel = 0
Header.ZIndex = 2
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
Title.ZIndex = 3
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
Minimize.ZIndex = 3
Minimize.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(34, 34)
Close.Position = UDim2.new(1, -40, 0, 5)
Close.BackgroundTransparency = 1
Close.Text = "X"
Close.TextColor3 = THEME.text
Close.TextSize = 17
Close.Font = Enum.Font.GothamBold
Close.ZIndex = 3
Close.Parent = Header

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, -28, 0, 2)
HeaderLine.Position = UDim2.fromOffset(14, 44)
HeaderLine.BackgroundColor3 = Color3.new(1, 1, 1)
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = 3
HeaderLine.Parent = Main
addRGB(HeaderLine)

-- Tab -----------------------------------------------------------
local TabBar = Instance.new("Frame")
TabBar.Position = UDim2.fromOffset(10, 52)
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.BackgroundTransparency = 1
TabBar.ZIndex = 2
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
    button.ZIndex = 3
    button.Parent = TabBar

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = Color3.new(1, 1, 1)
    line.BorderSizePixel = 0
    line.Visible = false
    line.ZIndex = 3
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
PagesHolder.ZIndex = 2
PagesHolder.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 30)
Status.Position = UDim2.new(0, 10, 1, -34)
Status.BackgroundTransparency = 1
Status.Text = "Siap."
Status.TextColor3 = THEME.muted
Status.TextSize = 10
Status.Font = Enum.Font.Gotham
Status.TextWrapped = true
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.TextYAlignment = Enum.TextYAlignment.Center
Status.ZIndex = 3
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
    frame.ZIndex = 2
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
    button.ZIndex = 3
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
    box.BackgroundTransparency = math.max(panelTransparency - 0.05, 0.15)
    box.TextColor3 = THEME.text
    box.PlaceholderColor3 = THEME.muted
    box.PlaceholderText = placeholder
    box.Text = ""
    box.ClearTextOnFocus = false
    box.TextSize = 13
    box.Font = Enum.Font.Gotham
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ZIndex = 3
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
    frame.BackgroundTransparency = math.max(panelTransparency - 0.05, 0.1)
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.CanvasSize = UDim2.new()
    frame.ZIndex = 3
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
        button.ZIndex = 4
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

local function newGrid(parent, position, size, onSelect, onNearEnd)
    local frame = Instance.new("ScrollingFrame")
    frame.Position = position
    frame.Size = size
    frame.BackgroundColor3 = THEME.panel
    frame.BackgroundTransparency = math.max(panelTransparency - 0.05, 0.1)
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.CanvasSize = UDim2.new()
    frame.ZIndex = 3
    frame.Parent = parent
    corner(frame, 8)
    rgbStroke(frame, 1, 0.5)

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.3, 0, 0, 128)
    grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 6)
    padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = frame

    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 12)
    end)

    local ctl = { frame = frame, cells = {}, selectedCell = nil, selected = nil }

    function ctl.clear()
        for _, c in ipairs(ctl.cells) do
            c.button:Destroy()
        end
        ctl.cells = {}
        ctl.selectedCell = nil
        ctl.selected = nil
        frame.CanvasPosition = Vector2.zero
    end

    function ctl.add(entry)
        local button = Instance.new("TextButton")
        button.Text = ""
        button.AutoButtonColor = false
        button.BackgroundColor3 = THEME.item
        button.BackgroundTransparency = 0.25
        button.LayoutOrder = #ctl.cells + 1
        button.ZIndex = 4
        button.Parent = frame
        corner(button, 8)

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(150, 120, 255)
        stroke.Transparency = 1
        stroke.Parent = button

        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Position = UDim2.fromOffset(4, 4)
        img.Size = UDim2.new(1, -8, 1, -40)
        img.ScaleType = Enum.ScaleType.Fit
        img.Image = entry.thumb or ""
        img.ZIndex = 5
        img.Parent = button
        corner(img, 6)

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 4, 1, -34)
        label.Size = UDim2.new(1, -8, 0, 32)
        label.Text = entry.text
        label.TextColor3 = THEME.text
        label.TextSize = 10
        label.Font = Enum.Font.Gotham
        label.TextWrapped = true
        label.TextTruncate = Enum.TextTruncate.AtEnd
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.ZIndex = 5
        label.Parent = button
        applyTextShadow(label)

        local cell = { button = button, stroke = stroke, img = img }
        table.insert(ctl.cells, cell)

        local function choose()
            if ctl.selectedCell then
                ctl.selectedCell.stroke.Transparency = 1
                ctl.selectedCell.button.BackgroundColor3 = THEME.item
            end
            ctl.selectedCell = cell
            ctl.selected = entry.value
            stroke.Transparency = 0
            button.BackgroundColor3 = THEME.itemSelected
            onSelect(entry)
        end

        button.Activated:Connect(choose)
        return choose
    end

    frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if onNearEnd and frame.AbsoluteCanvasSize.Y > 0
            and frame.CanvasPosition.Y + frame.AbsoluteWindowSize.Y >= frame.AbsoluteCanvasSize.Y - 80 then
            onNearEnd()
        end
    end)

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
-- PENEMPATAN DI POSISI SPAWN
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

    local groundY
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate and baseplate:IsA("BasePart") then
        local rel = baseplate.CFrame:PointToObjectSpace(spawnPoint)
        if math.abs(rel.X) <= baseplate.Size.X / 2 and math.abs(rel.Z) <= baseplate.Size.Z / 2 then
            groundY = baseplate.Position.Y + baseplate.Size.Y / 2
        end
    end

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
-- IMPOR OBJEK
--==============================================================

local SERVICE_NAMES = {
    Lighting = true, ServerScriptService = true, ServerStorage = true,
    ReplicatedStorage = true, ReplicatedFirst = true, StarterGui = true,
    StarterPack = true, StarterPlayer = true, SoundService = true,
    Teams = true, Chat = true, TextChatService = true, MaterialService = true,
}

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
        table.insert(parts, report.services .. " objek ke service")
    end
    if report.gui > 0 then
        table.insert(parts, report.gui .. " GUI ke PlayerGui")
    end

    local message = "BERHASIL: " .. table.concat(parts, ", ") .. ". Script ikut masuk apa adanya."

    if report.failed > 0 then
        message = message .. " | " .. report.failed .. " objek ditolak Roblox."
    end

    return true, message .. placeNote
end

--==============================================================
-- PEMINDAI FILE
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
local ModelScan = makeButton(ModelPage, "SCAN FILE", UDim2.fromOffset(0, 38), UDim2.new(1 / 3, -3, 0, 32), true)
local ModelFilter = makeButton(ModelPage, "FILTER: ALL", UDim2.new(1 / 3, 1, 0, 38), UDim2.new(1 / 3, -2, 0, 32))
local ModelRun = makeButton(ModelPage, "RUN: OFF", UDim2.new(2 / 3, 3, 0, 38), UDim2.new(1 / 3, -3, 0, 32))

local runScriptsEnabled = RUN_SCRIPTS_DEFAULT

local function refreshRunButton()
    ModelRun.Text = "RUN: " .. (runScriptsEnabled and "ON" or "OFF")
end

ModelRun.Activated:Connect(function()
    runScriptsEnabled = not runScriptsEnabled
    refreshRunButton()
    setStatus(runScriptsEnabled
        and "RUN ON: script hasil import akan dijalankan (hati-hati)."
        or "RUN OFF: script hanya dimasukkan, tidak dijalankan.")
end)

refreshRunButton()

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
VolLabel.ZIndex = 3
VolLabel.Parent = MusicPage
local VolUp = makeButton(MusicPage, "VOL +", UDim2.new(0.7, 4, 1, -34), UDim2.new(0.3, -4, 0, 34))

local Audio = {
    kind = nil,
    obj = nil,
    extra = {},
    volume = 0.5,
    looped = false,
    path = nil,
    busy = false,
}

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
    VolLabel.Text = "VOLUME " .. math.floor(Audio.volume * 100 + 0.5) .. "%"
end

local function audioIsPlaying()
    if not Audio.obj then
        return false
    end
    local ok, value = pcall(function()
        return Audio.obj.IsPlaying
    end)
    return ok and value == true
end

local function applyAudioSettings()
    if not Audio.obj then
        return
    end
    pcall(function()
        Audio.obj.Volume = Audio.volume
    end)
    pcall(function()
        if Audio.kind == "sound" then
            Audio.obj.Looped = Audio.looped
        else
            Audio.obj.Looping = Audio.looped
        end
    end)
end

local function clearAudio()
    if Audio.obj then
        pcall(function()
            Audio.obj:Stop()
        end)
        pcall(function()
            Audio.obj:Destroy()
        end)
    end
    for _, o in ipairs(Audio.extra) do
        pcall(function()
            o:Destroy()
        end)
    end
    Audio.obj = nil
    Audio.extra = {}
    Audio.kind = nil
end

local function trySound(url)
    local s = Instance.new("Sound")
    s.Name = "PunawakanMusic"
    s.Volume = Audio.volume
    s.Looped = Audio.looped
    s.SoundId = url
    s.Parent = SoundService

    local t0 = os.clock()
    while os.clock() - t0 < 8 and not (s.IsLoaded and s.TimeLength > 0) do
        task.wait(0.1)
    end

    if not (s.IsLoaded and s.TimeLength > 0) then
        local info = "IsLoaded=" .. tostring(s.IsLoaded) .. " TimeLength=" .. tostring(s.TimeLength)
        s:Destroy()
        return false, info
    end

    s:Play()
    task.wait(0.5)

    if s.IsPlaying then
        Audio.obj = s
        Audio.kind = "sound"
        return true
    end

    s:Destroy()
    return false, "termuat tapi tidak berbunyi"
end

local function tryAudioPlayer(url)
    local created = {}

    local ok, err = pcall(function()
        local ap = Instance.new("AudioPlayer")
        ap.Name = "PunawakanAudio"
        ap.Volume = Audio.volume
        ap.Looping = Audio.looped
        ap.Asset = url
        ap.Parent = SoundService
        table.insert(created, ap)

        local out = Instance.new("AudioDeviceOutput")
        out.Name = "PunawakanOut"
        out.Parent = SoundService
        table.insert(created, out)

        local wire = Instance.new("Wire")
        wire.Name = "PunawakanWire"
        wire.SourceInstance = ap
        wire.TargetInstance = out
        wire.Parent = SoundService
        table.insert(created, wire)
    end)

    local function destroyCreated()
        for _, o in ipairs(created) do
            pcall(function()
                o:Destroy()
            end)
        end
    end

    if not ok then
        destroyCreated()
        return false, tostring(err)
    end

    local ap = created[1]

    local function ready()
        local okR, value = pcall(function()
            return ap.IsReady and ap.TimeLength > 0
        end)
        return okR and value == true
    end

    local t0 = os.clock()
    while os.clock() - t0 < 8 and not ready() do
        task.wait(0.1)
    end

    pcall(function()
        ap:Play()
    end)
    task.wait(0.5)

    local okP, playing = pcall(function()
        return ap.IsPlaying
    end)

    if okP and playing then
        Audio.obj = ap
        Audio.kind = "audio"
        Audio.extra = { created[2], created[3] }
        return true
    end

    destroyCreated()
    return false, "AudioPlayer tidak berbunyi"
end

local function makeCopy(path)
    if not (readfileAPI and writefileAPI) then
        return nil
    end

    local resolved = findFile(path)
    if not resolved then
        return nil
    end

    local okR, data = pcall(readfileAPI, resolved)
    if not okR or type(data) ~= "string" or #data == 0 then
        return nil
    end

    pcall(function()
        if makefolderAPI and not folderExists("PunawakanCache") then
            makefolderAPI("PunawakanCache")
        end
    end)

    local copyPath = "PunawakanCache/track_" .. tostring(os.time()) .. "_"
        .. tostring(math.floor(os.clock() * 1000)) .. "." .. getExtension(path)

    if pcall(writefileAPI, copyPath, data) then
        return copyPath
    end

    return nil
end

local function loadAndPlay(path)
    if Audio.busy then
        return
    end

    if not getcustomassetAPI then
        setStatus("ERROR: getcustomasset tidak tersedia di executor ini.")
        return
    end

    local resolved = findFile(path)
    if not resolved then
        setStatus("ERROR: file lagu tidak ditemukan: " .. path)
        return
    end

    Audio.busy = true
    clearAudio()
    setStatus("Memuat lagu...")

    local reasons = {}

    local function attempt(url, label)
        local ok1, e1 = trySound(url)
        if ok1 then
            return true
        end
        table.insert(reasons, label .. "/Sound: " .. tostring(e1))

        local ok2, e2 = tryAudioPlayer(url)
        if ok2 then
            return true
        end
        table.insert(reasons, label .. "/AudioPlayer: " .. tostring(e2))

        return false
    end

    local done = false

    local okA, url = pcall(getcustomassetAPI, resolved)
    if okA and type(url) == "string" and url ~= "" then
        done = attempt(url, "asli")
    else
        table.insert(reasons, "getcustomasset: " .. tostring(url))
    end

    if not done then
        local copyPath = makeCopy(resolved)
        if copyPath then
            local okB, url2 = pcall(getcustomassetAPI, copyPath)
            if okB and type(url2) == "string" and url2 ~= "" then
                done = attempt(url2, "salinan")
            else
                table.insert(reasons, "salinan getcustomasset: " .. tostring(url2))
            end
        end
    end

    if done then
        Audio.path = path
        applyAudioSettings()
        setStatus("Memutar: " .. baseNameOf(path) .. " (" .. tostring(Audio.kind) .. ")")
    else
        Audio.path = nil
        print("[Punakawan] Lagu gagal diputar: " .. path)
        for _, r in ipairs(reasons) do
            print("[Punakawan]   - " .. r)
        end
        setStatus("GAGAL memutar. " .. (reasons[1] or "") .. " (detail di console)")
    end

    Audio.busy = false
end

PlayButton.Activated:Connect(function()
    if Audio.busy then
        return
    end

    local selected = songList.selected

    if selected and selected ~= Audio.path then
        task.spawn(loadAndPlay, selected)
    elseif Audio.obj then
        if audioIsPlaying() then
            pcall(function()
                Audio.obj:Pause()
            end)
            setStatus("Dijeda: " .. baseNameOf(Audio.path or ""))
        else
            pcall(function()
                if Audio.kind == "sound" and Audio.obj.IsPaused then
                    Audio.obj:Resume()
                else
                    Audio.obj:Play()
                end
            end)
        end
    else
        setStatus("Pilih lagu terlebih dahulu (tekan SCAN LAGU).")
    end
end)

StopButton.Activated:Connect(function()
    if Audio.obj then
        pcall(function()
            Audio.obj:Stop()
        end)
    end
    setStatus("Lagu dihentikan.")
end)

LoopButton.Activated:Connect(function()
    Audio.looped = not Audio.looped
    LoopButton.Text = "LOOP: " .. (Audio.looped and "ON" or "OFF")
    applyAudioSettings()
end)

VolDown.Activated:Connect(function()
    Audio.volume = math.max(0, math.floor(Audio.volume * 10 + 0.5) / 10 - 0.1)
    refreshVolume()
    applyAudioSettings()
end)

VolUp.Activated:Connect(function()
    Audio.volume = math.min(1, math.floor(Audio.volume * 10 + 0.5) / 10 + 0.1)
    refreshVolume()
    applyAudioSettings()
end)

task.spawn(function()
    while ScreenGui.Parent do
        PlayButton.Text = audioIsPlaying() and "PAUSE" or "PLAY"
        task.wait(0.4)
    end
end)

--==============================================================
-- HALAMAN 3: TOOLBOX
--==============================================================

local ToolboxPage = newPage("toolbox")

local ToolboxSearch = makeBox(ToolboxPage, "Cari model (nama) atau tempel Asset ID...", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32))
local ToolboxGo = makeButton(ToolboxPage, "CARI", UDim2.fromOffset(0, 38), UDim2.new(0.5, -3, 0, 32), true)
local ToolboxMore = makeButton(ToolboxPage, "MUAT LAGI", UDim2.new(0.5, 3, 0, 38), UDim2.new(0.5, -3, 0, 32))

local tbKeyword, tbPage, tbBusy, tbEnd, tbStarted = "", 0, false, false, false
local runToolboxSearch

local toolboxList = newGrid(
    ToolboxPage,
    UDim2.fromOffset(0, 76),
    UDim2.new(1, 0, 1, -122),
    function(entry)
        setStatus("Dipilih: " .. entry.text .. " [" .. tostring(entry.value) .. "]")
    end,
    function()
        runToolboxSearch(true)
    end
)

local ToolboxImport = makeButton(ToolboxPage, "IMPORT MODEL TERPILIH", UDim2.new(0, 0, 1, -38), UDim2.new(1, 0, 0, 38), true)

local function httpBody(url: string): string?
    if requestAPI then
        local ok, res = pcall(requestAPI, {
            Url = url,
            Method = "GET",
            Headers = { ["Accept"] = "*/*" },
        })

        if ok and type(res) == "table" then
            local code = res.StatusCode or res.status_code
            local body = res.Body or res.body
            local success = res.Success
            if success == nil then
                success = (type(code) ~= "number") or code < 400
            end
            if success and type(body) == "string" and body ~= "" then
                return body
            end
        end
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and body ~= "" then
        return body
    end

    return nil
end

local function httpJson(path)
    for index, host in ipairs(API_HOSTS) do
        local body = httpBody("https://" .. host .. path)
        if body then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(body)
            end)
            if ok and type(data) == "table" then
                if index > 1 then
                    table.remove(API_HOSTS, index)
                    table.insert(API_HOSTS, 1, host)
                end
                return data
            end
        end
    end
    return nil, "server Toolbox tidak bisa dijangkau dari executor ini"
end

local function thumbUrl(id)
    return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150"
end

-- Ambil URL thumbnail asli via API (batch). Fallback: tabel kosong.
local function fetchThumbnails(ids)
    if #ids == 0 then
        return {}
    end

    local idStrings = {}
    for _, id in ipairs(ids) do
        idStrings[#idStrings + 1] = tostring(id)
    end
    local idList = table.concat(idStrings, ",")

    for _, host in ipairs(THUMB_HOSTS) do
        local url = "https://" .. host
            .. "/v1/assets?assetIds=" .. idList
            .. "&size=150x150&format=Png&isCircular=false"
        local body = httpBody(url)
        if body then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(body)
            end)
            if ok and type(data) == "table" and type(data.data) == "table" then
                local result = {}
                for _, item in ipairs(data.data) do
                    local tid = tonumber(item.targetId)
                    local imgUrl = item.imageUrl
                    if tid and type(imgUrl) == "string" and imgUrl ~= "" then
                        result[tid] = imgUrl
                    end
                end
                if next(result) then
                    return result
                end
            end
        end
    end

    return {}
end

local function toolboxSearch(keyword, page)
    local data, err = httpJson(string.format(
        "/toolbox-service/v1/marketplace/%d?limit=30&pageNumber=%d&keyword=%s",
        TOOLBOX_CATEGORY, page, HttpService:UrlEncode(keyword)
    ))

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
            local details = httpJson("/toolbox-service/v1/items/details?assetIds=" .. table.concat(ids, "%2C"))

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
                table.insert(results, { id = id, name = i.name or ("Asset " .. id), creator = i.creator })
            end
        end

        return results
    end

    local ok, pagesResult = pcall(function()
        return InsertService:GetFreeModelsAsync(keyword, page)
    end)

    if ok and type(pagesResult) == "table" and pagesResult[1] and type(pagesResult[1].Results) == "table" then
        for _, r in ipairs(pagesResult[1].Results) do
            table.insert(results, { id = r.AssetId, name = r.Name, creator = r.CreatorName })
        end
        return results
    end

    return nil, err or "tidak ada hasil"
end

local function addToolboxResults(results)
    if #results == 0 then
        return
    end

    -- Batch-fetch thumbnail sekali supaya tidak boros request
    local ids = {}
    for _, r in ipairs(results) do
        ids[#ids + 1] = r.id
    end

    local thumbMap = fetchThumbnails(ids)

    for _, r in ipairs(results) do
        local thumb = thumbMap[r.id] or thumbUrl(r.id)
        toolboxList.add({
            text = tostring(r.name) .. (r.creator and ("\nby " .. tostring(r.creator)) or ""),
            value = r.id,
            thumb = thumb,
        })
    end
end

runToolboxSearch = function(append)
    if tbBusy then
        return
    end

    local keyword

    if append then
        if not tbStarted or tbEnd then
            return
        end
        keyword = tbKeyword
    else
        keyword = trim(ToolboxSearch.Text)

        -- Jika hanya angka -> anggap Asset ID langsung
        if keyword:match("^%d+$") then
            tbStarted = false
            toolboxList.clear()
            local id = tonumber(keyword)
            local thumbMap = fetchThumbnails({ id })
            local choose = toolboxList.add({
                text = "Asset ID " .. keyword,
                value = id,
                thumb = thumbMap[id] or thumbUrl(id),
            })
            choose()
            return
        end
    end

    tbBusy = true

    if append then
        tbPage = tbPage + 1
    else
        tbKeyword = keyword
        tbPage = 0
        tbEnd = false
        tbStarted = true
        toolboxList.clear()
    end

    setStatus(keyword == "" and "Memuat model populer..." or ("Mencari \"" .. keyword .. "\"..."))

    task.spawn(function()
        local results, err = toolboxSearch(tbKeyword, tbPage)

        if not results then
            if append then
                tbPage = tbPage - 1
            end
            setStatus("Pencarian gagal: " .. tostring(err))
        elseif #results == 0 then
            tbEnd = true
            if append then
                tbPage = tbPage - 1
                setStatus("Sudah semua hasil ditampilkan.")
            else
                setStatus("Tidak ada hasil untuk kata kunci ini.")
            end
        else
            addToolboxResults(results)
            setStatus("Halaman " .. (tbPage + 1) .. ": " .. #results .. " model. Pilih lalu IMPORT.")
        end

        tbBusy = false
    end)
end

ToolboxGo.Activated:Connect(function()
    runToolboxSearch(false)
end)

ToolboxMore.Activated:Connect(function()
    if not tbStarted then
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

local toolboxOpened = false
tabButtons.toolbox.Activated:Connect(function()
    if not toolboxOpened then
        toolboxOpened = true
        runToolboxSearch(false)
    end
end)

--==============================================================
-- PEMULIHAN ISI SCRIPT
--==============================================================

local ScriptClasses = { Script = true, LocalScript = true, ModuleScript = true }
local ScriptRegistry = setmetatable({}, { __mode = "k" })
local moduleCache = setmetatable({}, { __mode = "k" })

local okEnv, BASE_ENV = pcall(function()
    return getfenv()
end)
if not okEnv or type(BASE_ENV) ~= "table" then
    BASE_ENV = _G
end

local function sanitizeName(s)
    local clean = tostring(s):gsub("[^%w%._%- ]", "_")
    if clean == "" then
        clean = "_"
    end
    return clean
end

local function setScriptSource(inst, source)
    if setscriptsourceAPI and pcall(setscriptsourceAPI, inst, source) then
        return true
    end

    if pcall(function()
        inst.Source = source
    end) then
        local okRead, current = pcall(function()
            return inst.Source
        end)
        if not okRead or current == source then
            return true
        end
    end

    if sethiddenpropertyAPI and pcall(sethiddenpropertyAPI, inst, "Source", source) then
        return true
    end

    return false
end

local function exportScripts(label, items)
    if not writefileAPI or #items == 0 then
        return 0
    end

    local function ensureFolder(p)
        if makefolderAPI and not folderExists(p) then
            pcall(makefolderAPI, p)
        end
    end

    local base = SCRIPT_EXPORT_FOLDER .. "/" .. sanitizeName(label)
    ensureFolder(SCRIPT_EXPORT_FOLDER)
    ensureFolder(base)

    local used, count = {}, 0

    for _, item in ipairs(items) do
        local segments = {}
        for seg in string.gmatch(item.path, "[^/]+") do
            table.insert(segments, sanitizeName(seg))
        end

        if #segments > 0 then
            local folder = base
            for i = 1, #segments - 1 do
                folder = folder .. "/" .. segments[i]
                ensureFolder(folder)
            end

            local file = folder .. "/" .. segments[#segments]
            local candidate, n = file .. ".lua", 1
            while used[string.lower(candidate)] do
                n = n + 1
                candidate = file .. "_" .. n .. ".lua"
            end
            used[string.lower(candidate)] = true

            if pcall(writefileAPI, candidate, item.source) then
                count = count + 1
            end
        end
    end

    return count
end

local function restoreScripts(objects, bytes, label)
    local stats = { inFile = 0, matched = 0, setOK = 0, exported = 0, list = {}, err = nil }

    local okP, r1, r2 = pcall(RbxParser.parse, bytes)
    local parsed, perr
    if okP then
        parsed, perr = r1, r2
    else
        perr = tostring(r1)
    end

    if not parsed then
        stats.err = perr or "gagal membaca file"
        return stats
    end

    stats.inFile = RbxParser.countScripts(parsed)
    if stats.inFile == 0 then
        return stats
    end

    local exportItems = {}

    pcall(RbxParser.match, objects, parsed, function(live, p, path)
        if p.source ~= nil and ScriptClasses[live.ClassName] then
            stats.matched = stats.matched + 1
            ScriptRegistry[live] = { source = p.source, path = path }
            table.insert(stats.list, live)
            if setScriptSource(live, p.source) then
                stats.setOK = stats.setOK + 1
            end
            table.insert(exportItems, { path = path, source = p.source })
        end
    end)

    if EXPORT_SCRIPT_FILES then
        stats.exported = exportScripts(label, exportItems)
    end

    return stats
end

local function describeScripts(stats)
    if not stats then
        return ""
    end

    if stats.err and stats.inFile == 0 then
        return " | Script: isi tak terbaca (" .. tostring(stats.err) .. ")"
    end

    if stats.inFile == 0 then
        return " | Tidak ada script di file."
    end

    local msg = " | Script " .. stats.matched .. "/" .. stats.inFile .. " terbaca"

    if stats.setOK > 0 then
        msg = msg .. ", " .. stats.setOK .. " terpasang"
    end
    if stats.exported > 0 then
        msg = msg .. ", " .. stats.exported .. " diekspor ke " .. SCRIPT_EXPORT_FOLDER
    end

    return msg
end

local function makeEnv(inst)
    return setmetatable({
        script = inst,
        require = function(m)
            local info = typeof(m) == "Instance" and ScriptRegistry[m] or nil
            if info and m.ClassName == "ModuleScript" then
                if moduleCache[m] then
                    return moduleCache[m][1]
                end
                local fn, err = loadstring(info.source, "=" .. info.path)
                if not fn then
                    error(err)
                end
                setfenv(fn, makeEnv(m))
                local result = fn()
                moduleCache[m] = { result }
                return result
            end
            return require(m)
        end,
    }, { __index = BASE_ENV })
end

local function runScripts(list)
    local started = 0

    for _, inst in ipairs(list) do
        local info = ScriptRegistry[inst]
        if info and inst.ClassName ~= "ModuleScript" then
            local disabled = false
            pcall(function()
                disabled = inst.Disabled
            end)

            if not disabled then
                local fn, err = loadstring(info.source, "=" .. info.path)
                if fn then
                    setfenv(fn, makeEnv(inst))
                    task.spawn(fn)
                    started = started + 1
                else
                    warn("[Punakawan] gagal kompilasi " .. info.path .. ": " .. tostring(err))
                end
            end
        end
    end

    return started
end

--==============================================================
-- MEMUAT FILE / ASSET
--==============================================================

local function readFileBytes(path)
    if not readfileAPI then
        return nil
    end
    local resolved = findFile(path) or path
    local ok, data = pcall(readfileAPI, resolved)
    if ok and type(data) == "string" and #data > 0 then
        return data
    end
    return nil
end

local EMPTY_STATS = function(reason)
    return { inFile = 0, matched = 0, setOK = 0, exported = 0, list = {}, err = reason }
end

local function loadFile(path)
    if not getcustomassetAPI then
        return nil, "getcustomasset tidak tersedia di executor ini."
    end

    local resolved = findFile(path)
    if not resolved then
        return nil, "file tidak ditemukan: " .. tostring(path)
    end

    local okAsset, assetUrl = pcall(getcustomassetAPI, resolved)
    if not okAsset or type(assetUrl) ~= "string" or assetUrl == "" then
        return nil, "getcustomasset gagal: " .. tostring(assetUrl)
    end

    local objects

    local ok, result = pcall(function()
        return game:GetObjects(assetUrl)
    end)
    if ok and type(result) == "table" and #result > 0 then
        objects = result
    else
        local err1 = tostring(result)
        local ok2, single = pcall(function()
            return InsertService:LoadLocalAsset(assetUrl)
        end)
        if ok2 and typeof(single) == "Instance" then
            objects = { single }
        else
            return nil, "GetObjects: " .. err1 .. " | LoadLocalAsset: " .. tostring(single)
        end
    end

    local bytes = readFileBytes(resolved)
    local stats
    if bytes then
        stats = restoreScripts(objects, bytes, baseNameOf(path))
    else
        stats = EMPTY_STATS("readfile tidak tersedia")
    end

    return objects, nil, stats
end

local function fetchAssetBytes(id)
    for _, host in ipairs(ASSET_HOSTS) do
        local body = httpBody("https://" .. host .. "/v1/asset/?id=" .. tostring(id))
        if type(body) == "string" then
            local head = string.sub(body, 1, 200)
            if string.sub(head, 1, 8) == "<roblox!" or string.find(head, "<roblox", 1, true) then
                return body
            end
        end
    end
    return nil
end

local function loadToolboxAsset(id)
    local objects

    local ok, result = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if ok and type(result) == "table" and #result > 0 then
        objects = result
    else
        local err1 = tostring(result)
        local ok2, model = pcall(function()
            return InsertService:LoadAsset(id)
        end)
        if ok2 and typeof(model) == "Instance" then
            objects = { model }
        else
            return nil, "GetObjects: " .. err1 .. " | LoadAsset: " .. tostring(model)
        end
    end

    local bytes = fetchAssetBytes(id)
    local stats
    if bytes then
        stats = restoreScripts(objects, bytes, "Toolbox_" .. tostring(id))
    else
        stats = EMPTY_STATS("file asli tidak bisa diunduh")
    end

    return objects, nil, stats
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

        -- Logging untuk debugging di console
        print("[Punakawan] Scan selesai. Model:", modelCount, "Audio:", audioCount)
        local shown = 0
        for path in pairs(modelFiles) do
            if shown < 5 then
                print("[Punakawan]   model:", path, "-> resolvable:", findFile(path) ~= nil)
                shown = shown + 1
            end
        end

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

    local resolved = findFile(path)
    if not resolved then
        setStatus("ERROR: file tidak ditemukan: " .. path)
        return
    end

    importing = true
    local isPlace = PLACE_EXT[getExtension(path)] == true
    setStatus(isPlace and "Membaca file place, file besar butuh waktu..." or "Membaca file model...")

    task.spawn(function()
        local objects, err, stats = loadFile(resolved)

        if not objects then
            setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local _, message = importObjects(objects, isPlace, baseNameOf(path))
            local extra = describeScripts(stats)

            if runScriptsEnabled and stats and #stats.list > 0 then
                extra = extra .. " | " .. runScripts(stats.list) .. " dijalankan"
            end

            setStatus(message .. extra)
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
        local objects, err, stats = loadToolboxAsset(id)

        if not objects then
            setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local _, message = importObjects(objects, false, "Toolbox_" .. tostring(id))
            local extra = describeScripts(stats)

            if runScriptsEnabled and stats and #stats.list > 0 then
                extra = extra .. " | " .. runScripts(stats.list) .. " dijalankan"
            end

            setStatus(message .. extra)
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
    clearAudio()
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
if not readfileAPI then table.insert(missing, "readfile") end

if #missing > 0 then
    setStatus("API tidak tersedia: " .. table.concat(missing, ", "))
else
    setStatus("Siap. Tekan SCAN FILE untuk mencari model & lagu.")
end

print("======================================")
print("PUNAKAWAN COMMUNITY IMPORTER v5.1 FIXED")
print("listfiles:", listfilesAPI ~= nil)
print("isfile:", isfileAPI ~= nil)
print("getcustomasset:", getcustomassetAPI ~= nil)
print("request:", requestAPI ~= nil)
print("readfile:", readfileAPI ~= nil, "| writefile:", writefileAPI ~= nil)
print("logo image:", logoImage ~= nil, "| bg image:", bgImage ~= nil)
print("======================================")
