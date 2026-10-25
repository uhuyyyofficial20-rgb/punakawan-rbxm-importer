--==============================================================
-- PUNAKAWAN COMMUNITY IMPORTER v6.2 (NO INFINITE YIELD + SPAWN)
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
local SPAWN_POSITION = nil -- Auto-detect spawn location
local USE_SPAWNLOCATION = true
local STACK_ON_PREVIOUS = false
local ROOT_PATHS = { "", ".", "workspace", "Workspace" }
local MAX_DEPTH = 20
local RUN_SCRIPTS_DEFAULT = false -- WAJIB FALSE: Mencegah Infinite Yield
local EXPORT_SCRIPT_FILES = false 
local SCRIPT_EXPORT_FOLDER = "PunawakanScripts"

local API_HOSTS = { "apis.roblox.com", "apis.roproxy.com" }
local THUMB_HOSTS = { "thumbnails.roblox.com", "thumbnails.roproxy.com" }

local GUI_SCALE = Vector2.new(0.62, 0.9)
local GUI_MIN = Vector2.new(370, 340)
local GUI_MAX = Vector2.new(480, 560)
local RGB_SPEED = 0.2
local TOOLBOX_CATEGORY = 10

local LOGO_FILE = "punakawan_logo.png"
local LOGO_ASSET_ID = "rbxassetid://132323133444056"
local BG_FILE = "punawakan_bg.png"
local BG_ASSET_ID = "rbxassetid://132323133444056"

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
local setscriptsourceAPI = getAPI("setscriptsource") or getAPI("set_script_source") or getAPI("setsource")
local sethiddenpropertyAPI = getAPI("sethiddenproperty") or getAPI("set_hidden_property") or getAPI("set_hidden_prop")
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

