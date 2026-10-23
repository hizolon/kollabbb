--[[
    invisibility_bundle.lua
    Target: Roblox / Luau executor (Synapse, Fluxus, Delta, Xeno, Wave ...)
    Один файл, всё внутри.

    Что делает:
      1) Если USE_RAW = true — перехватывает buffer.fromstring и складывает
         реальный Luraph-байткод из gB в luraph_payload.bin.
         Потом запускает оригинальный обфусцированный файл и печатает ошибку,
         если он падает (а он упадёт — там сломанный вызов :HB()).
      2) В любом случае работает рабочий клиентский invisibility для LocalPlayer.

    Управление после загрузки:
      _G.Inv:toggle()               -- вкл/выкл
      _G.Inv:set_invisible(true)    -- принудительно вкл
      _G.Inv:set_invisible(false)   -- принудительно выкл
      _G.Inv:dump()                 -- повторный дамп обфусцированного файла
]]

-- ═══════════════════════════════════════════════════════════════════
-- НАСТРОЙКИ
-- ═══════════════════════════════════════════════════════════════════

local USE_RAW           = false   -- true → сначала дампер Luraph, потом инвиз
local RAW_SCRIPT        = "invisibility.lua.txt"  -- имя файла на диске
local DUMP_PATH         = "luraph_payload.bin"

local INVISIBLE         = true    -- главный переключатель инвиза
local HIDE_NAME         = true    -- скрыть ник над головой
local HIDE_TOOLS        = true    -- спрятать предметы в руках
local HIDE_ACCESSORIES  = false   -- спрятать шляпы/аксессуары
local HIDE_SHADOW       = true    -- убрать тень

-- ═══════════════════════════════════════════════════════════════════
-- ЧАСТЬ 1 — ДАМПЕР LURAPH PAYLOAD
-- ═══════════════════════════════════════════════════════════════════

local function dump_luraph_payload()
    local ok_bf, orig_fromstring = pcall(function() return buffer.fromstring end)
    if not ok_bf or type(orig_fromstring) ~= "function" then
        warn("[dump] buffer.fromstring недоступен — экзекутор не поддерживает buffer API")
        return
    end

    local hooked = false
    buffer.fromstring = function(s, ...)
        if not hooked and type(s) == "string" and #s > 64 then
            hooked = true
            local wf = rawget(getfenv(), "writefile") or writefile
            if wf then
                local ok, err = pcall(wf, DUMP_PATH, s)
                if ok then
                    print(("[dump] payload dumped → %s (%d bytes)"):format(DUMP_PATH, #s))
                else
                    warn("[dump] writefile fail:", err)
                end
            end
        end
        return orig_fromstring(s, ...)
    end

    local ok_rf, src = pcall(function() return readfile(RAW_SCRIPT) end)
    if not ok_rf or type(src) ~= "string" then
        warn("[dump] не нашёл "..RAW_SCRIPT.." — положи файл рядом в workspace экзекутора")
        return
    end

    local fn, load_err = loadstring(src)
    if not fn then
        warn("[dump] loadstring fail:", load_err)
        return
    end

    local ok_run, run_err = pcall(fn)
    print(("[dump] raw run: ok=%s err=%s"):format(tostring(ok_run), tostring(run_err)))
end

-- ═══════════════════════════════════════════════════════════════════
-- ЧАСТЬ 2 — РАБОЧИЙ INVISIBILITY (LocalPlayer)
-- ═══════════════════════════════════════════════════════════════════

local Players    = game:GetService("Players")
local lp         = Players.LocalPlayer

local function hide_char(char)
    char = char or lp.Character
    if not char then return end

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Transparency = 1
            obj.CanCollide = false
            obj.CastShadow = 0
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        elseif obj:IsA("BillboardGui") and HIDE_NAME then
            obj.Enabled = false
        elseif obj:IsA("Accessory") and HIDE_ACCESSORIES then
            for _, p in ipairs(obj:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = 1 end
            end
        elseif obj:IsA("Tool") and HIDE_TOOLS then
            for _, p in ipairs(obj:GetDescendants()) do
                if p:IsA("BasePart") then p.Transparency = 1 end
            end
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
end

local function show_char(char)
    char = char or lp.Character
    if not char then return end

    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Transparency = 0
            obj.CastShadow = 1
        elseif obj:IsA("Decal") then
            obj.Transparency = 0
        elseif obj:IsA("BillboardGui") then
            obj.Enabled = true
        elseif obj:IsA("Accessory") or obj:IsA("Tool") then
            for _, p in ipairs(obj:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.Transparency = 0 end
            end
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
    end
end

local conns = {}

local function hook_char(char)
    for _, c in ipairs(conns) do c:Disconnect() end
    conns = {}
    if not char then return end

    if INVISIBLE then hide_char(char) end

    table.insert(conns, char.DescendantAdded:Connect(function()
        if INVISIBLE then task.defer(function() pcall(hide_char, char) end) end
    end))

    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        table.insert(conns, hum:GetPropertyChangedSignal("Health"):Connect(function()
            if INVISIBLE and hum.Health > 0 then hide_char(char) end
        end))
    end
end

lp.CharacterAdded:Connect(hook_char)
if lp.Character then hook_char(lp.Character) end

-- ═══════════════════════════════════════════════════════════════════
-- ПУБЛИЧНОЕ API
-- ═══════════════════════════════════════════════════════════════════

local api = {}
function api.set_invisible(v)
    INVISIBLE = v and true or false
    if INVISIBLE then hide_char() else show_char() end
    print("[invis]", INVISIBLE and "ON" or "OFF")
end
function api.toggle() api.set_invisible(not INVISIBLE) end
function api.dump() dump_luraph_payload() end

_G.Inv = api
print("[invis] loaded. _G.Inv:toggle() / _G.Inv:set_invisible(bool) / _G.Inv:dump()")

-- ═══════════════════════════════════════════════════════════════════
-- СТАРТ
-- ═══════════════════════════════════════════════════════════════════

if USE_RAW then
    task.spawn(dump_luraph_payload)
end

if INVISIBLE then hide_char() end
