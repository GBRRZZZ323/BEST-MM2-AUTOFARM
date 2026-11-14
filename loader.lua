-- loader.lua
-- O script principal é entregue pelo servidor somente após validar a key.

local SERVER = "https://gdztoolsn.fly.dev"
local KEY_FILE = "key.txt"
local PLAN = "mensal"
local DEBUG_FORCE_PROMPT = false -- true = sempre pede key (testes). Troca pra false quando for lançar de verdade.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Analytics = game:GetService("RbxAnalyticsService")

local requestFn = request or http_request or (syn and syn.request)

if not requestFn then
    warn("Seu executor não suporta request()")
    return
end

local hwid = (gethwid and gethwid()) or Analytics:GetClientId()

local function api(method, path, body)
    local ok, res = pcall(requestFn, {
        Url = SERVER .. path,
        Method = method,
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = body and HttpService:JSONEncode(body) or nil
    })

    if not ok or not res or type(res.Body) ~= "string" then
        return { ok = false, error = "Sem conexão com o servidor" }
    end

    local decoded, data = pcall(HttpService.JSONDecode, HttpService, res.Body)

    if not decoded or type(data) ~= "table" then
        return { ok = false, error = "Resposta inválida do servidor" }
    end

    return data
end

local function validate(key)
    key = tostring(key or ""):gsub("%s+", "")

    if key == "" then
        return { ok = false, error = "Cole a sua key" }
    end

    local data = api("POST", "/validate", {
        key = key,
        hwid = hwid,
        userId = tostring(Players.LocalPlayer.UserId)
    })

    if not data.ok then
        return data
    end

    if type(data.script) ~= "string" or data.script == "" then
        return { ok = false, error = "Script não recebido do servidor" }
    end

    local fn, err = loadstring(data.script)

    if not fn then
        return { ok = false, error = "Script inválido: " .. tostring(err) }
    end

    if writefile then
        pcall(writefile, KEY_FILE, key)
    end

    task.spawn(fn)

    return { ok = true }
end

if not DEBUG_FORCE_PROMPT and isfile and readfile then
    local okFile, saved = pcall(function()
        return isfile(KEY_FILE) and readfile(KEY_FILE) or nil
    end)

    if okFile and saved and saved ~= "" then
        local result = validate(saved)

        if result.ok then
            return
        end

        warn("Key salva não funcionou:", result.error)
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "KeyUI"
gui.ResetOnSpawn = false
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 200)
frame.Position = UDim2.new(0.5, -160, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.Parent = gui

Instance.new("UICorner", frame)

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -40, 0, 36)
box.Position = UDim2.fromOffset(20, 20)
box.PlaceholderText = "Cole sua key aqui"
box.Text = ""
box.ClearTextOnFocus = false
box.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -40, 0, 36)
status.Position = UDim2.fromOffset(20, 62)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.TextWrapped = true
status.Text = ""
status.Parent = frame

local busy = false

local function button(text, y, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -40, 0, 32)
    b.Position = UDim2.fromOffset(20, y)
    b.Text = text
    b.Parent = frame

    b.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true

        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then
                warn("Erro na interface:", err)
            end
            busy = false
        end)
    end)
end

button("Validar key", 108, function()
    status.Text = "Validando..."
    local result = validate(box.Text)

    if result.ok then
        gui:Destroy()
    else
        status.Text = result.error or "Erro"
    end
end)

button("Comprar key", 148, function()
    if setclipboard then
        setclipboard("https://discord.gg/MeFeAt2Afg")
    end
    status.Text = "Link do Discord copiado! Entra no servidor e abre um atendimento pra comprar."
end)