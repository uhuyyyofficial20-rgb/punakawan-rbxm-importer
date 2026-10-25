--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER v5.5 (PATCHED CORE - ZERO CACHE)
--==============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

--========================= CONFIG =============================
local SPAWN_POSITION = Vector3.new(0, 0.5, 0)
local USE_SPAWNLOCATION = false
local STACK_ON_PREVIOUS = false
local ROOT_PATHS = { "", ".", "workspace", "Workspace" }
local MAX_DEPTH = 20
local RUN_SCRIPTS_DEFAULT = true
local EXPORT_SCRIPT_FILES = true
local SCRIPT_EXPORT_FOLDER = "PunawakanScripts"

local API_HOSTS = { "apis.roblox.com", "apis.roproxy.com" }
local THUMB_HOSTS = { "thumbnails.roblox.com", "thumbnails.roproxy.com" }

local GUI_SCALE = Vector2.new(0.62, 0.9)
local GUI_MIN = Vector2.new(370, 340)
local GUI_MAX = Vector2.new(480, 560)
local RGB_SPEED = 0.2
local TOOLBOX_CATEGORY = 10

local LOGO_FILE = "punakawan_logo.png"
local LOGO_ASSET_ID = ""
local BG_FILE = "punawakan_bg.png"
local BG_ASSET_ID = ""

local MODEL_EXT = { rbxm = true, rbxmx = true, rbxl = true, rbxlx = true }
local PLACE_EXT = { rbxl = true, rbxlx = true }
local AUDIO_EXT = { mp3 = true, ogg = true, wav = true, flac = true }

--========================= EXECUTOR API ========================
local function getAPI(name)
    local ok, v = pcall(function() return getgenv()[name] end)
    if ok and typeof(v) == "function" then return v end
    ok, v = pcall(function() return _G[name] end)
    if ok and typeof(v) == "function" then return v end
    ok, v = pcall(function() return getfenv()[name] end)
    if ok and typeof(v) == "function" then return v end
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

--========================= UTIL ===============================
local function normalizePath(path)
    local p = tostring(path)
    p = p:gsub("\\", "/"):gsub("/+", "/"):gsub("/$", "")
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

