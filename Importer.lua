--==============================================================
-- REYYKAI
-- Original Founder: ItsmeeLangzz x H2C 👑
-- Delta Executor -> Roblox Studio Lite
-- SOURCE: Delta/Workspace/
-- SUPPORTED: RBXM + RBXMX + RBXL + RBXLX
--==============================================================

if not game:IsLoaded() then game.Loaded:Wait() end

--==============================================================
-- SERVICES
--==============================================================

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local HttpService      = game:GetService("HttpService")
local InsertService    = game:GetService("InsertService")
local TweenService     = game:GetService("TweenService")
local UIS              = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local player = Players.LocalPlayer

--==============================================================
-- CAPABILITY DETECTION
--==============================================================

local ENV = _G
pcall(function() if type(getgenv) == "function" then ENV = getgenv() end end)

local function getFn(name)
    local f
    pcall(function() f = ENV[name] end)
    if type(f) == "function" then return f end
    pcall(function() if type(getfenv) == "function" then f = getfenv()[name] end end)
    if type(f) == "function" then return f end
    pcall(function() f = _G[name] end)
    if type(f) == "function" then return f end
    return nil
end

local listfiles      = getFn("listfiles")
local readfile       = getFn("readfile")
local isfile         = getFn("isfile")
local isfolder       = getFn("isfolder")
local getcustomasset = getFn("getcustomasset")
local gethui         = getFn("gethui")

_G.LANGZ_RAW_SOURCES = _G.LANGZ_RAW_SOURCES or {}

local parent
if gethui then pcall(function() parent = gethui() end) end
if not parent then pcall(function() parent = game:GetService("CoreGui") end) end
if not parent and player then parent = player:WaitForChild("PlayerGui", 5) end
if not parent then return end

pcall(function()
    local old = parent:FindFirstChild("REYY_IMPORT")
    if old then old:Destroy() end
end)

--==============================================================
-- RBXM BINARY PARSER (LZ4 + zstd, dari v62)
--==============================================================