local ZP2 = {}
for i = 0, 52 do ZP2[i] = 2 ^ i end
local Z_LL_BASE, Z_LL_BITS, Z_ML_BASE, Z_ML_BITS = {}, {}, {}, {}
for i = 0, 15 do Z_LL_BASE[i] = i; Z_LL_BITS[i] = 0 end
do
    local b = { 16, 18, 20, 22, 24, 28, 32, 40, 48, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536 }
    local nb = { 1, 1, 1, 1, 2, 2, 3, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
    for i = 1, 20 do Z_LL_BASE[15 + i] = b[i]; Z_LL_BITS[15 + i] = nb[i] end
end
for i = 0, 31 do Z_ML_BASE[i] = i + 3; Z_ML_BITS[i] = 0 end
do
    local b = { 35, 37, 39, 41, 43, 47, 51, 59, 67, 83, 99, 131, 259, 515, 1027, 2051, 4099, 8195, 16387, 32771, 65539 }
    local nb = { 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
    for i = 1, 21 do Z_ML_BASE[31 + i] = b[i]; Z_ML_BITS[31 + i] = nb[i] end
end
local Z_PRED = {
    LL = { al = 6, p = { 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 1, 1, 1, 1, 1, -1, -1, -1, -1 } },
    ML = { al = 6, p = { 1, 4, 3, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1 } },
    OF = { al = 5, p = { 1, 1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1 } },
}

local function zstdDecompress(src)
    local floor = math.floor
    local len = #src
    local pos = 1
    local out, n = {}, 0
    local reps = { 1, 4, 8 }
    local huff, tabLL, tabOF, tabML = nil, nil, nil, nil
    local predCache = {}

    local function bitsAt(base, lo, nb)
        if nb <= 0 then return 0 end
        local bi = floor(lo / 8)
        local sh = lo - bi * 8
        local b0, b1, b2, b3, b4 = sbyte(src, base + bi, base + bi + 4)
        local v = (b0 or 0) + (b1 or 0) * 256 + (b2 or 0) * 65536 + (b3 or 0) * 16777216 + (b4 or 0) * 4294967296
        return floor(v / ZP2[sh]) % ZP2[nb]
    end
    local function backInit(first, last)
        if last < first then error("zstd: stream kosong") end
        local b = sbyte(src, last)
        if not b or b == 0 then error("zstd: sentinel tidak ada") end
        local h = 0
        while b > 1 do b = floor(b / 2); h = h + 1 end
        return { base = first, left = (last - first) * 8 + h }
    end
    local function backPeek(r, nb)
        if nb == 0 then return 0 end
        local lo = r.left - nb
        if lo >= 0 then return bitsAt(r.base, lo, nb) end
        local m = nb + lo
        if m <= 0 then return 0 end
        return bitsAt(r.base, 0, m) * ZP2[-lo]
    end
    local function backRead(r, nb)
        local v = backPeek(r, nb)
        r.left = r.left - nb
        return v
    end

    local function buildFse(probs, maxSym, al)
        local size = ZP2[al]
        local sy, nb, bs, nextState = {}, {}, {}, {}
        local high = size - 1
        for s = 0, maxSym do
            local p = probs[s] or 0
            if p == -1 then sy[high] = s; high = high - 1; nextState[s] = 1
            else nextState[s] = p end
        end
        local step = floor(size / 2) + floor(size / 8) + 3
        local p0 = 0
        for s = 0, maxSym do
            local p = probs[s] or 0
            for _ = 1, p do
                sy[p0] = s
                p0 = (p0 + step) % size
                while p0 > high do p0 = (p0 + step) % size end
            end
        end
        if p0 ~= 0 then error("zstd: tabel FSE tidak valid") end
        for u = 0, size - 1 do
            local s = sy[u]
            local ns = nextState[s]
            nextState[s] = ns + 1
            local lg, t = 0, ns
            while t > 1 do t = floor(t / 2); lg = lg + 1 end
            local nbits = al - lg
            nb[u] = nbits
            bs[u] = ns * ZP2[nbits] - size
        end
        return { al = al, sy = sy, nb = nb, bs = bs }
    end

    local function readFse(p, maxAl, maxSym)
        local bitPos = 0
        local function rd(k) local v = bitsAt(p, bitPos, k); bitPos = bitPos + k; return v end
        local al = rd(4) + 5
        if al > maxAl then error("zstd: accuracy log terlalu besar") end
        local size = ZP2[al]
        local remaining, threshold, nbBits = size + 1, size, al + 1
        local probs, sym = {}, 0
        while remaining > 1 and sym <= maxSym do
            local max = 2 * threshold - 1 - remaining
            local peek = bitsAt(p, bitPos, nbBits)
            local count
            if peek % threshold < max then
                count = peek % threshold
                bitPos = bitPos + nbBits - 1
            else
                count = peek % (2 * threshold)
                if count >= threshold then count = count - max end
                bitPos = bitPos + nbBits
            end
            count = count - 1
            if count < 0 then remaining = remaining - 1 else remaining = remaining - count end
            probs[sym] = count
            sym = sym + 1
            if count == 0 then
                while true do
                    local r = rd(2)
                    for _ = 1, r do probs[sym] = 0; sym = sym + 1 end
                    if r < 3 then break end
                end
            end
            while remaining < threshold do nbBits = nbBits - 1; threshold = floor(threshold / 2) end
        end
        if remaining ~= 1 then error("zstd: distribusi FSE rusak") end
        return buildFse(probs, sym - 1, al), p + floor((bitPos + 7) / 8)
    end

    local function predefined(kind, maxSym)
        local c = predCache[kind]
        if c then return c end
        local d = Z_PRED[kind]
        local probs = {}
        for i = 1, #d.p do probs[i - 1] = d.p[i] end
        c = buildFse(probs, #d.p - 1, d.al)
        predCache[kind] = c
        return c
    end

    local function readHuffTree(p)
        local hb = sbyte(src, p); p = p + 1
        local weights, nw = {}, 0
        if hb >= 128 then
            nw = hb - 127
            for i = 0, nw - 1 do
                local b = sbyte(src, p + floor(i / 2))
                if i % 2 == 0 then weights[i] = floor(b / 16) else weights[i] = b % 16 end
            end
            p = p + floor((nw + 1) / 2)
        else
            local tab, np = readFse(p, 6, 255)
            local stop = p + hb
            local r = backInit(np, stop - 1)
            local s1 = backRead(r, tab.al)
            local s2 = backRead(r, tab.al)
            while true do
                weights[nw] = tab.sy[s1]; nw = nw + 1
                s1 = tab.bs[s1] + backRead(r, tab.nb[s1])
                if r.left < 0 then weights[nw] = tab.sy[s2]; nw = nw + 1; break end
                weights[nw] = tab.sy[s2]; nw = nw + 1
                s2 = tab.bs[s2] + backRead(r, tab.nb[s2])
                if r.left < 0 then weights[nw] = tab.sy[s1]; nw = nw + 1; break end
                if nw > 255 then error("zstd: bobot terlalu banyak") end
            end
            p = stop
        end
        local total = 0
        for i = 0, nw - 1 do
            local w = weights[i]
            if w > 0 then total = total + ZP2[w - 1] end
        end
        if total == 0 then error("zstd: bobot kosong") end
        local maxBits, t = 0, total
        while t >= 1 do t = floor(t / 2); maxBits = maxBits + 1 end
        local rest = ZP2[maxBits] - total
        local lw, t2 = 0, rest
        while t2 > 1 do t2 = floor(t2 / 2); lw = lw + 1 end
        if ZP2[lw] ~= rest then error("zstd: bobot terakhir tidak valid") end
        weights[nw] = lw + 1; nw = nw + 1
        if maxBits > 11 then error("zstd: tree huffman terlalu dalam") end
        local hs, hn, idx = {}, {}, 0
        for w = 1, maxBits do
            local nbits = maxBits + 1 - w
            local span = ZP2[w - 1]
            for s = 0, nw - 1 do
                if weights[s] == w then
                    for k = 0, span - 1 do hs[idx + k] = s; hn[idx + k] = nbits end
                    idx = idx + span
                end
            end
        end
        return { bits = maxBits, sym = hs, nb = hn }, p
    end

    local function huffStream(tree, first, last, count, dst, dn)
        local r = backInit(first, last)
        local mb, hs, hn = tree.bits, tree.sym, tree.nb
        for i = 1, count do
            local v = backPeek(r, mb)
            local s = hs[v]
            if not s then error("zstd: kode huffman tidak valid") end
            dst[dn + i] = s
            r.left = r.left - hn[v]
        end
        tick(count)
        return dn + count
    end

    local function readLiterals(p)
        local b0 = sbyte(src, p)
        local ltype = b0 % 4
        local sf = floor(b0 / 4) % 4
        local lits = {}
        if ltype == 0 or ltype == 1 then
            local size, hdr
            if sf == 0 or sf == 2 then size = floor(b0 / 8); hdr = 1
            elseif sf == 1 then size = floor(b0 / 16) + sbyte(src, p + 1) * 16; hdr = 2
            else size = floor(b0 / 16) + sbyte(src, p + 1) * 16 + sbyte(src, p + 2) * 4096; hdr = 3 end
            p = p + hdr
            if ltype == 0 then
                for i = 1, size do lits[i] = sbyte(src, p + i - 1) end
                p = p + size
            else
                local b = sbyte(src, p)
                for i = 1, size do lits[i] = b end
                p = p + 1
            end
            tick(size)
            return lits, size, p
        end
        local hdr, nstreams, nbSz
        if sf == 0 then hdr, nstreams, nbSz = 3, 1, 10
        elseif sf == 1 then hdr, nstreams, nbSz = 3, 4, 10
        elseif sf == 2 then hdr, nstreams, nbSz = 4, 4, 14
        else hdr, nstreams, nbSz = 5, 4, 18 end
        local v = 0
        for i = 0, hdr - 1 do v = v + sbyte(src, p + i) * ZP2[8 * i] end
        local regen = floor(v / 16) % ZP2[nbSz]
        local comp = floor(v / ZP2[4 + nbSz]) % ZP2[nbSz]
        p = p + hdr
        local dataEnd = p + comp
        local tree
        if ltype == 2 then
            tree, p = readHuffTree(p)
            huff = tree
        else
            tree = huff
            if not tree then error("zstd: tree huffman sebelumnya tidak ada") end
        end
        if nstreams == 1 then
            huffStream(tree, p, dataEnd - 1, regen, lits, 0)
        else
            local s1 = sbyte(src, p) + sbyte(src, p + 1) * 256
            local s2 = sbyte(src, p + 2) + sbyte(src, p + 3) * 256
            local s3 = sbyte(src, p + 4) + sbyte(src, p + 5) * 256
            local q = p + 6
            local seg = floor((regen + 3) / 4)
            local dn = 0
            dn = huffStream(tree, q, q + s1 - 1, seg, lits, dn); q = q + s1
            dn = huffStream(tree, q, q + s2 - 1, seg, lits, dn); q = q + s2
            dn = huffStream(tree, q, q + s3 - 1, seg, lits, dn); q = q + s3
            huffStream(tree, q, dataEnd - 1, regen - 3 * seg, lits, dn)
        end
        return lits, regen, dataEnd
    end

    local function seqTable(mode, p, maxAl, maxSym, prev, kind)
        if mode == 0 then return predefined(kind), p
        elseif mode == 1 then
            local s = sbyte(src, p)
            return { al = 0, sy = { [0] = s }, nb = { [0] = 0 }, bs = { [0] = 0 } }, p + 1
        elseif mode == 2 then return readFse(p, maxAl, maxSym)
        else
            if not prev then error("zstd: tabel repeat belum ada") end
            return prev, p
        end
    end

    local function decodeBlock(p, bend)
        local lits, nlit, q = readLiterals(p)
        local litPos = 1
        local b = sbyte(src, q)
        local nseq = 0
        if q >= bend or b == nil or b == 0 then nseq = 0
        elseif b < 128 then nseq = b; q = q + 1
        elseif b < 255 then nseq = (b - 128) * 256 + sbyte(src, q + 1); q = q + 2
        else nseq = sbyte(src, q + 1) + sbyte(src, q + 2) * 256 + 32512; q = q + 3 end
        if nseq > 0 then
            local modes = sbyte(src, q); q = q + 1
            tabLL, q = seqTable(floor(modes / 64) % 4, q, 9, 35, tabLL, "LL")
            tabOF, q = seqTable(floor(modes / 16) % 4, q, 8, 31, tabOF, "OF")
            tabML, q = seqTable(floor(modes / 4) % 4, q, 9, 52, tabML, "ML")
            local r = backInit(q, bend - 1)
            local sLL = backRead(r, tabLL.al)
            local sOF = backRead(r, tabOF.al)
            local sML = backRead(r, tabML.al)
            for i = 1, nseq do
                local ofc, mlc, llc = tabOF.sy[sOF], tabML.sy[sML], tabLL.sy[sLL]
                local ofv = ZP2[ofc] + backRead(r, ofc)
                local ml = Z_ML_BASE[mlc] + backRead(r, Z_ML_BITS[mlc])
                local ll = Z_LL_BASE[llc] + backRead(r, Z_LL_BITS[llc])
                local off
                if ofv > 3 then
                    off = ofv - 3
                    reps[3] = reps[2]; reps[2] = reps[1]; reps[1] = off
                else
                    local idx = ofv
                    if ll == 0 then idx = idx + 1 end
                    if idx == 1 then off = reps[1]
                    elseif idx == 2 then off = reps[2]; reps[2] = reps[1]; reps[1] = off
                    elseif idx == 3 then off = reps[3]; reps[3] = reps[2]; reps[2] = reps[1]; reps[1] = off
                    else off = reps[1] - 1; reps[3] = reps[2]; reps[2] = reps[1]; reps[1] = off end
                end
                for j = 0, ll - 1 do out[n + j + 1] = lits[litPos + j] end
                n = n + ll; litPos = litPos + ll
                if off < 1 or off > n then error("zstd: offset tidak valid") end
                local from = n - off
                for j = 1, ml do out[n + j] = out[from + j] end
                n = n + ml
                tick(ll + ml)
                if i < nseq then
                    sLL = tabLL.bs[sLL] + backRead(r, tabLL.nb[sLL])
                    sML = tabML.bs[sML] + backRead(r, tabML.nb[sML])
                    sOF = tabOF.bs[sOF] + backRead(r, tabOF.nb[sOF])
                end
            end
        end
        for j = litPos, nlit do n = n + 1; out[n] = lits[j] end
    end

    local didSize = { [0] = 0, 1, 2, 4 }
    local fcsSize = { 2, 4, 8 }
    while pos + 3 <= len do
        local magic = u32(src, pos)
        if magic == 0xFD2FB528 then
            pos = pos + 4
            local fhd = sbyte(src, pos); pos = pos + 1
            local fcsFlag = floor(fhd / 64) % 4
            local single = floor(fhd / 32) % 2
            local cksum = floor(fhd / 4) % 2
            if single == 0 then pos = pos + 1 end
            pos = pos + didSize[fhd % 4]
            if fcsFlag == 0 then pos = pos + single else pos = pos + fcsSize[fcsFlag] end
            reps = { 1, 4, 8 }
            huff, tabLL, tabOF, tabML = nil, nil, nil, nil
            while true do
                local h = sbyte(src, pos) + sbyte(src, pos + 1) * 256 + sbyte(src, pos + 2) * 65536
                pos = pos + 3
                local last = h % 2
                local btype = floor(h / 2) % 4
                local bsize = floor(h / 8)
                if btype == 0 then
                    for i = 0, bsize - 1 do out[n + i + 1] = sbyte(src, pos + i) end
                    n = n + bsize; pos = pos + bsize
                    tick(bsize)
                elseif btype == 1 then
                    local b = sbyte(src, pos)
                    for i = 1, bsize do out[n + i] = b end
                    n = n + bsize; pos = pos + 1
                    tick(bsize)
                elseif btype == 2 then
                    decodeBlock(pos, pos + bsize)
                    pos = pos + bsize
                else
                    error("zstd: tipe block tidak valid")
                end
                if last == 1 then break end
            end
            if cksum == 1 then pos = pos + 4 end
        elseif magic >= 0x184D2A50 and magic <= 0x184D2A5F then
            pos = pos + 8 + u32(src, pos + 4)
        else
            error("zstd: magic number salah")
        end
    end
    local parts = {}
    for k = 1, n, 2048 do parts[#parts + 1] = schar(table.unpack(out, k, math.min(k + 2047, n))) end
    return table.concat(parts)
end
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
            if ssub(raw, 1, 4) == "\40\181\47\253" then
                local okZ, resZ = pcall(zstdDecompress, raw)
                if not okZ then return nil, "ZSTD gagal: " .. tostring(resZ) end
                chunk = resZ
            else
                chunk = lz4Decompress(raw)
            end
            pos = start + comp
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
        local k = p.class .. "\0" .. p.name
        local g = groups[k]
        if not g then g = {}; groups[k] = g end
        g[#g + 1] = p
    end
    for _, live in ipairs(liveList) do
        local g = groups[live.ClassName .. "\0" .. live.Name]
        if g and #g > 0 then
            local pick = 1
            if #g > 1 then
                local lc = #live:GetChildren()
                for i, cand in ipairs(g) do
                    if #cand.children == lc then pick = i; break end
                end
            end
            local p = table.remove(g, pick)
            local ppath = path .. "/" .. live.Name
            cb(live, p, ppath)
            matchLevel(live:GetChildren(), p.children, cb, ppath)
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
    local spawns = collectSpawns()
    if not SPAWN_POSITION then
        if #spawns > 0 then SPAWN_POSITION = spawns[1].Position else SPAWN_POSITION = Vector3.new(0, 0.5, 0) end
    end
    local sp = SPAWN_POSITION
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

--======================= IMPORT OBJECTS =======================
local SERVICE_NAMES = {
    Lighting = true, ServerScriptService = true, ServerStorage = true, ReplicatedStorage = true, ReplicatedFirst = true,
    StarterGui = true, StarterPack = true, StarterPlayer = true, SoundService = true, Teams = true, Chat = true, TextChatService = true, MaterialService = true,
}
local ScriptRegistry = setmetatable({}, { __mode = "k" })
local ScriptNoRun = setmetatable({}, { __mode = "k" })

local CloneTools = {}
function CloneTools.register(orig, clone, report)
    local info = ScriptRegistry[orig]
    if info then
        ScriptRegistry[clone] = info
        if report then report.scripts[#report.scripts + 1] = clone end
    end
    local oc, cc = orig:GetChildren(), clone:GetChildren()
    for i = 1, math.min(#oc, #cc) do CloneTools.register(oc[i], cc[i], report) end
end
function CloneTools.markNoRun(inst)
    ScriptNoRun[inst] = true
    for _, d in ipairs(inst:GetDescendants()) do ScriptNoRun[d] = true end
end
function CloneTools.into(child, parent, report)
    local ok, clone = pcall(function() return child:Clone() end)
    if not ok or typeof(clone) ~= "Instance" then report.failed = report.failed + 1; return false end
    CloneTools.register(child, clone, report)
    pcall(function() clone.Parent = parent end)
    if clone.Parent == parent then report.services = report.services + 1; return true end
    pcall(function() clone:Destroy() end)
    report.failed = report.failed + 1
    return false
end

local function mergeIntoLocalService(serviceObj, report)
    local okS, realS = pcall(function() return game:GetService(serviceObj.ClassName) end)
    local children = serviceObj:GetChildren()
    if not okS or not realS then report.failed = report.failed + #children; return end
    for _, child in ipairs(children) do
        if serviceObj.ClassName == "StarterGui" and child:IsA("LayerCollector") then
            local okC, clone = pcall(function() return child:Clone() end)
            if okC and typeof(clone) == "Instance" then
                CloneTools.register(child, clone, report)
                pcall(function() clone.Parent = PlayerGui end)
                CloneTools.markNoRun(child)
            end
        end
        local ok = pcall(function() child.Parent = realS end)
        if ok and child.Parent == realS then report.services = report.services + 1 else report.failed = report.failed + 1 end
    end
end
local function collectImportables(objects, report)
    local list = {}
    local function handleService(s, fromDataModel)
        local cn = s.ClassName
        if cn == "Workspace" then
            for _, c in ipairs(s:GetChildren()) do list[#list + 1] = c end
        elseif cn == "ReplicatedStorage" or cn == "Lighting" then
            local real = game:GetService(cn)
            for _, child in ipairs(s:GetChildren()) do CloneTools.into(child, real, report) end
        elseif SERVICE_NAMES[cn] or fromDataModel then
            mergeIntoLocalService(s, report)
        else
            list[#list + 1] = s
        end
    end
    for _, obj in ipairs(objects) do
        if typeof(obj) == "Instance" then
            if obj.ClassName == "DataModel" then
                for _, s in ipairs(obj:GetChildren()) do handleService(s, true) end
            else
                handleService(obj, false)
            end
        end
    end
    return list
end
local function wrapObjects(items, name, report)
    local container = Instance.new("Model"); container.Name = name
    for _, item in ipairs(items) do
        if item:IsA("LayerCollector") then
            local ok = pcall(function() item.Parent = PlayerGui end)
            if ok and item.Parent == PlayerGui then report.gui = report.gui + 1 else report.failed = report.failed + 1 end
        else
            local ok = pcall(function() item.Parent = container end)
            if not ok or item.Parent ~= container then report.failed = report.failed + 1 end
        end
    end
    return container
end
local function importObjects(objects, isPlace, baseName)
    local report = { services = 0, failed = 0, gui = 0, scripts = {} }
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
    if placed == 0 and report.services == 0 and report.gui == 0 then return false, "Tidak ada objek.", nil, report end
    local parts = {}
    if placed > 0 then parts[#parts + 1] = placed .. " objek" end
    if report.services > 0 then parts[#parts + 1] = report.services .. " ke service" end
    if report.gui > 0 then parts[#parts + 1] = report.gui .. " GUI" end
    local msg = "BERHASIL: " .. table.concat(parts, ", ") .. "."
    if report.failed > 0 then msg = msg .. " | " .. report.failed .. " ditolak." end
    return true, msg .. placeNote, target, report
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
local ModelRun = makeButton(ModelPage, "RUN: OFF", UDim2.new(2 / 3, 3, 0, 38), UDim2.new(1 / 3, -3, 0, 32))
local runScriptsEnabled = RUN_SCRIPTS_DEFAULT
local function refreshRunButton() ModelRun.Text = "RUN: " .. (runScriptsEnabled and "ON" or "OFF") end
ModelRun.Activated:Connect(function() runScriptsEnabled = not runScriptsEnabled; refreshRunButton(); setStatus(runScriptsEnabled and "RUN ON." or "RUN OFF.") end)
refreshRunButton()
local modelList = newList(ModelPage, UDim2.fromOffset(0, 76), UDim2.new(1, 0, 1, -160), function(e) setStatus("Dipilih: " .. e.value) end)
local ModelCopy = makeButton(ModelPage, "SALIN SCRIPT", UDim2.new(0, 0, 1, -78), UDim2.new(1 / 3, -3, 0, 32))
local ModelRestore = makeButton(ModelPage, "PULIHKAN", UDim2.new(1 / 3, 1, 1, -78), UDim2.new(1 / 3, -2, 0, 32))
local ModelAuto = makeButton(ModelPage, "AUTO: ON", UDim2.new(2 / 3, 3, 1, -78), UDim2.new(1 / 3, -3, 0, 32))
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

local function httpBody(url, headers)
    local function viaRequest(h)
        if not requestAPI then return nil end
        local ok2, res = pcall(requestAPI, { Url = url, Method = "GET", Headers = h or { ["Accept"] = "*/*" } })
        if ok2 and type(res) == "table" then
            local code = res.StatusCode or res.status_code; local b = res.Body or res.body; local succ = res.Success
            if succ == nil then succ = (type(code) ~= "number") or code < 400 end
            if succ and type(b) == "string" and b ~= "" then return b end
        end
        return nil
    end
    if headers then
        local b = viaRequest(headers)
        if b then return b end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and body ~= "" then return body end
    return viaRequest(nil)
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
local thumbnailURLCache, thumbURLsBatch = {}, {}
local function resolveThumbnail(id, skipHttp)
    id = tonumber(id); if not id then return MODEL_ICON end
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

--======================= SCRIPT RECOVERY ===============
local ScriptClasses = { Script = true, LocalScript = true, ModuleScript = true }
local moduleCache = setmetatable({}, { __mode = "k" })
local decompileAPI = getAPI("decompile")
local okEnv, BASE_ENV = pcall(function() return getfenv() end)
if not okEnv or type(BASE_ENV) ~= "table" then BASE_ENV = _G end

local function sanitizeName(s) local c = tostring(s):gsub("[^%w%._%- ]", "_"); if c == "" then c = "_" end; return c end

local SrcDiag = { direct = "-", api = "-", hidden = "-", id = "-" }
SrcDiag.setId = getAPI("setthreadidentity") or getAPI("set_thread_identity") or getAPI("setidentity")
    or getAPI("setthreadcontext") or getAPI("set_thread_context")
SrcDiag.getId = getAPI("getthreadidentity") or getAPI("get_thread_identity") or getAPI("getidentity")
    or getAPI("getthreadcontext") or getAPI("get_thread_context")

function SrcDiag.withIdentity(fn)
    local prev
    if SrcDiag.getId then local okG, v = pcall(SrcDiag.getId); if okG then prev = v end end
    if SrcDiag.setId then
        local okS = pcall(SrcDiag.setId, 8)
        if not okS then okS = pcall(SrcDiag.setId, 7) end
        if not okS then okS = pcall(SrcDiag.setId, 2) end
        SrcDiag.id = okS and "naik" or "gagal naik"
    else
        SrcDiag.id = "tidak ada"
    end
    local ok, res = pcall(fn)
    if SrcDiag.setId and prev then pcall(SrcDiag.setId, prev) end
    if ok then return res end
    return false
end

function SrcDiag.readSource(inst)
    local prev = SrcDiag.writing
    SrcDiag.writing = true
    local okR, cur = pcall(function() return inst.Source end)
    SrcDiag.writing = prev
    if okR and type(cur) == "string" then return cur end
    return nil
end

SrcDiag.src = setmetatable({}, { __mode = "k" })
SrcDiag.hook = "belum"
SrcDiag.writing = false

function SrcDiag.installHook()
    if SrcDiag.hook == "ok" then return end
    local nc = getAPI("newcclosure") or function(f) return f end
    local oldIndex, oldNew

    local function newIndex(self, key)
        if key == "Source" and not SrcDiag.writing and typeof(self) == "Instance" then
            local s = SrcDiag.src[self]
            if s ~= nil then return s end
        end
        if not oldIndex then return nil end
        return oldIndex(self, key)
    end
    local function newNewindex(self, key, value)
        if key == "Source" and not SrcDiag.writing and type(value) == "string" and typeof(self) == "Instance"
            and SrcDiag.src[self] ~= nil then
            SrcDiag.src[self] = value
            return
        end
        if not oldNew then return end
        return oldNew(self, key, value)
    end

    local okH = false
    local hmm = getAPI("hookmetamethod")
    if hmm then
        okH = pcall(function() oldIndex = hmm(game, "__index", nc(newIndex)) end)
        okH = okH and oldIndex ~= nil
        if okH then pcall(function() oldNew = hmm(game, "__newindex", nc(newNewindex)) end) end
    end
    if not okH then
        local grm = getAPI("getrawmetatable")
        local sro = getAPI("setreadonly")
        local mw = getAPI("make_writeable")
        if grm then
            okH = pcall(function()
                local mt = grm(game)
                local oi = rawget(mt, "__index")
                local on = rawget(mt, "__newindex")
                if sro then sro(mt, false) elseif mw then mw(mt) end
                if oi then oldIndex = oi; mt.__index = nc(newIndex) end
                if on then oldNew = on; mt.__newindex = nc(newNewindex) end
                if sro then sro(mt, true) end
            end)
        end
    end
    SrcDiag.hook = (okH and oldIndex ~= nil) and "ok" or "gagal"

    pcall(function()
        local okG, genv = pcall(getgenv)
        if not okG or type(genv) ~= "table" then return end
        for _, name in ipairs({ "decompile", "getscriptsource" }) do
            local orig = genv[name]
            if type(orig) == "function" then
                genv[name] = function(inst, ...)
                    if typeof(inst) == "Instance" then
                        local s = SrcDiag.src[inst]
                        if s ~= nil then return s end
                    end
                    return orig(inst, ...)
                end
            end
        end
    end)
end
pcall(SrcDiag.installHook)

local function setScriptSource(inst, source)
    if source == nil then return false end
    if source == "" then return true end
    SrcDiag.src[inst] = source
    SrcDiag.writing = true
    local okW = SrcDiag.withIdentity(function()
        if decompileAPI and source == "" then
            local okD, decompiled = pcall(decompileAPI, inst)
            if okD and type(decompiled) == "string" and #decompiled > 0 and not string.find(decompiled, "^%-%-") then
                source = decompiled
                SrcDiag.src[inst] = source
            end
        end

        local ok1, e1 = pcall(function() inst.Source = source end)
        if ok1 then
            local cur = SrcDiag.readSource(inst)
            if cur == source then SrcDiag.direct = "ok"; return true end
            SrcDiag.direct = "tulis ok tapi baca ulang beda"
        else
            SrcDiag.direct = tostring(e1):sub(1, 40)
        end
        
        if setscriptsourceAPI then
            local ok, e = pcall(setscriptsourceAPI, inst, source)
            if ok then
                local cur = SrcDiag.readSource(inst)
                if cur == nil or cur == source then SrcDiag.api = "ok"; return true end
                SrcDiag.api = "dipanggil tapi baca ulang beda"
            else
                SrcDiag.api = tostring(e):sub(1, 40)
            end
        else
            SrcDiag.api = "tidak ada"
        end
        
        if sethiddenpropertyAPI then
            local ok, e = pcall(sethiddenpropertyAPI, inst, "Source", source)
            if ok then
                local cur = SrcDiag.readSource(inst)
                if cur == nil or cur == source then SrcDiag.hidden = "ok"; return true end
                SrcDiag.hidden = "dipanggil tapi baca ulang beda"
            else
                SrcDiag.hidden = tostring(e):sub(1, 40)
            end
        else
            SrcDiag.hidden = "tidak ada"
        end
        return false
    end)
    SrcDiag.writing = false
    if okW then return true end
    return SrcDiag.hook == "ok"
end

local function exportScripts(label, items)
    if not writefileAPI or #items == 0 then return 0 end
    local function ensureFolder(p) if makefolderAPI and not folderExists(p) then pcall(makefolderAPI, p) end end
    local base = SCRIPT_EXPORT_FOLDER .. "/" .. sanitizeName(label); ensureFolder(SCRIPT_EXPORT_FOLDER); ensureFolder(base)
    local used, count = {}, 0
    for _, item in ipairs(items) do
        local segs = {}; for seg in string.gmatch(item.path, "[^/]+") do segs[#segs + 1] = sanitizeName(seg) end
        if #segs > 0 then
            local folder = base; for i = 1, #segs - 1 do folder = folder .. "/" .. segs[i]; ensureFolder(folder) end
            local file = folder .. "/" .. segs[#segs]; local candidate, n = file .. ".lua", 1
            while used[string.lower(candidate)] do n = n + 1; candidate = file .. "_" .. n .. ".lua" end
            used[string.lower(candidate)] = true
            if pcall(writefileAPI, candidate, item.source) then count = count + 1 end
        end
    end
    return count
end

local function restoreScripts(objects, bytes, label)
    local stats = { inFile = 0, matched = 0, setOK = 0, exported = 0, fallback = 0, list = {}, err = nil, hint = nil }
    local exportItems = {}

    local function getFallbackSource(inst)
        local ok, src = pcall(function() return inst.Source end)
        if ok and type(src) == "string" and src ~= "" then return src, "Source" end
        if decompileAPI then
            local ok2, res = pcall(decompileAPI, inst)
            if ok2 and type(res) == "string" and res ~= "" then
                local first = string.lower(res:match("^[^\n]*") or "")
                local bad = string.sub(first, 1, 2) == "--" and (first:find("fail", 1, true) or first:find("error", 1, true) or first:find("unable", 1, true))
                if not bad then return res, "decompile" end
            end
        end
        return nil
    end

    if type(bytes) == "string" and #bytes > 0 then
        local okP, r1, r2 = pcall(RbxParser.parse, bytes)
        local parsed, perr
        if okP then parsed, perr = r1, r2 else perr = tostring(r1) end
        if not parsed then
            stats.err = perr or "gagal baca"
            if tostring(perr):find("ZSTD") then stats.hint = "decoder ZSTD gagal; simpan ulang model (Save As .rbxm) lalu coba lagi." end
        else
            stats.inFile = RbxParser.countScripts(parsed)
            if stats.inFile > 0 then
                local okM, errM = pcall(RbxParser.match, objects, parsed, function(live, p, path)
                    if p.source ~= nil and ScriptClasses[live.ClassName] and not ScriptRegistry[live] then
                        stats.matched = stats.matched + 1
                        ScriptRegistry[live] = { source = p.source, path = path }
                        table.insert(stats.list, live)
                        if setScriptSource(live, p.source) then stats.setOK = stats.setOK + 1 end
                        table.insert(exportItems, { path = path, source = p.source })
                    end
                end)
                if not okM then stats.err = "pencocokan: " .. tostring(errM) end
            end
        end
    else
        stats.err = "file asli tidak tersedia"
    end

    local function walk(inst, parentPath)
        local path = parentPath .. "/" .. inst.Name
        if ScriptClasses[inst.ClassName] and not ScriptRegistry[inst] then
            local src, how = getFallbackSource(inst)
            if src then
                ScriptRegistry[inst] = { source = src, path = path }
                table.insert(stats.list, inst)
                stats.fallback = stats.fallback + 1
                if how == "Source" or setScriptSource(inst, src) then stats.setOK = stats.setOK + 1 end
                table.insert(exportItems, { path = path, source = src })
            end
        end
        for _, c in ipairs(inst:GetChildren()) do walk(c, path) end
    end
    for _, o in ipairs(objects) do
        if typeof(o) == "Instance" then
            if o.ClassName == "DataModel" then
                for _, c in ipairs(o:GetChildren()) do pcall(walk, c, "") end
            else
                pcall(walk, o, "")
            end
        end
    end

    local CS = game:GetService("CollectionService")
    local function depthOf(i) local d, p = 0, i.Parent; while p do d = d + 1; p = p.Parent end; return d end
    local function fresh(old)
        local info = ScriptRegistry[old]
        if not info then return nil end
        local okN, new = pcall(Instance.new, old.ClassName)
        if not okN or typeof(new) ~= "Instance" then return nil end
        setScriptSource(new, info.source)
        pcall(function() new.Name = old.Name end)
        for _, prop in ipairs({ "Disabled", "RunContext", "Enabled" }) do pcall(function() new[prop] = old[prop] end) end
        pcall(function() for k, v in pairs(old:GetAttributes()) do new:SetAttribute(k, v) end end)
        pcall(function() for _, t in ipairs(CS:GetTags(old)) do CS:AddTag(new, t) end end)
        for _, c in ipairs(old:GetChildren()) do pcall(function() c.Parent = new end) end
        local parent = old.Parent
        pcall(function() new.Parent = parent end)
        ScriptRegistry[new] = info
        return new
    end
    local ordered = {}
    for _, inst in ipairs(stats.list) do ordered[#ordered + 1] = { inst = inst, d = depthOf(inst) } end
    table.sort(ordered, function(a, b) return a.d > b.d end)
    local newList, replaced = {}, 0
    for _, e in ipairs(ordered) do
        local old = e.inst
        local new = fresh(old)
        if new then
            replaced = replaced + 1
            for idx, o in ipairs(objects) do if o == old then objects[idx] = new end end
            pcall(function() old:Destroy() end)
            newList[#newList + 1] = new
        else
            newList[#newList + 1] = old
        end
    end
    stats.list = newList
    stats.replaced = replaced

    if EXPORT_SCRIPT_FILES then stats.exported = exportScripts(label, exportItems) end
    return stats
end

local function describeScripts(stats)
    if not stats then return "" end
    local total = stats.matched + (stats.fallback or 0)
    if total == 0 then
        if stats.err then
            local msg = " | Script tak terbaca: " .. tostring(stats.err)
            if stats.hint then msg = msg .. " — " .. stats.hint end
            return msg
        end
        if stats.inFile == 0 then return " | Tidak ada script." end
        return " | Ada " .. stats.inFile .. " script di file tapi tidak cocok dengan objek hasil load."
    end
    local msg = " | Script " .. total
    if stats.inFile > 0 then msg = msg .. "/" .. stats.inFile end
    if (stats.fallback or 0) > 0 then msg = msg .. " (" .. stats.fallback .. " via decompile)" end
    local live = stats.liveCount or total
    local okc = stats.injected or stats.setOK
    msg = msg .. ", " .. okc .. "/" .. live .. " source terpasang"
    if (stats.replaced or 0) > 0 then msg = msg .. ", " .. stats.replaced .. " bisa diedit" end
    if okc < live then
        msg = msg .. " | GAGAL tulis Source ke " .. (live - okc) .. " script (tetap dijalankan). Diagnosa: Source=" .. SrcDiag.direct
            .. "; setscriptsource=" .. SrcDiag.api .. "; hidden=" .. SrcDiag.hidden .. "; identity=" .. SrcDiag.id .. "; hook=" .. SrcDiag.hook
    end
    return msg
end

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
        end
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
                    warn("[Punakawan] compile gagal " .. info.path .. ": " .. tostring(err))
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
    "https://assetdelivery.roproxy.com/v1/asset/?id=", "https://www.roblox.com/asset/?id=",
}
local function fetchAssetBytes(id)
    local function looksLikeRbx(b)
        if type(b) ~= "string" or #b < 100 then return false end
        local head = string.sub(b, 1, 200)
        return string.sub(head, 1, 8) == "<roblox!" or string.find(head, "<roblox", 1, true) ~= nil
    end
    local ASSET_V2 = { "https://assetdelivery.roblox.com/v2/assetId/", "https://assetdelivery.roproxy.com/v2/assetId/" }
    local hdr = { ["Accept"] = "*/*", ["User-Agent"] = "Roblox/WinInet", ["Roblox-Place-Id"] = tostring(game.PlaceId) }
    for _, base in ipairs(ASSET_V2) do
        local body = httpBody(base .. tostring(id), hdr)
        if body then
            local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
            if ok and type(data) == "table" and type(data.locations) == "table" then
                for _, loc in ipairs(data.locations) do
                    if type(loc) == "table" and type(loc.location) == "string" then
                        local b = httpBody(loc.location, hdr)
                        if looksLikeRbx(b) then return b end
                    end
                end
            end
        end
    end
    for _, base in ipairs(ASSET_ENDPOINTS) do
        local b = httpBody(base .. tostring(id), hdr)
        if looksLikeRbx(b) then return b end
    end
    return nil
end

local function loadToolboxAsset(id)
    local bytes = fetchAssetBytes(id)
    local objects
    local ok, result = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
    if ok and type(result) == "table" and #result > 0 then objects = result
    else
        local err1 = tostring(result)
        local ok2, m = pcall(function() return InsertService:LoadAsset(id) end)
        if ok2 and typeof(m) == "Instance" then objects = { m }
        elseif bytes and writefileAPI then
            local tmp = "punawakan_tmp_" .. tostring(id) .. ".rbxm"
            local objs, err, stats
            if pcall(writefileAPI, tmp, bytes) then
                objs, err, stats = loadFile(tmp)
                fileCache[tmp] = nil
                local del = getAPI("delfile"); if del then pcall(del, tmp) end
            end
            if objs then return objs, nil, stats end
            return nil, "Gagal muat. (GetObjects: " .. err1 .. " | File: " .. tostring(err) .. ")"
        else
            return nil, "Gagal muat. (Download: " .. tostring(bytes ~= nil) .. " | GetObjects: " .. err1 .. ")"
        end
    end
    local stats = restoreScripts(objects, bytes, "Toolbox_" .. tostring(id))
    if not bytes then stats.err = "file model asli tidak bisa diunduh (asset privat / HTTP diblokir)" end
    return objects, nil, stats
end

local Backup
local function finishImport(objects, stats, isPlace, baseName)
    local _, msg, target, report = importObjects(objects, isPlace, baseName)
    if target and typeof(target) == "Instance" then pcall(function() Backup.add(target, baseName) end) end
    local live, runnable, seen = {}, {}, {}
    local function add(inst)
        if inst and not seen[inst] and ScriptRegistry[inst] then
            local inGame = false
            pcall(function() inGame = inst.Parent ~= nil and inst:IsDescendantOf(game) end)
            if inGame then
                seen[inst] = true
                live[#live + 1] = inst
                if not ScriptNoRun[inst] then runnable[#runnable + 1] = inst end
            end
        end
    end
    if stats and stats.list then for _, i in ipairs(stats.list) do add(i) end end
    if report and report.scripts then for _, i in ipairs(report.scripts) do add(i) end end

    local injected = 0
    for _, inst in ipairs(live) do
        local info = ScriptRegistry[inst]
        if info and setScriptSource(inst, info.source) then injected = injected + 1 end
    end
    if stats then stats.injected = injected; stats.liveCount = #live end
    task.delay(1.5, function()
        for _, inst in ipairs(live) do
            local info = ScriptRegistry[inst]
            if info and inst.Parent and SrcDiag.readSource(inst) ~= info.source then pcall(setScriptSource, inst, info.source) end
        end
    end)

    local extra = describeScripts(stats)
    if #runnable > 0 then
        if runScriptsEnabled then
            task.delay(2, function()
                if not ScreenGui.Parent then return end
                
                -- FITUR BARU: Saring script yang memiliki WaitForChild agar tidak menyebabkan Infinite Yield
                local safeRunnable = {}
                for _, inst in ipairs(runnable) do
                    local info = ScriptRegistry[inst]
                    if info and info.source and not string.find(info.source, "WaitForChild", 1, true) then
                        safeRunnable[#safeRunnable + 1] = inst
                    else
                        warn("[Punakawan] Skip script (WaitForChild): " .. (info and info.path or "unknown"))
                    end
                end
                
                local started = runScripts(safeRunnable)
                setStatus(msg .. extra .. " | " .. started .. " dijalankan (script WaitForChild dilewati)")
            end)
            extra = extra .. " | Menunggu eksekusi..."
        else
            extra = extra .. " | RUN OFF"
        end
    end
    return msg .. extra
end

--======================= BACKUP / PULIHKAN / SALIN =============
-- Studio Lite memakai state server untuk Play/Test; objek buatan executor hanya
-- ada di client. Cadangan ini memasang ulang model bila hilang dari Workspace.
Backup = {}
do
    local entries = {}
    local autoRestore = true
    Backup.add = function(target, name)
        local ok, clone = pcall(function() return target:Clone() end)
        if ok and clone then entries[#entries + 1] = { live = target, clone = clone, name = name } end
    end
    local function restoreAll(manual)
        local n = 0
        for _, e in ipairs(entries) do
            local present = false
            pcall(function() present = e.live and e.live.Parent ~= nil and e.live:IsDescendantOf(workspace) end)
            if not present then
                local ok, new = pcall(function() return e.clone:Clone() end)
                if ok and new then
                    pcall(function() new.Parent = workspace end)
                    e.live = new; n += 1
                end
            end
        end
        if n > 0 then setStatus("Dipulihkan: " .. n .. " model kembali ke Workspace.")
        elseif manual then setStatus("Semua model masih ada di Workspace.") end
        return n
    end
    ModelRestore.Activated:Connect(function() restoreAll(true) end)
    ModelAuto.Activated:Connect(function()
        autoRestore = not autoRestore
        ModelAuto.Text = "AUTO: " .. (autoRestore and "ON" or "OFF")
        setStatus(autoRestore and "Auto-pulih ON." or "Auto-pulih OFF (hapus model manual tidak dipulihkan).")
    end)
    task.spawn(function()
        while ScreenGui.Parent do
            task.wait(1.5)
            if autoRestore and #entries > 0 then pcall(restoreAll, false) end
        end
    end)
    ModelCopy.Activated:Connect(function()
        local list = {}
        for inst, info in pairs(ScriptRegistry) do
            local alive = false
            pcall(function() alive = inst.Parent ~= nil and inst:IsDescendantOf(game) end)
            if alive and type(info.source) == "string" then list[#list + 1] = info end
        end
        if #list == 0 then setStatus("Belum ada script hasil import untuk disalin."); return end
        table.sort(list, function(a, b) return tostring(a.path) < tostring(b.path) end)
        local parts = {}
        for _, info in ipairs(list) do
            parts[#parts + 1] = "-- ===== " .. tostring(info.path) .. " =====\n" .. info.source
        end
        local text = table.concat(parts, "\n\n")
        local clip = getAPI("setclipboard") or getAPI("toclipboard")
        local copied = clip and pcall(clip, text)
        setStatus(#list .. " script " .. (copied and "disalin ke clipboard" or "TIDAK bisa disalin") .. ".")
    end)
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
        local okL, objects, err, stats = pcall(loadFile, path)
        if not okL then setStatus("IMPOR GAGAL: " .. tostring(objects))
        elseif not objects then setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local okF, res = pcall(finishImport, objects, stats, isPlace, baseNameOf(path))
            setStatus(okF and res or ("IMPOR GAGAL: " .. tostring(res)))
        end
        importing = false
    end)
end)

ToolboxImport.Activated:Connect(function()
    if importing then return end; local id = toolboxList.selected
    if not id then setStatus("Pilih model dulu."); return end
    importing = true; setStatus("Mengunduh model " .. tostring(id) .. "...")
    task.spawn(function()
        local okL, objects, err, stats = pcall(loadToolboxAsset, id)
        if not okL then setStatus("IMPOR GAGAL: " .. tostring(objects))
        elseif not objects then setStatus("IMPOR GAGAL: " .. tostring(err))
        else
            local okF, res = pcall(finishImport, objects, stats, false, "Toolbox_" .. tostring(id))
            setStatus(okF and res or ("IMPOR GAGAL: " .. tostring(res)))
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

do
    local delf = getAPI("delfolder")
    if delf then for _, name in ipairs({ "PunawakanCache", "PunawakanThumbs" }) do
        if folderExists(name) then pcall(delf, name) end
    end end
end
local missing = {}
if not listfilesAPI then missing[#missing + 1] = "listfiles" end
if not isfileAPI then missing[#missing + 1] = "isfile" end
if not getcustomassetAPI then missing[#missing + 1] = "getcustomasset" end
if not writefileAPI then missing[#missing + 1] = "writefile" end
if not readfileAPI then missing[#missing + 1] = "readfile" end
if #missing > 0 then setStatus("API hilang: " .. table.concat(missing, ", "))
else setStatus("Siap. setscriptsource: " .. (setscriptsourceAPI and "ada" or "TIDAK ADA") .. ", decompile: " .. (getAPI("decompile") and "ada" or "TIDAK ADA") .. ", hook Source: " .. SrcDiag.hook) end

print("======================================")
print("PUNAKAWAN IMPORTER v7.1")
print("======================================")