local function fileVariants(path)
    local p = normalizePath(path)
    local list, seen = {}, {}
    local function add(v)
        if v and v ~= "" and not seen[v] then seen[v] = true; list[#list + 1] = v end
    end
    add(p)
    local stripped = p:gsub("^%.?/", ""); if stripped ~= p then add(stripped) end
    local noWs = stripped:gsub("^[Ww]orkspace/", ""); if noWs ~= stripped then add(noWs); add("./" .. noWs) end
    local lower = string.lower(p); local wsPos = lower:find("/workspace/", 1, true)
    if wsPos then
        local rel = string.sub(p, wsPos + 11)
        add(rel); add("./" .. rel); add("workspace/" .. rel); add("Workspace/" .. rel)
    end
    local base = p:match("([^/\\]+)$"); if base and base ~= p then add(base); add("./" .. base) end
    local count = #list
    for i = 1, count do
        local v = list[i]
        if not v:match("^%.?/") and not v:match("^[Ww]orkspace/") and not v:match("^/") then
            add("./" .. v); add("workspace/" .. v); add("Workspace/" .. v)
        end
    end
    return list
end

local fileCache = {}
local function findFile(path, silent)
    if type(path) ~= "string" or path == "" then return nil end
    local cached = fileCache[path]
    if cached and cached ~= false then return cached end
    local variants = fileVariants(path)
    if getcustomassetAPI then
        for _, v in ipairs(variants) do
            local ok, url = pcall(getcustomassetAPI, v)
            if ok and type(url) == "string" and url ~= "" then fileCache[path] = v; return v end
        end
    end
    if isfileAPI then
        for _, v in ipairs(variants) do
            local ok, res = pcall(isfileAPI, v)
            if ok and res == true then fileCache[path] = v; return v end
        end
    end
    if readfileAPI then
        for _, v in ipairs(variants) do
            local ok, data = pcall(readfileAPI, v)
            if ok and type(data) == "string" and #data > 0 then fileCache[path] = v; return v end
        end
    end
    fileCache[path] = false
    return nil
end

local function folderExists(path)
    if isfolderAPI then local ok, res = pcall(isfolderAPI, path); if ok and res then return true end end
    return false
end

local function resolveImage(file, assetId)
    if assetId and assetId ~= "" then return assetId end
    if file and file ~= "" and getcustomassetAPI then
        local resolved = findFile(file, true)
        if resolved then
            local ok, url = pcall(getcustomassetAPI, resolved)
            if ok and type(url) == "string" and url ~= "" then return url end
        end
    end
    return nil
end

local logoImage = resolveImage(LOGO_FILE, LOGO_ASSET_ID)
local bgImage = resolveImage(BG_FILE, BG_ASSET_ID) or resolveImage("punakawan_bg.png", "")

--========================= PARSER =============================
local RbxParser
do
--@@PARSER_BEGIN
RbxParser = {}
RbxParser.yield = function() end
local sbyte, ssub, schar = string.byte, string.sub, string.char
local function u32(s, p) local a, b, c, d = sbyte(s, p, p + 3); return a + b * 256 + c * 65536 + d * 16777216 end
local yc = 0
local function tick(n) yc = yc + n; if yc > 400000 then yc = 0; RbxParser.yield() end end
local function lz4Decompress(src)
    local out, n = {}, 0
    local i, len = 1, #src
    while i <= len do
        local token = sbyte(src, i); i = i + 1
        local lit = math.floor(token / 16)
        if lit == 15 then local b; repeat b = sbyte(src, i); i = i + 1; lit = lit + b until b ~= 255 end
        for j = 0, lit - 1 do out[n + j + 1] = sbyte(src, i + j) end
        n = n + lit; i = i + lit; tick(lit)
        if i > len then break end
        local offset = sbyte(src, i) + sbyte(src, i + 1) * 256; i = i + 2
        local ml = token % 16
        if ml == 15 then local b; repeat b = sbyte(src, i); i = i + 1; ml = ml + b until b ~= 255 end
        ml = ml + 4
        local from = n - offset
        for j = 1, ml do out[n + j] = out[from + j] end
        n = n + ml; tick(ml)
    end
    local parts = {}
    for k = 1, n, 2048 do parts[#parts + 1] = schar(table.unpack(out, k, math.min(k + 2047, n))) end
    return table.concat(parts)
end
local function readIntArray(data, pos, count)
    local arr = {}
    for i = 0, count - 1 do
        local b0, b1, b2, b3 = sbyte(data, pos+i), sbyte(data, pos+count+i), sbyte(data, pos+2*count+i), sbyte(data, pos+3*count+i)
        local x = b0 * 16777216 + b1 * 65536 + b2 * 256 + b3
        arr[i + 1] = (x % 2 == 1) and -((x + 1) / 2) or (x / 2)
    end
    tick(count * 4)
    return arr, pos + count * 4
end
local function accumulate(arr) for i = 2, #arr do arr[i] = arr[i] + arr[i - 1] end; return arr end
local function readString(data, pos) local l = u32(data, pos); return ssub(data, pos + 4, pos + 3 + l), pos + 4 + l end
function RbxParser.parseBinary(data)
    if ssub(data, 1, 8) ~= "<roblox!" then return nil, "bukan biner RBXM" end
    local classes, inst, roots = {}, {}, {}
    local pos, len = 33, #data
    while pos + 15 <= len do
        local cname, comp, unc = ssub(data, pos, pos + 3), u32(data, pos + 4), u32(data, pos + 8)
        local start, chunk = pos + 16, nil
        if comp == 0 then chunk = ssub(data, start, start + unc - 1); pos = start + unc
        else
            local raw = ssub(data, start, start + comp - 1)
            if ssub(raw, 1, 4) == "\40\181\47\253" then return nil, "ZSTD_COMPRESSED" end
            chunk = lz4Decompress(raw); pos = start + comp
        end
        if cname == "INST" then
            local classId = u32(chunk, 1); local className, p = readString(chunk, 5); p = p + 1
            local count = u32(chunk, p); p = p + 4; local refs = readIntArray(chunk, p, count); accumulate(refs)
            classes[classId] = { name = className, refs = refs }
            for _, ref in ipairs(refs) do inst[ref] = { class = className, name = className, children = {} } end
        elseif cname == "PROP" then
            local classId = u32(chunk, 1); local propName, p = readString(chunk, 5); local typeId = sbyte(chunk, p); p = p + 1
            local cls = classes[classId]
            if cls and typeId == 1 then
                local isName = (propName == "Name")
                local isSource = (propName == "Source") and string.find(cls.name, "Script", 1, true) ~= nil
                if isName or isSource then
                    for _, ref in ipairs(cls.refs) do
                        local str; str, p = readString(chunk, p); local node = inst[ref]
                        if node then if isName then node.name = str else node.source = str end end
                    end
                end
            end
        elseif cname == "PRNT" then
            local count = u32(chunk, 2); local p = 6; local cr, pr
            cr, p = readIntArray(chunk, p, count); accumulate(cr)
            pr, p = readIntArray(chunk, p, count); accumulate(pr)
            for i = 1, count do
                local child = inst[cr[i]]; local pref = pr[i]
                if child then
                    if pref == -1 then roots[#roots + 1] = child
                    else local parent = inst[pref]; if parent then parent.children[#parent.children + 1] = child end end
                end
            end
        elseif cname == "END\0" then break end
    end
    return roots
end
local function unescapeXml(s) s = s:gsub("&#(%d+);", function(n) return utf8.char(tonumber(n)) end); return (s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&")) end
local function xmlContent(raw) if string.find(raw, "<![CDATA[", 1, true) then local parts = {}; for piece in string.gmatch(raw, "<!%[CDATA%[(.-)%]%]>") do parts[#parts + 1] = piece end; return table.concat(parts) end; return unescapeXml(raw) end
function RbxParser.parseXml(xml)
    local roots, stack = {}, {}; local pos, len = 1, #xml; local steps = 0
    while true do
        local lt = string.find(xml, "<", pos, true); if not lt then break end
        steps = steps + 1; if steps % 20000 == 0 then RbxParser.yield() end
        if ssub(xml, lt, lt + 3) == "<!--" then local e = string.find(xml, "-->", lt, true); pos = (e or len) + 3
        elseif ssub(xml, lt, lt + 8) == "<![CDATA[" then local e = string.find(xml, "]]>", lt, true); pos = (e or len) + 3
        else
            local gt = string.find(xml, ">", lt, true); if not gt then break end
            local tag = ssub(xml, lt + 1, gt - 1); local selfClosing = ssub(tag, -1) == "/"; pos = gt + 1
            if ssub(tag, 1, 5) == "Item " then
                local class = string.match(tag, 'class="([^"]*)"') or "Instance"
                local node = { class = class, name = class, children = {} }; local top = stack[#stack]
                if top then top.children[#top.children + 1] = node else roots[#roots + 1] = node end
                if not selfClosing then stack[#stack + 1] = node end
            elseif tag == "/Item" then stack[#stack] = nil
            elseif not selfClosing and #stack > 0 then
                local closeTag, isName, isSource
                isName = string.match(tag, '^string name="Name"') ~= nil
                isSource = string.match(tag, '^ProtectedString name="Source"') ~= nil or string.match(tag, '^string name="Source"') ~= nil
                if isName then closeTag = "</string>"
                elseif isSource then closeTag = string.match(tag, "^ProtectedString") and "</ProtectedString>" or "</string>" end
                if closeTag then
                    local e = string.find(xml, closeTag, pos, true)
                    if e then
                        local content = xmlContent(ssub(xml, pos, e - 1)); local top = stack[#stack]
                        if isName then top.name = content elseif string.find(top.class, "Script", 1, true) then top.source = content end
                        pos = e + #closeTag
                    end
                end
            end
        end
    end
    return roots
end
function RbxParser.parse(data)
    if type(data) ~= "string" or #data < 16 then return nil, "isi kosong" end
    if ssub(data, 1, 8) == "<roblox!" then return RbxParser.parseBinary(data) end
    if string.find(ssub(data, 1, 200), "<roblox", 1, true) then return RbxParser.parseXml(data) end
    return nil, "format tidak dikenali"
end
function RbxParser.countScripts(nodes)
    local n = 0
    for _, node in ipairs(nodes) do if node.source ~= nil then n = n + 1 end; n = n + RbxParser.countScripts(node.children) end
    return n
end
local function matchLevel(liveList, parsedList, cb, path)
    local groups = {}
    for _, p in ipairs(parsedList) do
        local k = p.class .. "\0" .. p.name; local g = groups[k]
        if not g then g = { i = 0 }; groups[k] = g end
        g[#g + 1] = p
    end
    for _, live in ipairs(liveList) do
        local k = live.ClassName .. "\0" .. live.Name; local g = groups[k]
        if g then
            g.i = g.i + 1; local p = g[g.i]
            if p then local ppath = path .. "/" .. live.Name; cb(live, p, ppath); matchLevel(live:GetChildren(), p.children, cb, ppath) end
        end
    end
end
function RbxParser.match(liveRoots, parsedRoots, cb)
    local live = {}
    for _, o in ipairs(liveRoots) do
        if o.ClassName == "DataModel" then for _, c in ipairs(o:GetChildren()) do live[#live + 1] = c end
        else live[#live + 1] = o end
    end
    local hits = 0
    local function counting(l, p, path) if p.source ~= nil then hits = hits + 1 end; cb(l, p, path) end
    matchLevel(live, parsedRoots, counting, "")
    if hits == 0 then
        local flat = {}
        for _, r in ipairs(parsedRoots) do for _, c in ipairs(r.children) do flat[#flat + 1] = c end end
        matchLevel(live, flat, counting, "")
    end
    return hits
end
--@@PARSER_END
end
RbxParser.yield = function() task.wait() end

--========================= THEME ==============================
local THEME = {
    bg = Color3.fromRGB(13, 13, 20), header = Color3.fromRGB(19, 19, 29), panel = Color3.fromRGB(23, 23, 35),
    item = Color3.fromRGB(33, 33, 49), itemSelected = Color3.fromRGB(74, 60, 150), button = Color3.fromRGB(37, 37, 55),
    text = Color3.fromRGB(238, 238, 248), muted = Color3.fromRGB(150, 150, 176), scrim = Color3.fromRGB(6, 6, 10),
}
local panelTransparency = bgImage and 0.35 or 0.7
local rgbGradients = {}
local function buildRainbow(shift)
    local kp = {}
    for i = 0, 6 do kp[#kp + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6 + shift) % 1, 0.85, 1)) end
    return ColorSequence.new(kp)
end
local function addRGB(parent) local g = Instance.new("UIGradient"); g.Color = buildRainbow(0); g.Parent = parent; table.insert(rgbGradients, g); return g end
local function rgbStroke(inst, thickness, transparency)
    local s = Instance.new("UIStroke"); s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Color = Color3.new(1, 1, 1)
    s.Thickness = thickness or 1.5; s.Transparency = transparency or 0; s.Parent = inst; addRGB(s); return s
end

--========================= GUI BASE ===========================
local function applyTextShadow(inst)
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        inst.TextStrokeColor3 = Color3.new(0, 0, 0); inst.TextStrokeTransparency = bgImage and 0.15 or 0.45
    end
end
local guiParent = PlayerGui
if gethuiAPI then local ok, hui = pcall(gethuiAPI); if ok and typeof(hui) == "Instance" then guiParent = hui end end
for _, container in ipairs({ PlayerGui, guiParent }) do
    local old = container:FindFirstChild("PunawakanCommunityImporter"); if old then old:Destroy() end
end
for _, name in ipairs({ "PunawakanMusic", "PunawakanAudio", "PunawakanOut", "PunawakanWire" }) do
    local old = SoundService:FindFirstChild(name); if old then old:Destroy() end
end

local connections = {}
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PunawakanCommunityImporter"; ScreenGui.ResetOnSpawn = false; ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999; ScreenGui.Parent = guiParent

local function corner(inst, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = inst; return c end

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"; OpenButton.Size = UDim2.fromOffset(54, 54); OpenButton.Position = UDim2.new(0, 15, 0.5, -27)
OpenButton.AutoButtonColor = false; OpenButton.BackgroundColor3 = THEME.bg; OpenButton.BackgroundTransparency = 0.3; OpenButton.Text = ""; OpenButton.Parent = ScreenGui
corner(OpenButton, 12); rgbStroke(OpenButton, 2, 0.1)

if logoImage then
    local logo = Instance.new("ImageLabel"); logo.Name = "Logo"; logo.Size = UDim2.fromScale(1, 1); logo.BackgroundTransparency = 1
    logo.Image = logoImage; logo.ScaleType = Enum.ScaleType.Fit; logo.Parent = OpenButton; corner(logo, 12)
else
    OpenButton.Text = "P"; OpenButton.TextColor3 = Color3.new(1, 1, 1); OpenButton.TextSize = 26; OpenButton.Font = Enum.Font.GothamBold
end

local Main = Instance.new("Frame")
Main.Name = "Main"; Main.AnchorPoint = Vector2.new(0.5, 0.5); Main.Position = UDim2.fromScale(0.5, 0.5)
Main.Size = UDim2.fromScale(GUI_SCALE.X, GUI_SCALE.Y); Main.BackgroundColor3 = THEME.bg
Main.BackgroundTransparency = bgImage and 1 or 0.6; Main.BorderSizePixel = 0; Main.Visible = false; Main.Parent = ScreenGui
corner(Main, 14); rgbStroke(Main, 2.5, 0)

local sizeLimit = Instance.new("UISizeConstraint"); sizeLimit.MinSize = GUI_MIN; sizeLimit.MaxSize = GUI_MAX; sizeLimit.Parent = Main

if bgImage then
    local bg = Instance.new("ImageLabel"); bg.Name = "Background"; bg.Size = UDim2.fromScale(1, 1); bg.BackgroundTransparency = 1
    bg.Image = bgImage; bg.ScaleType = Enum.ScaleType.Crop; bg.ZIndex = 0; bg.Parent = Main; corner(bg, 14)
    local scrim = Instance.new("Frame"); scrim.Size = UDim2.fromScale(1, 1); scrim.BackgroundColor3 = THEME.scrim
    scrim.BackgroundTransparency = 0.35; scrim.BorderSizePixel = 0; scrim.ZIndex = 0; scrim.Parent = Main; corner(scrim, 14)
end

local Header = Instance.new("Frame")
Header.Name = "Header"; Header.Size = UDim2.new(1, 0, 0, 44); Header.BackgroundColor3 = THEME.header
Header.BackgroundTransparency = bgImage and 0.25 or 0.65; Header.BorderSizePixel = 0; Header.ZIndex = 2; Header.Parent = Main
corner(Header, 14)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 1, 0); Title.Position = UDim2.fromOffset(14, 0); Title.BackgroundTransparency = 1
Title.Text = "PUNAKAWAN COMMUNITY"; Title.TextColor3 = Color3.new(1, 1, 1); Title.TextSize = 15; Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left; Title.ZIndex = 3; Title.Parent = Header; addRGB(Title)

local Minimize = Instance.new("TextButton")
Minimize.Size = UDim2.fromOffset(34, 34); Minimize.Position = UDim2.new(1, -76, 0, 5); Minimize.BackgroundTransparency = 1
Minimize.Text = "-"; Minimize.TextColor3 = THEME.text; Minimize.TextSize = 24; Minimize.Font = Enum.Font.GothamBold
Minimize.ZIndex = 3; Minimize.Parent = Header

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(34, 34); Close.Position = UDim2.new(1, -40, 0, 5); Close.BackgroundTransparency = 1
Close.Text = "X"; Close.TextColor3 = THEME.text; Close.TextSize = 17; Close.Font = Enum.Font.GothamBold
Close.ZIndex = 3; Close.Parent = Header

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, -28, 0, 2); HeaderLine.Position = UDim2.fromOffset(14, 44); HeaderLine.BackgroundColor3 = Color3.new(1, 1, 1)
HeaderLine.BorderSizePixel = 0; HeaderLine.ZIndex = 3; HeaderLine.Parent = Main; addRGB(HeaderLine)

local TabBar = Instance.new("Frame")
TabBar.Position = UDim2.fromOffset(10, 52); TabBar.Size = UDim2.new(1, -20, 0, 30); TabBar.BackgroundTransparency = 1
TabBar.ZIndex = 2; TabBar.Parent = Main

local tabButtons, tabLines, pages = {}, {}, {}
local TAB_DEFS = { { "model", "MODEL" }, { "music", "LAGU" }, { "toolbox", "TOOLBOX" } }

local function switchTab(name)
    for k, p in pairs(pages) do p.Visible = (k == name) end
    for k, b in pairs(tabButtons) do b.TextColor3 = (k == name) and THEME.text or THEME.muted; tabLines[k].Visible = (k == name) end
end

for i, def in ipairs(TAB_DEFS) do
    local key, label = def[1], def[2]
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1 / #TAB_DEFS, -4, 1, 0); button.Position = UDim2.new((i - 1) / #TAB_DEFS, 2, 0, 0)
    button.BackgroundTransparency = 1; button.Text = label; button.TextSize = 13; button.Font = Enum.Font.GothamBold
    button.TextColor3 = THEME.muted; button.ZIndex = 3; button.Parent = TabBar
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2); line.Position = UDim2.new(0, 0, 1, -2); line.BackgroundColor3 = Color3.new(1, 1, 1)
    line.BorderSizePixel = 0; line.Visible = false; line.ZIndex = 3; line.Parent = button; addRGB(line)
    tabButtons[key] = button; tabLines[key] = line; button.Activated:Connect(function() switchTab(key) end)
end

local PagesHolder = Instance.new("Frame")
PagesHolder.Position = UDim2.fromOffset(10, 90); PagesHolder.Size = UDim2.new(1, -20, 1, -128); PagesHolder.BackgroundTransparency = 1
PagesHolder.ZIndex = 2; PagesHolder.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 30); Status.Position = UDim2.new(0, 10, 1, -34); Status.BackgroundTransparency = 1
Status.Text = "Siap."; Status.TextColor3 = THEME.muted; Status.TextSize = 10; Status.Font = Enum.Font.Gotham
Status.TextWrapped = true; Status.TextXAlignment = Enum.TextXAlignment.Left; Status.TextYAlignment = Enum.TextYAlignment.Center
Status.ZIndex = 3; Status.Parent = Main

local function setStatus(text) Status.Text = tostring(text) end
local function newPage(key)
    local f = Instance.new("Frame"); f.Name = key; f.BackgroundTransparency = 1; f.Size = UDim2.fromScale(1, 1)
    f.Visible = false; f.ZIndex = 2; f.Parent = PagesHolder; pages[key] = f; return f
end
local function makeButton(parent, text, pos, size, primary)
    local b = Instance.new("TextButton"); b.Position = pos; b.Size = size; b.AutoButtonColor = true
    b.BackgroundColor3 = THEME.button; b.BackgroundTransparency = math.max(panelTransparency - 0.1, 0)
    b.Text = text; b.TextColor3 = THEME.text; b.TextSize = 12; b.Font = Enum.Font.GothamBold
    b.ZIndex = 3; b.Parent = parent; corner(b, 8); rgbStroke(b, 1.5, primary and 0.1 or 0.4); return b
end
local function makeBox(parent, placeholder, pos, size)
    local box = Instance.new("TextBox"); box.Position = pos; box.Size = size; box.BackgroundColor3 = THEME.panel
    box.BackgroundTransparency = math.max(panelTransparency - 0.05, 0.15); box.TextColor3 = THEME.text
    box.PlaceholderColor3 = THEME.muted; box.PlaceholderText = placeholder; box.Text = ""; box.ClearTextOnFocus = false
    box.TextSize = 13; box.Font = Enum.Font.Gotham; box.TextXAlignment = Enum.TextXAlignment.Left
    box.ZIndex = 3; box.Parent = parent; corner(box, 8); rgbStroke(box, 1, 0.5)
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10); pad.Parent = box
    return box
end
local function newList(parent, pos, size, onSelect)
    local frame = Instance.new("ScrollingFrame"); frame.Position = pos; frame.Size = size; frame.BackgroundColor3 = THEME.panel
    frame.BackgroundTransparency = math.max(panelTransparency - 0.05, 0.1); frame.BorderSizePixel = 0; frame.ScrollBarThickness = 4
    frame.CanvasSize = UDim2.new(); frame.ZIndex = 3; frame.Parent = parent; corner(frame, 8); rgbStroke(frame, 1, 0.5)
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 5); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = frame
    local padding = Instance.new("UIPadding"); padding.PaddingTop = UDim.new(0, 6); padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 6); padding.PaddingRight = UDim.new(0, 6); padding.Parent = frame
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() frame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12) end)
    local ctl = { frame = frame, buttons = {}, selectedButton = nil, selected = nil }
    function ctl.clear() for _, b in ipairs(ctl.buttons) do b:Destroy() end; ctl.buttons = {}; ctl.selectedButton = nil; ctl.selected = nil; frame.CanvasPosition = Vector2.zero end
    function ctl.add(entry)
        local button = Instance.new("TextButton"); button.Size = UDim2.new(1, -4, 0, 42); button.LayoutOrder = #ctl.buttons + 1
        button.AutoButtonColor = false; button.BackgroundColor3 = THEME.item; button.BackgroundTransparency = 0.45
        button.TextColor3 = THEME.text; button.TextSize = 11; button.Font = Enum.Font.Gotham; button.TextWrapped = true
        button.TextXAlignment = Enum.TextXAlignment.Left; button.Text = "  " .. entry.text; button.ZIndex = 4
        applyTextShadow(button); button.Parent = frame; corner(button, 7); table.insert(ctl.buttons, button)
        local function choose()
            if ctl.selectedButton then ctl.selectedButton.BackgroundColor3 = THEME.item end
            ctl.selectedButton = button; ctl.selected = entry.value; button.BackgroundColor3 = THEME.itemSelected; onSelect(entry)
        end
        button.Activated:Connect(choose); return choose
    end
    function ctl.set(entries) ctl.clear(); for _, e in ipairs(entries) do ctl.add(e) end end
    return ctl
end
local function newGrid(parent, pos, size, onSelect, onNearEnd)
    local frame = Instance.new("ScrollingFrame"); frame.Position = pos; frame.Size = size; frame.BackgroundColor3 = THEME.panel
    frame.BackgroundTransparency = math.max(panelTransparency - 0.05, 0.1); frame.BorderSizePixel = 0; frame.ScrollBarThickness = 4
    frame.CanvasSize = UDim2.new(); frame.ZIndex = 3; frame.Parent = parent; corner(frame, 8); rgbStroke(frame, 1, 0.5)
    local grid = Instance.new("UIGridLayout"); grid.CellSize = UDim2.new(0.3, 0, 0, 128); grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center; grid.SortOrder = Enum.SortOrder.LayoutOrder; grid.Parent = frame
    local padding = Instance.new("UIPadding"); padding.PaddingTop = UDim.new(0, 6); padding.PaddingBottom = UDim.new(0, 6)
    padding.PaddingLeft = UDim.new(0, 4); padding.PaddingRight = UDim.new(0, 4); padding.Parent = frame
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() frame.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 12) end)
    local ctl = { frame = frame, cells = {}, selectedCell = nil, selected = nil }
    function ctl.clear() for _, c in ipairs(ctl.cells) do c.button:Destroy() end; ctl.cells = {}; ctl.selectedCell = nil; ctl.selected = nil; frame.CanvasPosition = Vector2.zero end
    function ctl.add(entry)
        local button = Instance.new("TextButton"); button.Text = ""; button.AutoButtonColor = false
        button.BackgroundColor3 = THEME.item; button.BackgroundTransparency = 0.25; button.LayoutOrder = #ctl.cells + 1
        button.ZIndex = 4; button.Parent = frame; corner(button, 8)
        local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(150, 120, 255); stroke.Transparency = 1; stroke.Parent = button
        local img = Instance.new("ImageLabel"); img.BackgroundTransparency = 1; img.Position = UDim2.fromOffset(4, 4); img.Size = UDim2.new(1, -8, 1, -40)
        img.ScaleType = Enum.ScaleType.Fit; img.Image = entry.thumb or ""; img.ZIndex = 5; img.Parent = button; corner(img, 6)
        local label = Instance.new("TextLabel"); label.BackgroundTransparency = 1; label.Position = UDim2.new(0, 4, 1, -34)
        label.Size = UDim2.new(1, -8, 0, 32); label.Text = entry.text; label.TextColor3 = THEME.text; label.TextSize = 10
        label.Font = Enum.Font.Gotham; label.TextWrapped = true; label.TextTruncate = Enum.TextTruncate.AtEnd
        label.TextYAlignment = Enum.TextYAlignment.Top; label.ZIndex = 5; label.Parent = button; applyTextShadow(label)
        local cell = { button = button, stroke = stroke, img = img }; table.insert(ctl.cells, cell)
        local function choose()
            if ctl.selectedCell then ctl.selectedCell.stroke.Transparency = 1; ctl.selectedCell.button.BackgroundColor3 = THEME.item end
            ctl.selectedCell = cell; ctl.selected = entry.value; stroke.Transparency = 0; button.BackgroundColor3 = THEME.itemSelected; onSelect(entry)
        end
        button.Activated:Connect(choose); return choose, cell
    end
    frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        if onNearEnd and frame.AbsoluteCanvasSize.Y > 0 and frame.CanvasPosition.Y + frame.AbsoluteWindowSize.Y >= frame.AbsoluteCanvasSize.Y - 80 then onNearEnd() end
    end)
    return ctl
end

table.insert(connections, RunService.RenderStepped:Connect(function()
    local seq = buildRainbow((os.clock() * RGB_SPEED) % 1)
    for i = #rgbGradients, 1, -1 do local g = rgbGradients[i]; if g.Parent then g.Color = seq else table.remove(rgbGradients, i) end end
end))

do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Main.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

--======================= SPAWN PLACEMENT ======================
local importedModels = {}
local function collectSpawns()
    local t = {}; for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("SpawnLocation") then t[#t + 1] = d end end; return t
end
local function placeAtSpawn(model)
    local spawns = collectSpawns(); local sp = SPAWN_POSITION
    if USE_SPAWNLOCATION and #spawns > 0 then sp = spawns[1].Position end
    local boxCF, boxSize = model:GetBoundingBox(); local groundY
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate and baseplate:IsA("BasePart") then
        local rel = baseplate.CFrame:PointToObjectSpace(sp)
        if math.abs(rel.X) <= baseplate.Size.X / 2 and math.abs(rel.Z) <= baseplate.Size.Z / 2 then groundY = baseplate.Position.Y + baseplate.Size.Y / 2 end
    end
    if not groundY then
        local exclude = {}; if Player.Character then table.insert(exclude, Player.Character) end
        for _, s in ipairs(spawns) do table.insert(exclude, s) end
        if not STACK_ON_PREVIOUS then for i = #importedModels, 1, -1 do if importedModels[i].Parent then table.insert(exclude, importedModels[i]) else table.remove(importedModels, i) end end end
        local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = exclude
        local result = workspace:Raycast(Vector3.new(sp.X, sp.Y + 500, sp.Z), Vector3.new(0, -1500, 0), params)
        if result then groundY = result.Position.Y end
    end
    if not groundY then groundY = sp.Y - 0.5 end
    local halfH = 0.5 * (math.abs(boxCF.RightVector.Y) * boxSize.X + math.abs(boxCF.UpVector.Y) * boxSize.Y + math.abs(boxCF.LookVector.Y) * boxSize.Z)
    local d = Vector3.new(sp.X - boxCF.Position.X, (groundY + halfH) - boxCF.Position.Y, sp.Z - boxCF.Position.Z)
    model:PivotTo(model:GetPivot() + d)
end

--======================= IMPORT OBJECTS (PATCHED RS) ==========
local SERVICE_NAMES = {
    Lighting = true, ServerScriptService = true, ServerStorage = true, ReplicatedStorage = true, ReplicatedFirst = true,
    StarterGui = true, StarterPack = true, StarterPlayer = true, SoundService = true, Teams = true, Chat = true, TextChatService = true, MaterialService = true,
}
local function mergeIntoLocalService(serviceObj, report)
    local okS, realS = pcall(function() return game:GetService(serviceObj.ClassName) end)
    local children = serviceObj:GetChildren()
    if not okS or not realS then report.failed += #children; return end
    for _, child in ipairs(children) do
        if serviceObj.ClassName == "StarterGui" and child:IsA("LayerCollector") then pcall(function() child:Clone().Parent = PlayerGui end) end
        local ok = pcall(function() child.Parent = realS end)
        if ok and child.Parent == realS then report.services += 1 else report.failed += 1 end
    end
end
local function collectImportables(objects, report)
    local list = {}
    for _, obj in ipairs(objects) do
        if typeof(obj) == "Instance" then
            if obj.ClassName == "DataModel" then
                for _, s in ipairs(obj:GetChildren()) do
                    if s.ClassName == "Workspace" then
                        for _, c in ipairs(s:GetChildren()) do list[#list + 1] = c end
                    elseif s.ClassName == "ReplicatedStorage" then
                        -- [PATCH] SOLUSI INFINITE YIELD: Salin isi ReplicatedStorage langsung ke game
                        local realRS = game:GetService("ReplicatedStorage")
                        for _, child in ipairs(s:GetChildren()) do
                            pcall(function() 
                                if not realRS:FindFirstChild(child.Name) then
                                    local clone = child:Clone()
                                    clone.Parent = realRS 
                                end
                            end)
                        end
                        list[#list + 1] = s
                    else mergeIntoLocalService(s, report) end
                end
            elseif obj.ClassName == "Workspace" then
                for _, c in ipairs(obj:GetChildren()) do list[#list + 1] = c end
            elseif obj.ClassName == "ReplicatedStorage" then
                -- [PATCH] SOLUSI INFINITE YIELD
                local realRS = game:GetService("ReplicatedStorage")
                for _, child in ipairs(obj:GetChildren()) do
                    pcall(function() 
                        if not realRS:FindFirstChild(child.Name) then
                            local clone = child:Clone()
                            clone.Parent = realRS 
                        end
                    end)
                end
                list[#list + 1] = obj
            elseif SERVICE_NAMES[obj.ClassName] then mergeIntoLocalService(obj, report)
            else list[#list + 1] = obj end
        end
    end
    return list
end
local function wrapObjects(items, name, report)
    local container = Instance.new("Model"); container.Name = name
    for _, item in ipairs(items) do
        if item:IsA("LayerCollector") then
            local ok = pcall(function() item.Parent = PlayerGui end)
            if ok and item.Parent == PlayerGui then report.gui += 1 else report.failed += 1 end
        else
            local ok = pcall(function() item.Parent = container end)
            if not ok or item.Parent ~= container then report.failed += 1 end
        end
    end
    return container
end
local function importObjects(objects, isPlace, baseName)
    local report = { services = 0, failed = 0, gui = 0 }
    local items = collectImportables(objects, report)
    local target
    if #items == 1 and items[1]:IsA("Model") and not isPlace then target = items[1]
    elseif #items > 0 then target = wrapObjects(items, "Import_" .. baseName, report) end
    local placed, placeNote = 0, ""
    if target and (#target:GetChildren() > 0 or (target:IsA("Model") and #items == 1)) then
        local ok, err = pcall(placeAtSpawn, target)
        target.Parent = workspace; table.insert(importedModels, target); placed = #items
        if not ok then placeNote = " | gagal posisi: " .. tostring(err) end
    elseif target then target:Destroy() end
    if placed == 0 and report.services == 0 and report.gui == 0 then return false, "Tidak ada objek.", nil end
    local parts = {}
    if placed > 0 then parts[#parts + 1] = placed .. " objek" end
    if report.services > 0 then parts[#parts + 1] = report.services .. " ke service" end
    if report.gui > 0 then parts[#parts + 1] = report.gui .. " GUI" end
    local msg = "BERHASIL: " .. table.concat(parts, ", ") .. "."
    if report.failed > 0 then msg = msg .. " | " .. report.failed .. " ditolak." end
    return true, msg .. placeNote, target
end

--======================= FILE SCANNER =========================
local modelFiles, audioFiles = {}, {}
local scanning = false
local function scanDirectory(folderPath, depth, visited, counter)
    if depth > MAX_DEPTH or not listfilesAPI then return end
    folderPath = normalizePath(folderPath); if visited[folderPath] then return end; visited[folderPath] = true
    local arg = folderPath ~= "" and folderPath or "."
    local ok, entries = pcall(listfilesAPI, arg)
    if not ok or type(entries) ~= "table" then if folderPath == "" then ok, entries = pcall(listfilesAPI, "") end; if not ok or type(entries) ~= "table" then return end end
    for _, entry in ipairs(entries) do
        local path = normalizePath(entry); local ext = getExtension(path)
        if MODEL_EXT[ext] then modelFiles[path] = true elseif AUDIO_EXT[ext] then audioFiles[path] = true
        elseif folderExists(path) then scanDirectory(path, depth + 1, visited, counter) end
        counter.n += 1; if counter.n % 25 == 0 then task.wait() end
    end
end

--======================= MODEL PAGE ===========================
local ModelPage = newPage("model")
local ModelSearch = makeBox(ModelPage, "Cari file RBXM / RBXL...", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32))
local ModelScan = makeButton(ModelPage, "SCAN FILE", UDim2.fromOffset(0, 38), UDim2.new(1 / 3, -3, 0, 32), true)
local ModelFilter = makeButton(ModelPage, "FILTER: ALL", UDim2.new(1 / 3, 1, 0, 38), UDim2.new(1 / 3, -2, 0, 32))
local ModelRun = makeButton(ModelPage, "RUN: ON", UDim2.new(2 / 3, 3, 0, 38), UDim2.new(1 / 3, -3, 0, 32))
local runScriptsEnabled = RUN_SCRIPTS_DEFAULT
local function refreshRunButton() ModelRun.Text = "RUN: " .. (runScriptsEnabled and "ON" or "OFF") end
ModelRun.Activated:Connect(function() runScriptsEnabled = not runScriptsEnabled; refreshRunButton(); setStatus(runScriptsEnabled and "RUN ON." or "RUN OFF.") end)
refreshRunButton()
local modelList = newList(ModelPage, UDim2.fromOffset(0, 76), UDim2.new(1, 0, 1, -122), function(e) setStatus("Dipilih: " .. e.value) end)
local ModelImport = makeButton(ModelPage, "IMPORT FILE TERPILIH", UDim2.new(0, 0, 1, -38), UDim2.new(1, 0, 0, 38), true)
local MODEL_FILTERS = { "ALL", "RBXM", "RBXMX", "RBXL", "RBXLX" }
local modelFilterIndex = 1
local function renderModels()
    local q = string.lower(ModelSearch.Text); local mode = MODEL_FILTERS[modelFilterIndex]; local paths = {}
    for path in pairs(modelFiles) do
        local ext = string.upper(getExtension(path))
        if (mode == "ALL" or ext == mode) and string.find(string.lower(path), q, 1, true) then paths[#paths + 1] = path end
    end
    table.sort(paths); local entries = {}
    for _, p in ipairs(paths) do entries[#entries + 1] = { text = p, value = p } end
    modelList.set(entries); return #entries
end

--======================= MUSIC PAGE ===========================
local MusicPage = newPage("music")
local MusicSearch = makeBox(MusicPage, "Cari lagu...", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32))
local MusicScan = makeButton(MusicPage, "SCAN LAGU", UDim2.fromOffset(0, 38), UDim2.new(0.5, -3, 0, 32), true)
local LoopButton = makeButton(MusicPage, "LOOP: OFF", UDim2.new(0.5, 3, 0, 38), UDim2.new(0.5, -3, 0, 32))
local songList = newList(MusicPage, UDim2.fromOffset(0, 76), UDim2.new(1, 0, 1, -156), function(e) setStatus("Lagu dipilih: " .. e.value) end)
local PlayButton = makeButton(MusicPage, "PLAY", UDim2.new(0, 0, 1, -74), UDim2.new(0.5, -3, 0, 34), true)
local StopButton = makeButton(MusicPage, "STOP", UDim2.new(0.5, 3, 1, -74), UDim2.new(0.5, -3, 0, 34))
local VolDown = makeButton(MusicPage, "VOL -", UDim2.new(0, 0, 1, -34), UDim2.new(0.3, -4, 0, 34))
local VolLabel = Instance.new("TextLabel")
VolLabel.Position = UDim2.new(0.3, 0, 1, -34); VolLabel.Size = UDim2.new(0.4, 0, 0, 34); VolLabel.BackgroundTransparency = 1
VolLabel.TextColor3 = THEME.text; VolLabel.TextSize = 12; VolLabel.Font = Enum.Font.GothamBold; VolLabel.Text = "VOLUME 50%"
VolLabel.ZIndex = 3; VolLabel.Parent = MusicPage
local VolUp = makeButton(MusicPage, "VOL +", UDim2.new(0.7, 4, 1, -34), UDim2.new(0.3, -4, 0, 34))

local Audio = { kind = nil, obj = nil, extra = {}, volume = 0.5, looped = false, path = nil, busy = false }
local function renderSongs()
    local q = string.lower(MusicSearch.Text); local paths = {}
    for path in pairs(audioFiles) do if string.find(string.lower(path), q, 1, true) then paths[#paths + 1] = path end end
    table.sort(paths); local entries = {}
    for _, p in ipairs(paths) do entries[#entries + 1] = { text = p, value = p } end
    songList.set(entries); return #entries
end
local function refreshVolume() VolLabel.Text = "VOLUME " .. math.floor(Audio.volume * 100 + 0.5) .. "%" end
local function audioIsPlaying() if not Audio.obj then return false end; local ok, v = pcall(function() return Audio.obj.IsPlaying end); return ok and v == true end
local function applyAudioSettings()
    if not Audio.obj then return end
    pcall(function() Audio.obj.Volume = Audio.volume end)
    pcall(function() if Audio.kind == "sound" then Audio.obj.Looped = Audio.looped else Audio.obj.Looping = Audio.looped end end)
end
local function clearAudio()
    if Audio.obj then pcall(function() Audio.obj:Stop() end); pcall(function() Audio.obj:Destroy() end) end
    for _, o in ipairs(Audio.extra) do pcall(function() o:Destroy() end) end
    Audio.obj = nil; Audio.extra = {}; Audio.kind = nil
end
local function trySound(url)
    local s = Instance.new("Sound"); s.Name = "PunawakanMusic"; s.Volume = Audio.volume; s.Looped = Audio.looped; s.SoundId = url; s.Parent = SoundService
    local t0 = os.clock(); while os.clock() - t0 < 8 and not (s.IsLoaded and s.TimeLength > 0) do task.wait(0.1) end
    if not (s.IsLoaded and s.TimeLength > 0) then s:Destroy(); return false, "tidak termuat" end
    s:Play(); task.wait(0.5); if s.IsPlaying then Audio.obj = s; Audio.kind = "sound"; return true end
    s:Destroy(); return false, "tidak berbunyi"
end
local function tryAudioPlayer(url)
    local created = {}
    local ok, err = pcall(function()
        local ap = Instance.new("AudioPlayer"); ap.Name = "PunawakanAudio"; ap.Volume = Audio.volume; ap.Looping = Audio.looped
        ap.Asset = url; ap.Parent = SoundService; created[#created + 1] = ap
        local out = Instance.new("AudioDeviceOutput"); out.Name = "PunawakanOut"; out.Parent = SoundService; created[#created + 1] = out
        local w = Instance.new("Wire"); w.Name = "PunawakanWire"; w.SourceInstance = ap; w.TargetInstance = out; w.Parent = SoundService; created[#created + 1] = w
    end)
    local function destroy() for _, o in ipairs(created) do pcall(function() o:Destroy() end) end end
    if not ok then destroy(); return false, tostring(err) end
    local ap = created[1]; local function ready() local okR, v = pcall(function() return ap.IsReady and ap.TimeLength > 0 end); return okR and v == true end
    local t0 = os.clock(); while os.clock() - t0 < 8 and not ready() do task.wait(0.1) end
    pcall(function() ap:Play() end); task.wait(0.5); local okP, playing = pcall(function() return ap.IsPlaying end)
    if okP and playing then Audio.obj = ap; Audio.kind = "audio"; Audio.extra = { created[2], created[3] }; return true end
    destroy(); return false, "tidak berbunyi"
end
local function loadAndPlay(path)
    if Audio.busy or not getcustomassetAPI then setStatus("ERROR: getcustomasset tidak tersedia"); return end
    local resolved = findFile(path); if not resolved then setStatus("ERROR: file lagu tidak ditemukan: " .. path); return end
    Audio.busy = true; clearAudio(); setStatus("Memuat lagu...")
    local reasons = {}
    local function attempt(url, label)
        local ok1, e1 = trySound(url); if ok1 then return true end; reasons[#reasons + 1] = label .. "/Sound: " .. tostring(e1)
        local ok2, e2 = tryAudioPlayer(url); if ok2 then return true end; reasons[#reasons + 1] = label .. "/AudioPlayer: " .. tostring(e2); return false
    end
    local okA, url = pcall(getcustomassetAPI, resolved); local done = false
    if okA and type(url) == "string" and url ~= "" then done = attempt(url, "asli") end
    if done then Audio.path = path; applyAudioSettings(); setStatus("Memutar: " .. baseNameOf(path) .. " (" .. tostring(Audio.kind) .. ")")
    else setStatus("GAGAL memutar."); for _, r in ipairs(reasons) do warn("[Punakawan] " .. r) end end
    Audio.busy = false
end
PlayButton.Activated:Connect(function()
    if Audio.busy then return end; local s = songList.selected
    if s and s ~= Audio.path then task.spawn(loadAndPlay, s)
    elseif Audio.obj then
        if audioIsPlaying() then pcall(function() Audio.obj:Pause() end)
        else pcall(function() if Audio.kind == "sound" and Audio.obj.IsPaused then Audio.obj:Resume() else Audio.obj:Play() end end) end
    else setStatus("Pilih lagu dulu.") end
end)
StopButton.Activated:Connect(function() if Audio.obj then pcall(function() Audio.obj:Stop() end) end; setStatus("Lagu dihentikan.") end)
LoopButton.Activated:Connect(function() Audio.looped = not Audio.looped; LoopButton.Text = "LOOP: " .. (Audio.looped and "ON" or "OFF"); applyAudioSettings() end)
VolDown.Activated:Connect(function() Audio.volume = math.max(0, math.floor(Audio.volume * 10 + 0.5) / 10 - 0.1); refreshVolume(); applyAudioSettings() end)
VolUp.Activated:Connect(function() Audio.volume = math.min(1, math.floor(Audio.volume * 10 + 0.5) / 10 + 0.1); refreshVolume(); applyAudioSettings() end)
task.spawn(function() while ScreenGui.Parent do PlayButton.Text = audioIsPlaying() and "PAUSE" or "PLAY"; task.wait(0.4) end end)

--======================= TOOLBOX PAGE =========================
local ToolboxPage = newPage("toolbox")
local ToolboxSearch = makeBox(ToolboxPage, "Cari model atau tempel Asset ID...", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 32))
local ToolboxGo = makeButton(ToolboxPage, "CARI", UDim2.fromOffset(0, 38), UDim2.new(0.5, -3, 0, 32), true)
local ToolboxMore = makeButton(ToolboxPage, "MUAT LAGI", UDim2.new(0.5, 3, 0, 38), UDim2.new(0.5, -3, 0, 32))
local ToolboxImport = makeButton(ToolboxPage, "IMPORT MODEL TERPILIH", UDim2.new(0, 0, 1, -38), UDim2.new(1, 0, 0, 38), true)

local tbKeyword, tbPage, tbBusy, tbEnd, tbStarted = "", 0, false, false, false
local runToolboxSearch
local toolboxList = newGrid(ToolboxPage, UDim2.fromOffset(0, 76), UDim2.new(1, 0, 1, -122), function(e)
    setStatus("Dipilih: " .. e.text .. " [" .. tostring(e.value) .. "]")
end, function() runToolboxSearch(true) end)

local function httpBody(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and body ~= "" then return body end
    if requestAPI then
        local ok2, res = pcall(requestAPI, { Url = url, Method = "GET", Headers = { ["Accept"] = "*/*" } })
        if ok2 and type(res) == "table" then
            local code = res.StatusCode or res.status_code; local b = res.Body or res.body; local succ = res.Success
            if succ == nil then succ = (type(code) ~= "number") or code < 400 end
            if succ and type(b) == "string" and b ~= "" then return b end
        end
    end
    return nil
end
local function httpJson(path)
    for index, host in ipairs(API_HOSTS) do
        local body = httpBody("https://" .. host .. path)
        if body then
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and type(data) == "table" then
                if index > 1 then table.remove(API_HOSTS, index); table.insert(API_HOSTS, 1, host) end
                return data
            end
        end
    end
    return nil, "server toolbox tidak bisa dijangkau"
end
local function fetchThumbnailURLs(ids)
    if #ids == 0 then return {} end; local idList = table.concat(ids, ",")
    for _, host in ipairs(THUMB_HOSTS) do
        local url = "https://" .. host .. "/v1/assets?assetIds=" .. idList .. "&size=150x150&format=Png&isCircular=false"
        local body = httpBody(url)
        if body then
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and type(data) == "table" and type(data.data) == "table" then
                local result = {}
                for _, item in ipairs(data.data) do
                    local tid = tonumber(item.targetId)
                    if tid and type(item.imageUrl) == "string" and item.imageUrl ~= "" and string.find(item.imageUrl, "http", 1, true) then result[tid] = item.imageUrl end
                end
                if next(result) then return result end
            end
        end
    end
    return {}
end

local MODEL_ICON = "rbxassetid://4458901886"
local THUMB_CACHE = "PunawakanThumbs"
local thumbnailURLCache, thumbURLsBatch = {}, {}
local function ensureThumbFolder() if makefolderAPI and not folderExists(THUMB_CACHE) then pcall(makefolderAPI, THUMB_CACHE) end end
local function resolveThumbnail(id, skipHttp)
    id = tonumber(id); if not id then return MODEL_ICON end
    if thumbnailURLCache[id] then return thumbnailURLCache[id] end
    if writefileAPI and getcustomassetAPI then
        local cachePath = THUMB_CACHE .. "/" .. id .. ".png"; local resolved = findFile(cachePath, true)
        if resolved then local ok, url = pcall(getcustomassetAPI, resolved); if ok and url then thumbnailURLCache[id] = url; return url end end
        if not skipHttp then
            local httpsURL = thumbURLsBatch[id]
            if not httpsURL then local urls = fetchThumbnailURLs({ id }); httpsURL = urls[id]; if httpsURL then thumbURLsBatch[id] = httpsURL end end
            if httpsURL then
                local body = httpBody(httpsURL)
                if body and #body > 500 then
                    ensureThumbFolder(); pcall(writefileAPI, cachePath, body); local resolved2 = findFile(cachePath, true)
                    if resolved2 then local ok2, url2 = pcall(getcustomassetAPI, resolved2); if ok2 and url2 then thumbnailURLCache[id] = url2; return url2 end end
                end
            end
        end
    end
    return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150"
end

local thumbQueue, thumbProcessing = {}, false
local function enqueueThumb(id, imgLabel)
    table.insert(thumbQueue, { id = id, img = imgLabel })
    if thumbProcessing then return end
    thumbProcessing = true
    task.spawn(function()
        while #thumbQueue > 0 do
            local item = table.remove(thumbQueue, 1)
            if item.img and item.img.Parent then
                local better = resolveThumbnail(item.id, false)
                if better and item.img.Parent then pcall(function() item.img.Image = better end) end
            end
            task.wait(0.15)
        end
        thumbProcessing = false
    end)
end

local function toolboxSearch(keyword, page)
    local data, err = httpJson(string.format("/toolbox-service/v1/marketplace/%d?limit=30&pageNumber=%d&keyword=%s", TOOLBOX_CATEGORY, page, HttpService:UrlEncode(keyword)))
    local results = {}
    if data and type(data.data) == "table" then
        local ids = {}
        for _, entry in ipairs(data.data) do local id = tonumber(entry.id or entry.assetId); if id then ids[#ids + 1] = id end end
        if #ids > 0 then
            local info = {}; local details = httpJson("/toolbox-service/v1/items/details?assetIds=" .. table.concat(ids, "%2C"))
            if type(details) == "table" and type(details.data) == "table" then
                for _, d in ipairs(details.data) do
                    local a = type(d.asset) == "table" and d.asset or d; local id = tonumber(a.id)
                    if id then info[id] = { name = a.name, creator = type(d.creator) == "table" and d.creator.name or nil } end
                end
            end
            for _, id in ipairs(ids) do local i = info[id] or {}; results[#results + 1] = { id = id, name = i.name or ("Asset " .. id), creator = i.creator } end
        end
        return results
    end
    local ok, pr = pcall(function() return InsertService:GetFreeModelsAsync(keyword, page) end)
    if ok and type(pr) == "table" and pr[1] and type(pr[1].Results) == "table" then
        for _, r in ipairs(pr[1].Results) do results[#results + 1] = { id = r.AssetId, name = r.Name, creator = r.CreatorName } end
        return results
    end
    return nil, err or "tidak ada hasil"
end

local function addToolboxResults(results)
    if #results == 0 then return end
    local ids = {}; for _, r in ipairs(results) do ids[#ids + 1] = r.id end
    local urlMap = fetchThumbnailURLs(ids); for id, url in pairs(urlMap) do thumbURLsBatch[id] = url end
    for _, r in ipairs(results) do
        local initialThumb = "rbxthumb://type=Asset&id=" .. tostring(r.id) .. "&w=150&h=150"
        local choose, cell = toolboxList.add({ text = tostring(r.name) .. (r.creator and ("\nby " .. tostring(r.creator)) or ""), value = r.id, thumb = initialThumb })
        enqueueThumb(r.id, cell.img)
    end
end

runToolboxSearch = function(append)
    if tbBusy then return end; local keyword
    if append then if not tbStarted or tbEnd then return end; keyword = tbKeyword
    else
        keyword = trim(ToolboxSearch.Text)
        if keyword:match("^%d+$") then
            tbStarted = false; toolboxList.clear(); local id = tonumber(keyword)
            local choose, cell = toolboxList.add({ text = "Asset ID " .. keyword, value = id, thumb = "rbxthumb://type=Asset&id=" .. keyword .. "&w=150&h=150" })
            enqueueThumb(id, cell.img); choose(); return
        end
    end
    tbBusy = true
    if append then tbPage = tbPage + 1 else tbKeyword = keyword; tbPage = 0; tbEnd = false; tbStarted = true; toolboxList.clear() end
    setStatus(keyword == "" and "Memuat..." or ("Mencari \"" .. keyword .. "\"..."))
    task.spawn(function()
        local results, err = toolboxSearch(tbKeyword, tbPage)
        if not results then if append then tbPage = tbPage - 1 end; setStatus("Pencarian gagal: " .. tostring(err))
        elseif #results == 0 then tbEnd = true; if append then tbPage = tbPage - 1; setStatus("Semua hasil sudah ditampilkan.") else setStatus("Tidak ada hasil.") end
        else addToolboxResults(results); setStatus("Halaman " .. (tbPage + 1) .. ": " .. #results .. " model.") end
        tbBusy = false
    end)
end

ToolboxGo.Activated:Connect(function() runToolboxSearch(false) end)
ToolboxMore.Activated:Connect(function() if not tbStarted then setStatus("Cari dulu."); return end; runToolboxSearch(true) end)
ToolboxSearch.FocusLost:Connect(function(enter) if enter then runToolboxSearch(false) end end)
local toolboxOpened = false
tabButtons.toolbox.Activated:Connect(function() if not toolboxOpened then toolboxOpened = true; runToolboxSearch(false) end end)

--======================= SCRIPT RECOVERY (PURE SOURCE) ========
local ScriptClasses = { Script = true, LocalScript = true, ModuleScript = true }
local ScriptRegistry = setmetatable({}, { __mode = "k" })
local moduleCache = setmetatable({}, { __mode = "k" })
local okEnv, BASE_ENV = pcall(function() return getfenv() end)
if not okEnv or type(BASE_ENV) ~= "table" then BASE_ENV = _G end

local function sanitizeName(s) local c = tostring(s):gsub("[^%w%._%- ]", "_"); if c == "" then c = "_" end; return c end

-- [PATCH] FUNGSI INJEKSI SOURCE (Bypass Read-Only & Kloning)
local function setScriptSource(inst, source)
    if not source or source == "" then return false end
    
    -- 1. Properti Source langsung
    local ok2 = pcall(function() inst.Source = source end)
    if ok2 then
        local checkOk, checkSrc = pcall(function() return inst.Source end)
        if checkOk and checkSrc == source then return true end
    end

    -- 2. API setscriptsource
    if setscriptsourceAPI then
        if pcall(setscriptsourceAPI, inst, source) then return true end
    end
    
    -- 3. sethiddenproperty
    if sethiddenpropertyAPI then
        if pcall(sethiddenpropertyAPI, inst, "Source", source) then return true end
    end

    -- 4. Trik Clone (Membuat instance baru untuk melepas Read Only)
    if inst.Parent ~= nil then
        local success = pcall(function()
            local clone = inst:Clone()
            if setscriptsourceAPI then pcall(setscriptsourceAPI, clone, source) end
            pcall(function() clone.Source = source end)
            local parent = inst.Parent
            local name = inst.Name
            inst:Destroy()
            clone.Name = name
            clone.Parent = parent
        end)
        if success then return true end
    end
    
    return false
end

local function exportScripts(label, items)
    -- [PATCH] Mematikan fitur ekspor agar tidak membuat folder PunawakanScripts
    return 0
end

local function restoreScripts(objects, bytes, label)
    local stats = { inFile = 0, matched = 0, setOK = 0, exported = 0, list = {}, err = nil, hint = nil }
    local okP, r1, r2 = pcall(RbxParser.parse, bytes); local parsed, perr
    if okP then parsed, perr = r1, r2 else perr = tostring(r1) end
    if not parsed then
        stats.err = perr or "gagal baca"
        if tostring(perr):find("ZSTD") then stats.hint = "ZSTD-compressed. Gunakan 'Save As' RBXM non-ZSTD." end
        return stats
    end
    stats.inFile = RbxParser.countScripts(parsed)
    if stats.inFile == 0 then return stats end
    local exportItems = {}
    pcall(RbxParser.match, objects, parsed, function(live, p, path)
        if p.source ~= nil and ScriptClasses[live.ClassName] then
            stats.matched += 1; ScriptRegistry[live] = { source = p.source, path = path }; table.insert(stats.list, live)
            -- SUNTIKKAN SOURCE ASLI
            if setScriptSource(live, p.source) then stats.setOK += 1 end
            table.insert(exportItems, { path = path, source = p.source })
        end
    end)
    -- exportScripts dimatikan, tidak ada folder
    if EXPORT_SCRIPT_FILES then stats.exported = exportScripts(label, exportItems) end
    return stats
end

local function describeScripts(stats)
    if not stats then return "" end
    if stats.err then local msg = " | Script tak terbaca: " .. tostring(stats.err); if stats.hint then msg = msg .. " — " .. stats.hint end; return msg end
    if stats.inFile == 0 then return " | Tidak ada script." end
    local msg = " | Script " .. stats.matched .. "/" .. stats.inFile
    if stats.setOK > 0 then msg = msg .. ", " .. stats.setOK .. " terpasang" end
    if stats.setOK < stats.matched then msg = msg .. " | " .. (stats.matched - stats.setOK) .. " gagal setSource" end
    return msg
end

-- SCRIPT MURNI (TANPA FAKE ENV)
local function makeEnv(inst)
    return setmetatable({
        script = inst,
        require = function(m)
            local info = typeof(m) == "Instance" and ScriptRegistry[m] or nil
            if info and m.ClassName == "ModuleScript" then
                if moduleCache[m] then return moduleCache[m][1] end
                local fn, err = loadstring(info.source, "=" .. info.path)
                if not fn then error(err) end
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
            local disabled = false; pcall(function() disabled = inst.Disabled end)
            if not disabled then
                local fn, err = loadstring(info.source, "=" .. info.path)
                if fn then
                    setfenv(fn, makeEnv(inst))
                    task.spawn(fn)
                    started += 1
                else
                    warn("[Punawakan] compile gagal " .. info.path .. ": " .. tostring(err))
                end
            end
        end
    end
    return started
end

--======================= LOAD FILE / ASSET ====================
local function readFileBytes(resolvedPath)
    if not readfileAPI then return nil end
    local ok, data = pcall(readfileAPI, resolvedPath)
    if ok and type(data) == "string" and #data > 0 then return data end
    return nil
end
local function emptyStats(reason) return { inFile = 0, matched = 0, setOK = 0, exported = 0, list = {}, err = reason } end

-- [PATCH] Fungsi prepareFile dihapus pembuatan foldernya
local function prepareFile(path)
    local resolved = findFile(path)
    if not resolved then return nil, "file tidak ditemukan" end
    local bytes = readFileBytes(resolved)
    if not bytes then return nil, "gagal baca bytes" end
    return resolved, bytes
end

local function loadFile(path)
    local safePath, bytesOrErr = prepareFile(path)
    if not safePath then return nil, bytesOrErr end
    local bytes = bytesOrErr

    local function tryLoad(p)
        local errs = {}
        local ok, res = pcall(function() return game:GetObjects(p) end)
        if ok and type(res) == "table" and #res > 0 then return res end
        table.insert(errs, "GetObjects(path): " .. tostring(res))

        if getcustomassetAPI then
            local okA, url = pcall(getcustomassetAPI, p)
            if okA and url then
                local okB, res2 = pcall(function() return game:GetObjects(url) end)
                if okB and type(res2) == "table" and #res2 > 0 then return res2 end
                table.insert(errs, "GetObjects(url): " .. tostring(res2))
            else table.insert(errs, "getcustomasset: " .. tostring(url)) end
        end

        local okC, res3 = pcall(function() return InsertService:LoadLocalAsset(p) end)
        if okC and typeof(res3) == "Instance" then return {res3} end
        table.insert(errs, "LoadLocalAsset: " .. tostring(res3))
        return nil, table.concat(errs, " | ")
    end

    local objects, err = tryLoad(safePath)
    if not objects then return nil, err end
    
    local stats = restoreScripts(objects, bytes, baseNameOf(path))
    return objects, nil, stats
end

local ASSET_ENDPOINTS = {
    "https://assetdelivery.roblox.com/v1/asset/?id=", "https://assetdelivery.roblox.com/v1/asset?id=",
    "https://assetdelivery.roblox.com/v2/asset/?id=", "https://assetdelivery.roproxy.com/v1/asset/?id=", "https://www.roblox.com/asset/?id=",
}
local function fetchAssetBytes(id)
    for _, base in ipairs(ASSET_ENDPOINTS) do
        local body = httpBody(base .. tostring(id))
        if type(body) == "string" and #body > 100 then
            local head = string.sub(body, 1, 200)
            if string.sub(head, 1, 8) == "<roblox!" or string.find(head, "<roblox", 1, true) then return body end
        end
    end
    return nil
end

-- [PATCH] loadToolboxAsset tanpa membuat cache folder
local function loadToolboxAsset(id)
    local bytes = fetchAssetBytes(id)
    if bytes then
        local objects
        local ok, result = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
        if ok and type(result) == "table" and #result > 0 then objects = result
        else
            local err1 = tostring(result)
            local ok2, m = pcall(function() return InsertService:LoadAsset(id) end)
            if ok2 and typeof(m) == "Instance" then objects = { m }
            else return nil, "Gagal muat (GetObjects/LoadAsset): " .. err1 end
        end
        local stats = restoreScripts(objects, bytes, "Toolbox_" .. tostring(id))
        return objects, nil, stats
    end
    
    local objects
    local ok, result = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
    if ok and type(result) == "table" and #result > 0 then objects = result
    else
        local err1 = tostring(result)
        local ok2, m = pcall(function() return InsertService:LoadAsset(id) end)
        if ok2 and typeof(m) == "Instance" then objects = { m }
        else return nil, "Gagal muat. (Download: false | GetObjects: " .. err1 .. ")" end
    end
    local stats = emptyStats("file model asli tidak bisa diunduh")
    return objects, nil, stats
end

--======================= ACTIONS ==============================
local importing = false
local function scanFiles()
    if scanning then return end; if not listfilesAPI then setStatus("ERROR: listfiles tidak tersedia"); return end
    scanning = true; ModelScan.Text = "MEMINDAI..."; MusicScan.Text = "MEMINDAI..."; setStatus("Memindai...")
    table.clear(modelFiles); table.clear(audioFiles); table.clear(fileCache)
    task.spawn(function()
        local visited, counter = {}, { n = 0 }
        for _, root in ipairs(ROOT_PATHS) do pcall(scanDirectory, root, 0, visited, counter) end
        local mc, ac = 0, 0; for _ in pairs(modelFiles) do mc += 1 end; for _ in pairs(audioFiles) do ac += 1 end
        print("[Punakawan] Scan: " .. mc .. " model, " .. ac .. " audio"); renderModels(); renderSongs()
        setStatus("Scan: " .. mc .. " model, " .. ac .. " lagu."); ModelScan.Text = "SCAN FILE"; MusicScan.Text = "SCAN LAGU"; scanning = false
    end)
end
ModelScan.Activated:Connect(scanFiles); MusicScan.Activated:Connect(scanFiles)
ModelSearch:GetPropertyChangedSignal("Text"):Connect(function() setStatus("Ditampilkan " .. renderModels() .. " file.") end)
MusicSearch:GetPropertyChangedSignal("Text"):Connect(function() setStatus("Ditampilkan " .. renderSongs() .. " lagu.") end)
ModelFilter.Activated:Connect(function() modelFilterIndex = modelFilterIndex % #MODEL_FILTERS + 1; ModelFilter.Text = "FILTER: " .. MODEL_FILTERS[modelFilterIndex]; setStatus("Ditampilkan " .. renderModels() .. " file.") end)

ModelImport.Activated:Connect(function()
    if importing then return end; local path = modelList.selected
    if not path then setStatus("Pilih file dulu."); return end
    importing = true; setStatus("Memuat " .. baseNameOf(path) .. "...")
    task.spawn(function()
        local isPlace = PLACE_EXT[getExtension(path)] == true
        local objects, err, stats = loadFile(path)
        if not objects then setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local _, msg, container = importObjects(objects, isPlace, baseNameOf(path))
            
            -- INJEKSI ULANG SETELAH MASUK KE WORKSPACE
            if stats and stats.list then
                for _, scriptInstance in ipairs(stats.list) do
                    local sInfo = ScriptRegistry[scriptInstance]
                    if sInfo and scriptInstance.Parent then setScriptSource(scriptInstance, sInfo.source) end
                end
            end

            local extra = describeScripts(stats)
            if stats and #stats.list > 0 then
                if runScriptsEnabled then extra = extra .. " | " .. runScripts(stats.list) .. " dijalankan"
                else extra = extra .. " | RUN OFF" end
            end
            setStatus(msg .. extra)
        end
        importing = false
    end)
end)

ToolboxImport.Activated:Connect(function()
    if importing then return end; local id = toolboxList.selected
    if not id then setStatus("Pilih model dulu."); return end
    importing = true; setStatus("Mengunduh model " .. tostring(id) .. "...")
    task.spawn(function()
        local objects, err, stats = loadToolboxAsset(id)
        if not objects then setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local _, msg, container = importObjects(objects, false, "Toolbox_" .. tostring(id))
            
            -- INJEKSI ULANG SETELAH MASUK KE WORKSPACE
            if stats and stats.list then
                for _, scriptInstance in ipairs(stats.list) do
                    local sInfo = ScriptRegistry[scriptInstance]
                    if sInfo and scriptInstance.Parent then setScriptSource(scriptInstance, sInfo.source) end
                end
            end

            local extra = describeScripts(stats)
            if stats and #stats.list > 0 then
                if runScriptsEnabled then extra = extra .. " | " .. runScripts(stats.list) .. " dijalankan"
                else extra = extra .. " | RUN OFF" end
            end
            setStatus(msg .. extra)
        end
        importing = false
    end)
end)

OpenButton.Activated:Connect(function() Main.Visible = not Main.Visible end)
Minimize.Activated:Connect(function() Main.Visible = false end)
Close.Activated:Connect(function() clearAudio(); ScreenGui:Destroy() end)
ScreenGui.Destroying:Connect(function() for _, c in ipairs(connections) do c:Disconnect() end end)

for _, d in ipairs(ScreenGui:GetDescendants()) do applyTextShadow(d) end
refreshVolume(); switchTab("model"); Main.Visible = true

local missing = {}
if not listfilesAPI then missing[#missing + 1] = "listfiles" end
if not isfileAPI then missing[#missing + 1] = "isfile" end
if not getcustomassetAPI then missing[#missing + 1] = "getcustomasset" end
if not writefileAPI then missing[#missing + 1] = "writefile" end
if not readfileAPI then missing[#missing + 1] = "readfile" end
if #missing > 0 then setStatus("API hilang: " .. table.concat(missing, ", ")) else setStatus("Siap. Tekan SCAN FILE.") end

print("======================================")
print("PUNAKAWAN IMPORTER v5.5 (PATCHED ZERO CACHE)")
print("======================================")