local function Buffer(str, allowOverflows)
    local s = { Offset=0, Source=str, Length=#str, AllowOverflows=(allowOverflows==nil and true) or allowOverflows }
    function s:read(len, shift) len=len or 1; shift=(shift==nil and true) or shift; local d=string.sub(self.Source,self.Offset+1,self.Offset+len); if shift then self:seek(len) end; return d end
    function s:seek(len) self.Offset=math.clamp(self.Offset+len,0,self.Length) end
    function s:readNumber(fmt,shift) fmt=fmt or "I1"; local c=self:read(string.packsize(fmt),shift); return string.unpack(fmt,c) end
    function s:append(str2) self.Source=self.Source..str2; self.Length=#self.Source end
    function s:toEnd() self.Offset=self.Length end
    return s
end

local function transformInt(x) return (x%2==0) and (x/2) or (-(x+1)/2) end
local function rbxF32(x) x=bit32.rrotate(x,1); return string.unpack(">f",string.pack(">I4",x)) end

local bt = {}
function bt.String(b) return b:read(b:readNumber("<I4")) end
function bt.Int32(b) return transformInt(b:readNumber(">I4")) end
function bt.Int64(b) return transformInt(b:readNumber(">I8")) end
function bt.Float32(b) return rbxF32(b:readNumber(">I4")) end
function bt.Float64(b) return b:readNumber("<d") end

function bt.InterleaveArrayWithSize(b,count,sizeof)
    if count<0 then return Buffer("",false) end
    local stream=b:read(count*sizeof); local out=table.create(count)
    for i=1,count do local chunk=table.create(sizeof); for s2=0,sizeof-1 do local bp=i+(count*s2); chunk[s2+1]=string.sub(stream,bp,bp) end; out[i]=table.concat(chunk) end
    return Buffer(table.concat(out),false)
end
function bt.unsignedIntArray(b,count) if count<1 then return {} end; local o=table.create(count); local s2=bt.InterleaveArrayWithSize(b,count,4); for i=1,count do o[i]=s2:readNumber("<I4") end; return o end
function bt.Int32Array(b,count) if count<1 then return {} end; local o=table.create(count); local s2=bt.InterleaveArrayWithSize(b,count,4); for i=1,count do o[i]=bt.Int32(s2) end; return o end
function bt.Int64Array(b,count) if count<1 then return {} end; local o=table.create(count); local s2=bt.InterleaveArrayWithSize(b,count,8); for i=1,count do o[i]=bt.Int64(s2) end; return o end
function bt.RbxF32Array(b,count) if count<1 then return {} end; local o=table.create(count); local s2=bt.InterleaveArrayWithSize(b,count,4); for i=1,count do o[i]=bt.Float32(s2) end; return o end
function bt.RefArray(b,count)
    if count<1 then return {} end
    local o=table.create(count); local refs=bt.Int32Array(b,count); local last=0
    for i=1,count do local ref=last+refs[i]; o[i]=ref; last=ref end
    return o
end

local function b64encode(str)
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local out={}
    for i=1,#str,3 do
        local b0,b1,b2=string.byte(str,i,i+2)
        local b=bit32.lshift(b0,16)+bit32.lshift(b1 or 0,8)+(b2 or 0)
        table.insert(out,chars:sub(bit32.extract(b,18,6)+1,bit32.extract(b,18,6)+1))
        table.insert(out,chars:sub(bit32.extract(b,12,6)+1,bit32.extract(b,12,6)+1))
        table.insert(out,b1 and chars:sub(bit32.extract(b,6,6)+1,bit32.extract(b,6,6)+1) or "=")
        table.insert(out,b2 and chars:sub(bit32.band(b,63)+1,bit32.band(b,63)+1) or "=")
    end
    return table.concat(out)
end

local function zstdDecompress(stream)
    local z64=b64encode(stream)
    local json='{"m":null,"t":"buffer","zbase64":"'..z64..'"}'
    local x=HttpService:JSONDecode(json)
    return buffer.tostring(x)
end

local function lz4Decompress(lz4data)
    local inp=Buffer(lz4data)
    local compressedLen=string.unpack("<I4",inp:read(4))
    local decompressedLen=string.unpack("<I4",inp:read(4))
    local reserved=string.unpack("<I4",inp:read(4))
    if reserved~=0 then error("not lz4") end
    if compressedLen==0 then return inp:read(decompressedLen) end
    local out=Buffer("")
    repeat
        local token=string.byte(inp:read())
        local litLen=bit32.rshift(token,4)
        local matLen=bit32.band(token,15)+4
        if litLen>=15 then repeat local nb=string.byte(inp:read()); litLen=litLen+nb until nb~=0xFF end
        local literal=inp:read(litLen); out:append(literal); out:toEnd()
        if out.Length<decompressedLen then
            local offset=string.unpack("<I2",inp:read(2))
            if matLen>=19 then repeat local nb=string.byte(inp:read()); matLen=matLen+nb until nb~=0xFF end
            out:seek(-offset)
            local pos=out.Offset; local match=out:read(matLen)
            local unread=out.LastUnreadBytes or 0
            if unread then
                repeat out.Offset=pos; local extra=out:read(unread); unread=out.LastUnreadBytes or 0; match=match..extra until unread<=0
            end
            out:append(match); out:toEnd()
        end
    until out.Length>=decompressedLen
    return out.Source
end

local function parseRBXMForSources(data)
    local sources={}
    local rb=Buffer(data,false)
    if rb:read(8)~="<roblox!" or rb:read(6)~=string.char(137,255,13,10,26,10) then return sources,"Invalid header" end
    if rb:read(2)~=(string.char(0)..string.char(0)) then return sources,"Invalid version" end
    local classCount=rb:readNumber("<i4"); local instCount=rb:readNumber("<i4")
    local classRefs,virtualInstances,strings,chunkInfo={},{},{},{}
    local _EC="END"..string.char(0)
    local valid={[_EC]=true,["INST"]=true,["META"]=true,["PRNT"]=true,["PROP"]=true,["SIGN"]=true,["SSTR"]=true}
    for k in pairs(valid) do chunkInfo[k]={} end
    if rb:read(8)~=string.char(0,0,0,0,0,0,0,0) then return sources,"Invalid header" end
    local index,last_chunk=0,nil
    repeat
        index=index+1
        local chunk={InternalID=index,Header=rb:read(4)}
        if not valid[chunk.Header] then return sources,"Invalid chunk" end
        local lz4h=rb:read(16,false)
        local compressed=string.unpack("<I4",string.sub(lz4h,1,4))
        local decompressed=string.unpack("<I4",string.sub(lz4h,5,8))
        local zstd_check=string.sub(lz4h,13,16)
        local dataChunk
        if compressed==0 then
            dataChunk=rb:read(decompressed+12)
        else
            if zstd_check==string.char(40,181,47,253) then rb:seek(12); dataChunk=zstdDecompress(rb:read(compressed))
            else dataChunk=lz4Decompress(rb:read(compressed+12)) end
        end
        chunk.Data=Buffer(dataChunk,false); table.insert(chunkInfo[chunk.Header],chunk); last_chunk=chunk
    until last_chunk and last_chunk.Header==_EC

    for _,chunk in ipairs(chunkInfo["SSTR"] or {}) do
        local b=chunk.Data
        if b:readNumber("<I4")==0 then for i=1,b:readNumber("<I4") do b:read(16); strings[i]=bt.String(b) end end
    end

    for _,chunk in ipairs(chunkInfo["INST"] or {}) do
        local b=chunk.Data
        local classID=b:readNumber("<I4"); local className=bt.String(b)
        if b:read()=="\1" then return sources,"Contains services" end
        local count=b:readNumber("<I4"); local refs=bt.RefArray(b,count)
        classRefs[classID]={Name=className,Sizeof=count,Refs=refs}
        for _,ref in ipairs(refs) do virtualInstances[ref]={ClassId=classID,ClassName=className,Ref=ref,Properties={},Children={}} end
    end

    for _,chunk in ipairs(chunkInfo["PROP"] or {}) do
        local b=chunk.Data
        local classID=b:readNumber("<I4"); local classref=classRefs[classID]
        if not classref then return sources,"Missing classref" end
        local refs=classref.Refs; local sizeof=classref.Sizeof; local name=bt.String(b)
        if string.byte(b:read(1,false))==0x1E then b:seek(1) end
        local typeID=string.byte(b:read()); local props={}
        if typeID==0x01 or typeID==0x1D then
            for i=1,sizeof do props[i]=bt.String(b) end
        elseif typeID==0x02 then
            for i=1,sizeof do props[i]=b:read()~=string.char(0) end
        elseif typeID==0x03 then props=bt.Int32Array(b,sizeof)
        elseif typeID==0x04 then props=bt.RbxF32Array(b,sizeof)
        elseif typeID==0x05 then
            for i=1,sizeof do props[i]=bt.Float64(b) end
        else
            for i=1,sizeof do if typeID==0x13 then props=bt.RefArray(b,sizeof); break else b:read(4) end end
        end
        if name=="Source" or name=="ContentText" then
            for i,v in ipairs(refs) do if virtualInstances[v] and props[i] then virtualInstances[v].Properties[name]=props[i] end end
        end
    end

    for _,chunk in ipairs(chunkInfo["PRNT"] or {}) do
        local b=chunk.Data
        if b:read()~=string.char(0) then return sources,"Invalid PRNT" end
        local count=b:readNumber("<I4")
        local child_refs=bt.RefArray(b,count); local parent_refs=bt.RefArray(b,count)
        for i=1,count do
            local child=virtualInstances[child_refs[i]]; local par=virtualInstances[parent_refs[i]]
            if child and par then table.insert(par.Children,child) end
        end
    end

    local function buildSourceMap(node,path)
        local src=node.Properties["Source"] or node.Properties["ContentText"]
        if src and type(src)=="string" and #src>0 then sources[path]=src end
        for _,child in ipairs(node.Children or {}) do buildSourceMap(child,path.."."..child.ClassName..":"..(child.Properties["Name"] or "unnamed")) end
    end

    local roots={}
    for _,inst in pairs(virtualInstances) do
        local hasParent=false
        for _,other in pairs(virtualInstances) do
            for _,child in ipairs(other.Children or {}) do if child.Ref==inst.Ref then hasParent=true; break end end
            if hasParent then break end
        end
        if not hasParent then table.insert(roots,inst) end
    end
    for _,root in ipairs(roots) do buildSourceMap(root,root.ClassName..":"..(root.Properties["Name"] or "root")) end
    return sources,nil
end

--==============================================================
-- STUDIO LITE INTEGRATION
--==============================================================

local slFolder     = ReplicatedStorage:FindFirstChild("StudioLiteFolder")
local serverFuncs  = slFolder and slFolder:FindFirstChild("ServerFunctions")
local SL_CACHE     = {}

local function triggerServerLoad(idStr)
    if not serverFuncs or not idStr or idStr=="" then return end
    local id=tostring(idStr):match("%d+")
    if id then pcall(function() serverFuncs:InvokeServer("LoadMeshToRuntimeMeshes",tonumber(id)) end) end
end

local function injectStudioLiteUI(scr,sourceMap)
    if not scr:IsA("LuaSourceContainer") then return end
    local path=scr.ClassName..":"..scr.Name
    local realSource=sourceMap and sourceMap[path]
    if not realSource then pcall(function() realSource=scr.Source end) end
    if realSource and #realSource>0 then realSource=realSource:gsub(string.char(0).."*$","") else realSource="-- [LANGZ] Source tidak ditemukan." end
    _G.LANGZ_RAW_SOURCES[scr]=realSource
    local UI_TEXT=realSource
    if #UI_TEXT>150000 then UI_TEXT="-- [LANGZ Warning] Source terlalu panjang.\n\n"..string.sub(UI_TEXT,1,150000).."\n\n... [TERPOTONG]" end
    local existingTB=scr:FindFirstChild("SL_CodeTextBox")
    if existingTB then
        existingTB.Text=UI_TEXT
        if scr.ClassName=="ModuleScript" then local ro=scr:FindFirstChild("SL_1ReadOnly"); if ro then ro.ContentText=UI_TEXT; ro.Text=UI_TEXT end end
        return
    end
    if not serverFuncs then return end
    local map={Script="InsertScriptScript",LocalScript="InsertLocalScriptLocalScript",ModuleScript="InsertModuleScriptModuleScript"}
    local assetName=map[scr.ClassName]
    if not assetName then return end
    if not SL_CACHE[assetName] then
        pcall(function()
            serverFuncs:InvokeServer("LoadAssetToPlayerGui",assetName)
            local guiF=player:WaitForChild("PlayerGui"):WaitForChild(assetName,3)
            if guiF then
                SL_CACHE[assetName]={}
                for _,c in ipairs(guiF:GetChildren()) do table.insert(SL_CACHE[assetName],c:Clone()) end
                serverFuncs:InvokeServer("ClearAssetFromPlayerGui",assetName)
            end
        end)
    end
    if not SL_CACHE[assetName] then return end
    pcall(function()
        for _,c in ipairs(SL_CACHE[assetName]) do c:Clone().Parent=scr end
        local tb=scr:FindFirstChild("SL_CodeTextBox")
        if tb then
            tb.Text=UI_TEXT
            if scr.ClassName=="ModuleScript" then local ro=scr:FindFirstChild("SL_1ReadOnly"); if ro then ro.ContentText=UI_TEXT; ro.Text=UI_TEXT end end
        end
    end)
end

local function injectAllScripts(root,sourceMap)
    if not root then return 0 end
    local list={}
    if root:IsA("LuaSourceContainer") then table.insert(list,root) end
    for _,d in ipairs(root:GetDescendants()) do if d:IsA("LuaSourceContainer") then table.insert(list,d) end end
    local count=0
    for _,s in ipairs(list) do pcall(injectStudioLiteUI,s,sourceMap); count=count+1; task.wait(0.02) end
    return count
end

local function ApplyStudioLiteProperties(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("BasePart") then
            local oa=obj.Anchored; local oc=obj.CanCollide
            obj.Anchored=true
            if obj:GetAttribute("SL_Anchored")==nil then obj:SetAttribute("SL_Anchored",oa) end
            if obj:GetAttribute("SL_CanCollide")==nil then obj:SetAttribute("SL_CanCollide",oc) end
        end
    end)
    for _,child in ipairs(obj:GetChildren()) do ApplyStudioLiteProperties(child) end
end

local function LoadAssetsToSLServer(obj)
    local function scan(node)
        pcall(function()
            if node:IsA("MeshPart") then triggerServerLoad(node.MeshId); triggerServerLoad(node.TextureID)
            elseif node:IsA("Decal") or node:IsA("Texture") then triggerServerLoad(node.Texture)
            elseif node:IsA("SpecialMesh") then triggerServerLoad(node.MeshId); triggerServerLoad(node.TextureId)
            elseif node:IsA("Clothing") or node:IsA("ShirtGraphic") then triggerServerLoad(node.ClassName=="ShirtGraphic" and node.Graphic or node[node.ClassName.."Template"])
            elseif node:IsA("UnionOperation") or node:IsA("PartOperation") then triggerServerLoad(node.AssetId) end
        end)
        for _,child in ipairs(node:GetChildren()) do scan(child) end
    end
    scan(obj)
end

local SVC_MAP={
    Workspace=workspace,ReplicatedStorage=ReplicatedStorage,
    ReplicatedFirst=game:GetService("ReplicatedFirst"),
    StarterGui=game:GetService("StarterGui"),StarterPack=game:GetService("StarterPack"),
    StarterPlayer=game:GetService("StarterPlayer"),Lighting=game:GetService("Lighting"),
    SoundService=game:GetService("SoundService"),
    ServerScriptService=_G.sss or ReplicatedStorage,ServerStorage=_G.ss or ReplicatedStorage,
    Teams=ReplicatedStorage,Chat=ReplicatedStorage
}

local function insertObjects(objects,isRbxl,sourceMap)
    local count=0
    for _,obj in ipairs(objects) do
        pcall(function()
            local target=(isRbxl and (SVC_MAP[obj.ClassName] or SVC_MAP[obj.Name])) or workspace
            if target==workspace and obj:IsA("Service") then target=ReplicatedStorage end
            if isRbxl and target~=workspace then
                for _,ch in ipairs(obj:GetChildren()) do
                    pcall(function() ch.Parent=target; injectAllScripts(ch,sourceMap); ApplyStudioLiteProperties(ch); LoadAssetsToSLServer(ch); count=count+1 end)
                    task.wait(0.01)
                end
            else
                obj.Parent=target; injectAllScripts(obj,sourceMap); ApplyStudioLiteProperties(obj); LoadAssetsToSLServer(obj); count=count+1
            end
        end)
    end
    return count
end

--==============================================================
-- HTTP REQUEST UTILITY  (dari v62 — fallback loader via asset URL)
--==============================================================

local function httpRequest(url, method, headers, data)
    method  = method  or "GET"
    headers = headers or {}
    headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    local requestFuncs = {
        function() if syn and syn.request then local r=syn.request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body,r.StatusCode end end,
        function() if request then local r=request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body,r.StatusCode end end,
        function() if http_request then local r=http_request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body,r.StatusCode end end,
        function() if fluxus and fluxus.request then local r=fluxus.request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body,r.StatusCode end end,
        function() return game:HttpGet(url,true),200 end
    }
    for _,fn in ipairs(requestFuncs) do
        local ok,body,status=pcall(fn)
        if ok and body and type(body)=="string" and #body>0 then return body,status or 200 end
    end
    return nil,nil
end

--==============================================================
-- FILE LOADER  (getcustomasset → rbxasset:// → loadrbxm/x → httpRequest fallback)
-- FIX: menggunakan fileInfo.type (bukan fileInfo.ftype) agar match
-- dengan field yang di-set oleh scanner: { type=ext }
--==============================================================

local function loadFile(fileInfo)
    -- PERBAIKAN UTAMA: scanner menyimpan field "type", bukan "ftype"
    -- fileInfo.ftype selalu nil → isRbxl selalu false → file tidak dimuat benar
    local ftype  = fileInfo.type or fileInfo.ftype or ""
    local isRbxl = (ftype == "RBXL")

    if not readfile then return false, "readfile() tidak tersedia" end
    local ok, data = pcall(readfile, fileInfo.path)
    if not ok or type(data) ~= "string" or #data == 0 then
        return false, "readfile gagal: " .. tostring(data)
    end

    -- Parse source map untuk inject script source ke SL_CodeTextBox
    local sourceMap = {}
    if not isRbxl then
        local parseOk, sources = pcall(parseRBXMForSources, data)
        if parseOk and sources then sourceMap = sources end
    end

    -- Method 1: getcustomasset (Delta primary API)
    if getcustomasset then
        local ok1, aid = pcall(getcustomasset, fileInfo.path)
        if ok1 and aid then
            local ok2, objs = pcall(function() return game:GetObjects(aid) end)
            if ok2 and objs and #objs > 0 then
                return true, insertObjects(objs, isRbxl, sourceMap) .. " object(s) loaded via getcustomasset"
            end
        end
    end

    -- Method 2: rbxasset:// direct path
    local ok3, objs3 = pcall(function() return game:GetObjects("rbxasset://" .. fileInfo.path) end)
    if ok3 and objs3 and #objs3 > 0 then
        return true, insertObjects(objs3, isRbxl, sourceMap) .. " object(s) loaded via rbxasset"
    end

    -- Method 3: loadrbxmx / loadrbxm executor API
    if ftype == "RBXMX" or ftype == "RBXL" or ftype == "RBXLX" then
        local fn = getFn("loadrbxmx") or getFn("loadasset")
        if fn then
            local ok4, model = pcall(fn, data)
            if ok4 and model then
                pcall(function() model.Parent = workspace end)
                injectAllScripts(model, sourceMap)
                ApplyStudioLiteProperties(model)
                LoadAssetsToSLServer(model)
                return true, "1 object(s) loaded via loadrbxmx"
            end
        end
        -- XML validation fallback
        if data:find("<roblox", 1, true) then
            return false, "RBXMX/RBXLX valid tapi tidak ada API insert tersedia di executor ini"
        end
        return false, "RBXMX/RBXLX invalid atau corrupt"
    else
        -- RBXM binary
        local fn = getFn("loadrbxm") or getFn("readrbxm")
        if fn then
            local ok5, model = pcall(fn, data)
            if ok5 and model then
                pcall(function() model.Parent = workspace end)
                injectAllScripts(model, sourceMap)
                ApplyStudioLiteProperties(model)
                LoadAssetsToSLServer(model)
                return true, "1 object(s) loaded via loadrbxm"
            end
        end

        -- Method 4: httpRequest fallback — coba load binary data langsung via HTTP workaround
        -- Berguna di executor yang support request() tapi bukan getcustomasset
        local assetId = fileInfo.path:match("(%d+)") or ""
        if #assetId > 0 then
            local body, status = httpRequest(
                "https://assetdelivery.roblox.com/v1/asset/?id=" .. assetId,
                "GET", {}
            )
            if body and #body > 0 then
                local okH, objsH = pcall(function() return game:GetObjects("rbxassetid://" .. assetId) end)
                if okH and objsH and #objsH > 0 then
                    return true, insertObjects(objsH, isRbxl, sourceMap) .. " object(s) loaded via httpRequest+rbxassetid"
                end
            end
        end

        return false, "RBXM: semua metode load gagal. getcustomasset=" .. (getcustomasset and "✓" or "✕")
            .. "  loadrbxm=" .. (getFn("loadrbxm") and "✓" or "✕")
            .. "  readfile=" .. (readfile and "✓" or "✕")
            .. "  ftype=" .. tostring(ftype)
    end
end

--==============================================================
-- FILE SCANNER  (deep recursive, banyak path root)
--==============================================================

local files = {}

local ROOT_PATHS = {
    "Delta/Workspace", "Delta/Workspace/",
    "delta/workspace", "delta/workspace/",
    "Android/Delta/Workspace", "Android/Delta/Workspace/",
    "/sdcard/Delta/Workspace", "/sdcard/Android/Delta/Workspace",
    "workspace", "workspace/",
    "Workspace", "Workspace/",
    "../workspace", ".", ""
}

local function normPath(p)
    p = tostring(p or ""):gsub("\\","/")
    while p:find("//",1,true) do p = p:gsub("//","/") end
    if p:sub(-1)=="/" then p = p:sub(1,-2) end
    return p
end

local function getFileName(p)
    return normPath(p):match("([^/]+)$") or p
end

local function getFileType(name)
    local n = name:lower()
    -- RBXL family → RBXL
    if n:match("%.rbxl$") or n:match("%.rbxlx$") then return "RBXL" end
    -- RBXMX (XML) dipisah dari RBXM (binary) agar filter bar "RBXMX" bekerja
    if n:match("%.rbxmx$") then return "RBXMX" end
    if n:match("%.rbxm$")  then return "RBXM"  end
    return nil
end

local function looksLikeFolder(p)
    return not getFileName(p):match("%.[%a%d]+$")
end

local function safeList(p)
    if not listfiles then return nil end
    local ok, r = pcall(listfiles, p)
    return (ok and type(r)=="table") and r or nil
end

local function walkDir(path, depth, results, seen)
    if depth > 6 then return end
    local np = normPath(path)
    if seen[np] then return end
    seen[np] = true
    local items = safeList(path)
    if not items then return end
    local batch = 0
    for _, raw in ipairs(items) do
        batch = batch + 1
        if batch % 20 == 0 then task.wait() end  -- yield tiap 20 item, cegah freeze
        local p   = normPath(raw)
        local ext = getFileType(getFileName(p))
        if ext then
            local key = p:lower()
            if not seen[key] then
                local valid = true
                if isfile then
                    local ok2, val = pcall(isfile, p)
                    if ok2 and val == false then valid = false end
                end
                if valid then
                    seen[key] = true
                    table.insert(results, { name=getFileName(p), path=p, type=ext })
                end
            end
        else
            -- Check subfolder
            local isDir = false
            if isfolder then
                local ok3, val = pcall(isfolder, p); if ok3 and val then isDir = true end
            end
            if not isDir then
                local sub = safeList(p); if sub then isDir = true end
            end
            if isDir or looksLikeFolder(p) then
                walkDir(p, depth+1, results, seen)
            end
        end
    end
end

local function scan()
    files = {}
    if not listfiles then return false, "listfiles() tidak tersedia di executor ini" end
    local seen    = {}
    local results = {}
    local usedPath = nil
    for _, root in ipairs(ROOT_PATHS) do
        task.wait()  -- yield antar root agar tidak freeze
        local items = safeList(root)
        if items then
            if not usedPath then usedPath = root end
            walkDir(root, 0, results, seen)
        end
    end
    table.sort(results, function(a,b) return a.name:lower() < b.name:lower() end)
    files = results
    return true, nil, usedPath
end

--==============================================================
-- HOOKS — Anti-Putus Studio Lite (dari v62, lengkap)
--==============================================================

task.spawn(function()
    if getFn("hookmetamethod") then
        local hookmetamethod = getFn("hookmetamethod")
        local getnamecallmethod = getFn("getnamecallmethod")
        local checkcaller = getFn("checkcaller")
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args = {...}
            if checkcaller and not checkcaller() and method == "InvokeServer" then
                if self.Name == "GetScriptSourceServerFunction" then
                    local target = tostring(args[1])
                    for obj, src in pairs(_G.LANGZ_RAW_SOURCES) do
                        if typeof(obj)=="Instance" and (obj.ClassName..obj.Name)==target then
                            if src and src~="" then return src end
                        end
                    end
                    for _, place in ipairs({workspace, ReplicatedStorage, _G.sss, _G.ss, game:GetService("StarterGui"), game:GetService("StarterPlayer"), player:FindFirstChild("PlayerGui"), player:FindFirstChild("Backpack")}) do
                        if place then
                            for _, obj in ipairs(place:GetDescendants()) do
                                if obj:IsA("LuaSourceContainer") and (obj.ClassName..obj.Name)==target then
                                    local src=_G.LANGZ_RAW_SOURCES[obj]
                                    if src and src~="" then return src end
                                end
                            end
                        end
                    end
                end
                if self.Name=="SaveScriptSourceServerFunction" then
                    local target=tostring(args[1]); local newSource=tostring(args[2])
                    for obj,_ in pairs(_G.LANGZ_RAW_SOURCES) do
                        if typeof(obj)=="Instance" and (obj.ClassName..obj.Name)==target then _G.LANGZ_RAW_SOURCES[obj]=newSource; break end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end

    if getFn("hookfunction") then
        local hookfunction = getFn("hookfunction")
        local getrenv      = getFn("getrenv")

        local oldRequire
        pcall(function()
            oldRequire = hookfunction((getrenv and getrenv() or {}).require or require, function(module)
                if typeof(module)=="Instance" and module:IsA("ModuleScript") then
                    local src=_G.LANGZ_RAW_SOURCES[module]
                    if src and src~="" then
                        local func,err=loadstring(src)
                        if func then local success,result=pcall(func); if success then return result end end
                    end
                end
                return oldRequire(module)
            end)
        end)

        local oldGetObjects
        pcall(function()
            oldGetObjects = hookfunction(game.GetObjects, function(self, url, ...)
                local assetId=tostring(url):match("%d+"); if assetId then triggerServerLoad(assetId) end
                local objects=oldGetObjects(self,url,...)
                if objects then
                    for _,obj in ipairs(objects) do
                        pcall(function() injectAllScripts(obj,{}) end)
                        pcall(function() ApplyStudioLiteProperties(obj) end)
                        pcall(function() LoadAssetsToSLServer(obj) end)
                    end
                end
                return objects
            end)
        end)

        local oldLoadAsset
        pcall(function()
            oldLoadAsset = hookfunction(InsertService.LoadAsset, function(self, assetId, ...)
                triggerServerLoad(tostring(assetId))
                local obj=oldLoadAsset(self,assetId,...)
                if obj then
                    pcall(function() injectAllScripts(obj,{}) end)
                    pcall(function() ApplyStudioLiteProperties(obj) end)
                    pcall(function() LoadAssetsToSLServer(obj) end)
                end
                return obj
            end)
        end)
    end
end)

--==============================================================
-- UI HELPERS
--==============================================================

local function New(class, props, par)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do pcall(function() o[k] = v end) end
    o.Parent = par
    return o
end

local function Corner(o, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o)
end

local RAINBOW_SEQ = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0,   105)),
    ColorSequenceKeypoint.new(0.14, Color3.fromRGB(255, 60,  0  )),
    ColorSequenceKeypoint.new(0.28, Color3.fromRGB(255, 220, 0  )),
    ColorSequenceKeypoint.new(0.42, Color3.fromRGB(0,   255, 135)),
    ColorSequenceKeypoint.new(0.57, Color3.fromRGB(0,   205, 255)),
    ColorSequenceKeypoint.new(0.71, Color3.fromRGB(55,  90,  255)),
    ColorSequenceKeypoint.new(0.85, Color3.fromRGB(185, 0,   255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0,   105))
})

local rainbowGradients = {}
local function trackGradient(g, offset)
    table.insert(rainbowGradients, { g=g, offset=offset or 0 })
    return g
end

local function RainbowBorder(o, thickness, offset)
    local s = New("UIStroke", { Thickness=thickness or 2, Transparency=0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border }, o)
    local g = New("UIGradient", { Rotation=0, Color=RAINBOW_SEQ }, s)
    trackGradient(g, offset or 0)
    return s, g
end

local function RainbowText(label, offset)
    local g = New("UIGradient", { Rotation=0, Color=RAINBOW_SEQ }, label)
    trackGradient(g, offset or 30)
    return g
end

local function Stroke(o, thickness, transparency)
    return New("UIStroke", { Thickness=thickness or 1, Transparency=transparency or 0.05, ApplyStrokeMode=Enum.ApplyStrokeMode.Border }, o)
end

local WHITE  = Color3.fromRGB(245, 245, 250)
local WHITE2 = Color3.fromRGB(220, 220, 228)
local BLACK  = Color3.fromRGB(5,   5,   8  )
local CARD   = Color3.fromRGB(14,  14,  19 )

--==============================================================
-- GUI ROOT
--==============================================================

local gui = New("ScreenGui", {
    Name="LANGZ_IMPORTER_V001", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
}, parent)

local uiScale = New("UIScale", { Scale=1 }, gui)
local function updateResponsive()
    local cam=workspace.CurrentCamera; if not cam then return end
    local v=cam.ViewportSize; local scale=1
    if v.X<900 then scale=math.clamp(v.X/760,0.72,1) end
    if v.Y<650 then scale=math.min(scale,v.Y/650) end
    uiScale.Scale=math.clamp(scale,0.70,1)
end
updateResponsive()
pcall(function() workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive) end)

--==============================================================
-- MAIN PANEL
--==============================================================

local main = New("Frame", {
    Name="Main", Size=UDim2.fromOffset(350,460),
    Position=UDim2.new(0.5,-175,0.5,-230),
    BackgroundColor3=BLACK, BorderSizePixel=0,
    ClipsDescendants=false, Active=true, ZIndex=10
}, gui)
Corner(main, 17)
RainbowBorder(main, 2.2, 0)

local inner = New("Frame", {
    Size=UDim2.new(1,-6,1,-6), Position=UDim2.fromOffset(3,3),
    BackgroundTransparency=1, BorderSizePixel=0, ZIndex=11
}, main)
Corner(inner, 14); Stroke(inner, 0.7, 0.55)

-- HEADER
local drag = New("Frame", {
    Size=UDim2.new(1,-100,0,70), Position=UDim2.fromOffset(12,5),
    BackgroundTransparency=1, Active=true, ZIndex=20
}, main)

local title = New("TextLabel", {
    Size=UDim2.new(1,0,0,28), Position=UDim2.fromOffset(0,3),
    BackgroundTransparency=1, Text="LANGZ IMPORTER V00.1",
    TextColor3=WHITE, TextSize=18, Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=21
}, drag)
RainbowText(title, 30)

New("TextLabel", {
    Size=UDim2.new(1,0,0,17), Position=UDim2.fromOffset(0,33),
    BackgroundTransparency=1, Text="Original Founder: ItsmeeLangzz x H2C 👑",
    TextColor3=WHITE2, TextSize=8, Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=21
}, drag)

local status = New("TextLabel", {
    Size=UDim2.new(1,0,0,16), Position=UDim2.fromOffset(0,50),
    BackgroundTransparency=1, Text="INITIALIZING...",
    TextColor3=WHITE2, TextSize=8, Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=21
}, drag)

-- TOP BUTTONS
local function SmallTopButton(text, x)
    local b = New("TextButton", {
        Size=UDim2.fromOffset(38,30), Position=UDim2.new(1,x,0,12),
        BackgroundColor3=Color3.fromRGB(15,15,20), BorderSizePixel=0,
        Text=text, TextColor3=WHITE, TextSize=10, Font=Enum.Font.GothamBold,
        AutoButtonColor=false, ZIndex=25
    }, main)
    Corner(b,9); RainbowBorder(b,1,60); return b
end
local outputToggle = SmallTopButton("▣", -84)
local sizeToggle   = SmallTopButton("↔", -43)

-- SEARCH
local searchFrame = New("Frame", {
    Size=UDim2.new(1,-30,0,36), Position=UDim2.fromOffset(15,84),
    BackgroundColor3=Color3.fromRGB(12,12,17), BorderSizePixel=0, ZIndex=12
}, main)
Corner(searchFrame,10); Stroke(searchFrame,0.8,0.25)

local search = New("TextBox", {
    Size=UDim2.new(1,-20,1,0), Position=UDim2.fromOffset(10,0),
    BackgroundTransparency=1, PlaceholderText="Search models...",
    PlaceholderColor3=Color3.fromRGB(125,125,140), Text="",
    TextColor3=WHITE, TextSize=10, Font=Enum.Font.GothamMedium,
    ClearTextOnFocus=false, ZIndex=13
}, searchFrame)

-- FILTER BAR
local filterBar = New("Frame", {
    Size=UDim2.new(1,-30,0,30), Position=UDim2.fromOffset(15,126),
    BackgroundTransparency=1, ZIndex=12
}, main)
New("UIListLayout", { FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,6), VerticalAlignment=Enum.VerticalAlignment.Center }, filterBar)

local currentFilter = "ALL"
local function FilterButton(name, width)
    local b = New("TextButton", {
        Size=UDim2.fromOffset(width,28), BackgroundColor3=Color3.fromRGB(15,15,20),
        BorderSizePixel=0, Text=name, TextColor3=WHITE2, TextSize=8,
        Font=Enum.Font.GothamBold, AutoButtonColor=false, ZIndex=13
    }, filterBar)
    Corner(b,8); Stroke(b,0.8,0.35)
    b.MouseButton1Click:Connect(function()
        currentFilter=name
        for _,x in ipairs(filterBar:GetChildren()) do
            if x:IsA("TextButton") then x.BackgroundColor3=Color3.fromRGB(15,15,20); x.TextColor3=WHITE2 end
        end
        b.BackgroundColor3=Color3.fromRGB(34,34,43); b.TextColor3=WHITE
        if _G.LANGZ_REFRESH_LIBRARY then _G.LANGZ_REFRESH_LIBRARY() end
    end)
    return b
end
local allButton = FilterButton("ALL",48); FilterButton("RBXM",58); FilterButton("RBXMX",68); FilterButton("RBXL",55)
allButton.BackgroundColor3=Color3.fromRGB(34,34,43); allButton.TextColor3=WHITE

-- LIBRARY FRAME
local library = New("Frame", {
    Size=UDim2.new(1,-30,1,-216), Position=UDim2.fromOffset(15,163),
    BackgroundColor3=Color3.fromRGB(8,8,12), BorderSizePixel=0, ZIndex=12
}, main)
Corner(library,13); Stroke(library,0.8,0.35)

New("TextLabel", {
    Size=UDim2.new(1,-120,0,25), Position=UDim2.fromOffset(10,7),
    BackgroundTransparency=1, Text="RBXM / RBXMX LIBRARY",
    TextColor3=WHITE, TextSize=9, Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=14
}, library)

local count = New("TextLabel", {
    Size=UDim2.fromOffset(100,20), Position=UDim2.new(1,-110,0,8),
    BackgroundTransparency=1, Text="0 FILES", TextColor3=WHITE2,
    TextSize=8, Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Right, ZIndex=14
}, library)

local scroll = New("ScrollingFrame", {
    Size=UDim2.new(1,-12,1,-42), Position=UDim2.fromOffset(6,36),
    BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=2,
    ScrollBarImageTransparency=0.25, AutomaticCanvasSize=Enum.AutomaticSize.Y,
    Active=true, ZIndex=13
}, library)
New("UIListLayout", { Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder }, scroll)

local empty = New("TextLabel", {
    Size=UDim2.new(1,-20,0,80), Position=UDim2.new(0.5,-155,0.5,-20),
    BackgroundTransparency=1, Text="NO MODELS FOUND\n\nDelta/Workspace/",
    TextColor3=WHITE2, TextSize=10, Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Center, TextYAlignment=Enum.TextYAlignment.Center,
    TextWrapped=true, ZIndex=15
}, library)

-- BOTTOM BUTTONS
local function BottomButton(text, size, pos)
    local b = New("TextButton", {
        Size=size, Position=pos,
        BackgroundColor3=Color3.fromRGB(15,15,20), BorderSizePixel=0,
        Text=text, TextColor3=WHITE, TextSize=8, Font=Enum.Font.GothamBold,
        AutoButtonColor=false, ZIndex=20
    }, main)
    Corner(b,9); Stroke(b,0.8,0.25); return b
end
local statusButton  = BottomButton("SYSTEM STATUS", UDim2.fromOffset(110,32), UDim2.fromOffset(15,416))
local refreshButton = BottomButton("REFRESH",       UDim2.fromOffset(90,32),  UDim2.new(1,-105,0,416))

--==============================================================
-- OUTPUT PANEL
--==============================================================

local outputPanel = New("Frame", {
    Name="OutputPanel", Size=UDim2.fromOffset(285,460),
    Position=UDim2.new(0.5,190,0.5,-230),
    BackgroundColor3=BLACK, BorderSizePixel=0, Visible=false, ZIndex=40
}, gui)
Corner(outputPanel,17); RainbowBorder(outputPanel,2.0,80)

local outputHeader = New("TextLabel", {
    Size=UDim2.new(1,-25,0,30), Position=UDim2.fromOffset(13,12),
    BackgroundTransparency=1, Text="LANGZ OUTPUT", TextColor3=WHITE,
    TextSize=15, Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=42
}, outputPanel)
RainbowText(outputHeader, 110)

New("TextLabel", {
    Size=UDim2.new(1,-25,0,20), Position=UDim2.fromOffset(13,38),
    BackgroundTransparency=1, Text="LIVE IMPORTER LOG", TextColor3=WHITE2,
    TextSize=8, Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=42
}, outputPanel)

local clearLogBtn = New("TextButton", {
    Size=UDim2.new(1,-22,0,28), Position=UDim2.new(0,11,1,-38),
    BackgroundColor3=Color3.fromRGB(15,15,20), BorderSizePixel=0,
    Text="🗑  CLEAR OUTPUT", TextColor3=WHITE, TextSize=8,
    Font=Enum.Font.GothamBold, AutoButtonColor=false, ZIndex=45
}, outputPanel)
Corner(clearLogBtn,9); Stroke(clearLogBtn,0.8,0.25)

local outputScroll = New("ScrollingFrame", {
    Size=UDim2.new(1,-22,1,-78), Position=UDim2.fromOffset(11,66),
    BackgroundColor3=Color3.fromRGB(8,8,12), BorderSizePixel=0,
    ScrollBarThickness=2, AutomaticCanvasSize=Enum.AutomaticSize.Y, ZIndex=41
}, outputPanel)
Corner(outputScroll,11); Stroke(outputScroll,0.8,0.3)
New("UIListLayout", { Padding=UDim.new(0,5), SortOrder=Enum.SortOrder.LayoutOrder }, outputScroll)

local outputLogs = {}

local function RebuildOutputCards()
    for _,child in ipairs(outputScroll:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    for _,item in ipairs(outputLogs) do
        local card = New("Frame", { Size=UDim2.new(1,-10,0,48), BackgroundColor3=Color3.fromRGB(13,13,18), BorderSizePixel=0, ZIndex=43 }, outputScroll)
        Corner(card,8); Stroke(card,0.6,0.45)
        New("TextLabel", { Size=UDim2.new(1,-12,0,16), Position=UDim2.fromOffset(7,4), BackgroundTransparency=1, Text="["..item.time.."]  "..item.kind, TextColor3=WHITE, TextSize=8, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=44 }, card)
        New("TextLabel", { Size=UDim2.new(1,-12,0,24), Position=UDim2.fromOffset(7,20), BackgroundTransparency=1, Text=item.message, TextColor3=WHITE2, TextSize=8, Font=Enum.Font.GothamMedium, TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, ZIndex=44 }, card)
    end
    task.defer(function()
        outputScroll.CanvasPosition=Vector2.new(0,math.max(0,outputScroll.AbsoluteCanvasSize.Y-outputScroll.AbsoluteWindowSize.Y))
    end)
end

local function AddOutput(kind, message)
    table.insert(outputLogs, { kind=tostring(kind), message=tostring(message), time=os.date("%H:%M:%S") })
    if #outputLogs>80 then table.remove(outputLogs,1) end
    RebuildOutputCards()
end

clearLogBtn.MouseButton1Click:Connect(function()
    outputLogs={}; RebuildOutputCards(); AddOutput("INFO","Log cleared.")
end)

--==============================================================
-- SIZE PANEL  (no rainbow, center on open)
--==============================================================

local sizePanel = New("Frame", {
    Name="SizeControl", Size=UDim2.fromOffset(300,245),
    Position=UDim2.new(0.5,-150,0.5,-122),
    BackgroundColor3=BLACK, BorderSizePixel=0, Visible=false, ZIndex=50
}, gui)
Corner(sizePanel,17); Stroke(sizePanel,1.5,0.2)

local sizeTitle = New("TextLabel", {
    Size=UDim2.new(1,-25,0,26), Position=UDim2.fromOffset(13,11),
    BackgroundTransparency=1, Text="ATUR UKURAN PANEL",
    TextColor3=WHITE, TextSize=13, Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=52
}, sizePanel)
New("TextLabel", {
    Size=UDim2.new(1,-25,0,17), Position=UDim2.fromOffset(13,38),
    BackgroundTransparency=1, Text="MAIN GUI • WIDTH / HEIGHT",
    TextColor3=WHITE2, TextSize=7, Font=Enum.Font.GothamMedium,
    TextXAlignment=Enum.TextXAlignment.Left, ZIndex=52
}, sizePanel)

local function Slider(labelText, y, minV, maxV, defV)
    New("TextLabel", { Size=UDim2.fromOffset(65,20), Position=UDim2.fromOffset(13,y-7), BackgroundTransparency=1, Text=labelText, TextColor3=WHITE, TextSize=8, Font=Enum.Font.GothamMedium, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=53 }, sizePanel)
    local track = New("Frame", { Size=UDim2.new(1,-95,0,10), Position=UDim2.fromOffset(80,y), BackgroundColor3=Color3.fromRGB(28,28,34), BorderSizePixel=0, Active=true, ZIndex=53 }, sizePanel)
    Corner(track,5); Stroke(track,0.8,0.3)
    local fill = New("Frame", { Size=UDim2.new((defV-minV)/(maxV-minV),0,1,0), BackgroundColor3=Color3.fromRGB(230,230,235), BorderSizePixel=0, ZIndex=54 }, track); Corner(fill,5)
    local knob = New("Frame", { Size=UDim2.fromOffset(16,16), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new((defV-minV)/(maxV-minV),0,0.5,0), BackgroundColor3=Color3.fromRGB(245,245,250), BorderSizePixel=0, Active=true, ZIndex=55 }, track); Corner(knob,8)
    local vLabel = New("TextLabel", { Size=UDim2.fromOffset(45,18), Position=UDim2.new(1,-48,0,-26), BackgroundTransparency=1, Text=tostring(defV), TextColor3=WHITE, TextSize=8, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Right, ZIndex=55 }, track)
    local dragging=false
    local function setFromX(x)
        local rel=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local val=math.floor(minV+(maxV-minV)*rel+0.5)
        fill.Size=UDim2.new(rel,0,1,0); knob.Position=UDim2.new(rel,0,0.5,0); vLabel.Text=tostring(val)
        return val
    end
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; local v=setFromX(inp.Position.X)
            if labelText=="Lebar" then main.Size=UDim2.fromOffset(v,main.Size.Y.Offset) else main.Size=UDim2.fromOffset(main.Size.X.Offset,v) end
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            local v=setFromX(inp.Position.X)
            if labelText=="Lebar" then main.Size=UDim2.fromOffset(v,main.Size.Y.Offset) else main.Size=UDim2.fromOffset(main.Size.X.Offset,v) end
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
end

Slider("Lebar", 82, 280, 520, 350)
Slider("Tinggi",137, 360, 700, 460)

local resetSize = New("TextButton", {
    Size=UDim2.new(1,-26,0,35), Position=UDim2.fromOffset(13,190),
    BackgroundColor3=Color3.fromRGB(15,15,20), BorderSizePixel=0,
    Text="RESET KE DEFAULT 350 × 460", TextColor3=WHITE,
    TextSize=8, Font=Enum.Font.GothamBold, AutoButtonColor=false, ZIndex=53
}, sizePanel)
Corner(resetSize,9); Stroke(resetSize,0.8,0.25)
resetSize.MouseButton1Click:Connect(function()
    main.Size=UDim2.fromOffset(350,460); AddOutput("SIZE","Main panel reset ke 350 × 460.")
end)

--==============================================================
-- DRAG SYSTEM
--==============================================================

local function MakeDraggable(handle, object)
    local dragging,dragStart,startPos,dragInput=false,nil,nil,nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=inp.Position; startPos=object.Position; dragInput=inp
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then dragInput=inp end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and inp==dragInput then
            local delta=inp.Position-dragStart
            object.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
end

MakeDraggable(drag,         main)
MakeDraggable(outputHeader, outputPanel)
MakeDraggable(sizeTitle,    sizePanel)

--==============================================================
-- FLOATING TOGGLE BUTTON 📁 (draggable, kiri layar)
--==============================================================

local panelVisible = true  -- main panel mulai visible

local floatBtn = New("TextButton", {
    Name        = "LANGZ_FloatToggle",
    Size        = UDim2.fromOffset(42, 42),
    Position    = UDim2.new(0, 12, 0.5, -21),  -- kiri tengah layar
    BackgroundColor3 = Color3.fromRGB(10, 10, 15),
    BorderSizePixel  = 0,
    Text        = "📁",
    TextSize    = 20,
    Font        = Enum.Font.GothamBold,
    AutoButtonColor = false,
    ZIndex      = 100,
    Active      = true,
}, gui)
Corner(floatBtn, 12)
RainbowBorder(floatBtn, 2, 200)

-- tooltip label kecil
local floatTip = New("TextLabel", {
    Size              = UDim2.fromOffset(72, 18),
    Position          = UDim2.fromOffset(46, 12),
    BackgroundColor3  = Color3.fromRGB(10, 10, 15),
    BorderSizePixel   = 0,
    Text              = "LANGZ",
    TextColor3        = WHITE2,
    TextSize          = 8,
    Font              = Enum.Font.GothamMedium,
    TextXAlignment    = Enum.TextXAlignment.Left,
    Visible           = false,
    ZIndex            = 99,
}, floatBtn)
Corner(floatTip, 6)

-- hover tooltip
floatBtn.MouseEnter:Connect(function()  floatTip.Visible = true  end)
floatBtn.MouseLeave:Connect(function()  floatTip.Visible = false end)

-- toggle panel utama (main + outputPanel + sizePanel)
floatBtn.MouseButton1Click:Connect(function()
    panelVisible = not panelVisible
    local tw = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    if panelVisible then
        main.Visible = true
        TweenService:Create(main, tw, { BackgroundTransparency = 0 }):Play()
        floatBtn.Text  = "📁"
    else
        TweenService:Create(main, tw, { BackgroundTransparency = 1 }):Play()
        task.delay(0.23, function() if not panelVisible then main.Visible = false end end)
        if outputPanel.Visible then outputPanel.Visible = false end
        if sizePanel.Visible   then sizePanel.Visible   = false end
        floatBtn.Text = "📂"
    end
end)

-- drag floatBtn
MakeDraggable(floatBtn, floatBtn)

--==============================================================
-- LIBRARY RENDER
--==============================================================

local function clearCards()
    for _,x in ipairs(scroll:GetChildren()) do if x:IsA("Frame") then x:Destroy() end end
end

local function makeCard(file)
    local card = New("Frame", {
        Size=UDim2.new(1,-2,0,58), BackgroundColor3=CARD, BorderSizePixel=0, ZIndex=14
    }, scroll)
    Corner(card,9); Stroke(card,0.7,0.3)

    New("TextLabel", {
        Size=UDim2.new(1,-105,0,22), Position=UDim2.fromOffset(10,6),
        BackgroundTransparency=1, Text="◇ "..file.name, TextColor3=WHITE,
        TextSize=9, Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, ZIndex=15
    }, card)
    New("TextLabel", {
        Size=UDim2.new(1,-105,0,18), Position=UDim2.fromOffset(11,29),
        BackgroundTransparency=1, Text=file.type.." • MODEL", TextColor3=WHITE2,
        TextSize=7, Font=Enum.Font.GothamMedium,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=15
    }, card)

    local insertBtn = New("TextButton", {
        Size=UDim2.fromOffset(70,30), Position=UDim2.new(1,-80,0.5,-15),
        BackgroundColor3=Color3.fromRGB(24,24,30), BorderSizePixel=0,
        Text="INSERT", TextColor3=WHITE, TextSize=8,
        Font=Enum.Font.GothamBold, AutoButtonColor=false, ZIndex=16
    }, card)
    Corner(insertBtn,8); RainbowBorder(insertBtn,1,120)

    insertBtn.MouseButton1Click:Connect(function()
        insertBtn.Text = "LOADING..."
        AddOutput("INFO", "Memuat: "..file.name.." ("..file.path..")")
        task.spawn(function()
            local ok, msg = loadFile(file)
            if ok then
                insertBtn.Text = "✓ DONE"
                status.Text = "LOADED: "..file.name
                AddOutput("SUCCESS", file.name.." — "..tostring(msg))
            else
                insertBtn.Text = "✕ FAIL"
                status.Text = "FAILED: "..file.name
                AddOutput("ERROR", file.name.." — "..tostring(msg))
            end
            task.wait(2)
            insertBtn.Text = "INSERT"
        end)
    end)
end

function _G.LANGZ_REFRESH_LIBRARY()
    clearCards()
    local visible=0; local query=search.Text:lower()
    for _,file in ipairs(files) do
        local filterOK=(currentFilter=="ALL" or file.type==currentFilter)
        local searchOK=(query=="" or file.name:lower():find(query,1,true)~=nil)
        if filterOK and searchOK then makeCard(file); visible=visible+1 end
    end
    count.Text=tostring(visible).." FILE"..(visible==1 and "" or "S")
    empty.Visible=(visible==0)
    if visible==0 then
        empty.Text=(#files==0) and "NO MODELS FOUND\n\nDelta/Workspace/" or "NO MATCHING MODELS\n\nTry another search/filter."
    end
end

--==============================================================
-- REFRESH / SCAN
--==============================================================

local function refresh()
    status.Text="SCANNING..."
    empty.Text="SCANNING...\n\nDelta/Workspace/"; empty.Visible=true
    AddOutput("INFO","Deep scan semua root path...")
    local ok, err, usedPath = scan()
    if not ok then
        status.Text="FILESYSTEM ERROR"; empty.Text="FILESYSTEM ERROR\n\n"..tostring(err)
        AddOutput("ERROR", tostring(err)); return
    end
    _G.LANGZ_REFRESH_LIBRARY()
    status.Text="READY • "..#files.." MODEL(S)"
    if #files>0 then
        AddOutput("SUCCESS","Found "..#files.." file(s).")
        if usedPath then AddOutput("INFO","Root path: "..tostring(usedPath)) end
        for _,f in ipairs(files) do AddOutput("FILE",f.type.." → "..f.path) end
    else
        AddOutput("WARNING","Tidak ada RBXM/RBXMX terdeteksi.")
        AddOutput("INFO","Pastikan file ada di Delta/Workspace/")
        AddOutput("INFO","listfiles() "..(listfiles and "✓ tersedia" or "✕ TIDAK ADA — executor tidak support"))
        AddOutput("INFO","readfile()  "..(readfile  and "✓ tersedia" or "✕ TIDAK ADA"))
    end
end

refreshButton.MouseButton1Click:Connect(refresh)
search:GetPropertyChangedSignal("Text"):Connect(function()
    if _G.LANGZ_REFRESH_LIBRARY then _G.LANGZ_REFRESH_LIBRARY() end
end)

--==============================================================
-- SYSTEM STATUS
--==============================================================

statusButton.MouseButton1Click:Connect(function()
    AddOutput("SYSTEM STATUS", table.concat({
        "LANGZ IMPORTER V00.1","",
        "listfiles()      "..(listfiles         and "✓" or "✕"),
        "readfile()       "..(readfile          and "✓" or "✕"),
        "isfile()         "..(isfile            and "✓" or "✕"),
        "isfolder()       "..(isfolder          and "✓" or "✕"),
        "getcustomasset() "..(getcustomasset    and "✓" or "✕"),
        "hookmetamethod() "..(getFn("hookmetamethod") and "✓" or "✕"),
        "hookfunction()   "..(getFn("hookfunction")   and "✓" or "✕"),
        "loadrbxmx()      "..(getFn("loadrbxmx")      and "✓" or "✕"),
        "loadrbxm()       "..(getFn("loadrbxm")       and "✓" or "✕"),
        "","Files found: "..#files,"SOURCE: READ ONLY ✓"
    },"\n"))
    status.Text="SYSTEM STATUS"
end)

--==============================================================
-- TOGGLE PANELS
--==============================================================

outputToggle.MouseButton1Click:Connect(function()
    outputPanel.Visible=not outputPanel.Visible
    if outputPanel.Visible then AddOutput("INFO","Output panel opened.") end
end)

sizeToggle.MouseButton1Click:Connect(function()
    sizePanel.Visible=not sizePanel.Visible
    if sizePanel.Visible then
        local cam=workspace.CurrentCamera
        if cam then
            local v=cam.ViewportSize
            sizePanel.Position=UDim2.fromOffset(math.floor(v.X/2-150),math.floor(v.Y/2-122))
        end
        AddOutput("INFO","Size Control opened.")
    end
end)

--==============================================================
-- RAINBOW ANIMATION LOOP
--==============================================================

task.spawn(function()
    local rot=0
    while gui.Parent do
        rot=(rot+0.75)%360
        pcall(function()
            for _,e in ipairs(rainbowGradients) do e.g.Rotation=(rot+e.offset)%360 end
        end)
        task.wait(0.03)
    end
end)

--==============================================================
-- STARTUP
--==============================================================

main.BackgroundTransparency=1
TweenService:Create(main,TweenInfo.new(0.35,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency=0}):Play()

AddOutput("SYSTEM","LANGZ IMPORTER V00.1 initialized.")
AddOutput("INFO","Source: Delta/Workspace/")
AddOutput("INFO","Supported: RBXM + RBXMX + RBXL + RBXLX")

task.spawn(refresh)

print("LANGZ IMPORTER V00.1 loaded — Source: Delta/Workspace/ — RBXM + RBXMX + RBXL + RBXLX")
