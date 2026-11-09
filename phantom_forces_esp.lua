-- PELICAN | Phantom Forces ESP
-- ESP com Highlight, identificacao por pasta de equipe e limpeza segura.
-- Compatibilidade com executores nao e garantida; depende da API disponivel.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
    warn("[PELICAN] LocalPlayer indisponivel")
    return
end

local root = workspace:WaitForChild("Players", 10)
if not root then
    warn("[PELICAN] Pasta workspace.Players nao encontrada")
    return
end

local config = {
    enabled = true,
    teamCheck = true,
    toggleKey = Enum.KeyCode.RightShift,
    fillColor = Color3.fromRGB(255, 40, 40),
    outlineColor = Color3.fromRGB(255, 255, 255),
    fillTransparency = 0.5,
    outlineTransparency = 0,
}

local environment = _G
pcall(function()
    if type(getgenv) == "function" then
        environment = getgenv()
    end
end)

if type(environment.PelicanPFESP_Stop) == "function" then
    pcall(environment.PelicanPFESP_Stop)
end

local running = true
local connections = {}
local highlights = {}
local warnedNoTeam = false

local function listen(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
end

local function teamFolder(model)
    local parent = model.Parent
    while parent and parent ~= root do
        if parent.Parent == root and parent:IsA("Folder") then
            return parent
        end
        parent = parent.Parent
    end
    return nil
end

local function localTeamName()
    local colorName = player.TeamColor.Name
    if root:FindFirstChild(colorName) then
        return colorName
    end
    if player.Team then
        local teamName = player.Team.TeamColor.Name
        if root:FindFirstChild(teamName) then
            return teamName
        end
    end
    return nil
end

local function validModel(model)
    return model:IsA("Model")
        and model.Name == "Player"
        and model:FindFirstChild("Torso") ~= nil
        and teamFolder(model) ~= nil
end

local function visible(model)
    if not config.enabled or not validModel(model) then
        return false
    end
    if not config.teamCheck then
        return true
    end

    local myTeam = localTeamName()
    local folder = teamFolder(model)
    if not myTeam or not folder then
        if not warnedNoTeam then
            warn("[PELICAN] Equipe local nao reconhecida; ESP oculto para evitar marcar aliados")
            warnedNoTeam = true
        end
        return false
    end
    warnedNoTeam = false
    return folder.Name ~= myTeam
end

local function remove(model)
    local highlight = highlights[model]
    if highlight then
        highlights[model] = nil
        highlight:Destroy()
    end
end

local function attach(model)
    if not running or highlights[model] or not validModel(model) then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "PelicanPFESP"
    highlight.Adornee = model
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = config.fillColor
    highlight.OutlineColor = config.outlineColor
    highlight.FillTransparency = config.fillTransparency
    highlight.OutlineTransparency = config.outlineTransparency
    highlight.Enabled = visible(model)
    highlight.Parent = model
    highlights[model] = highlight
end

local function refresh()
    for model, highlight in pairs(highlights) do
        if not model:IsDescendantOf(root) or not validModel(model) then
            remove(model)
        else
            highlight.Enabled = visible(model)
        end
    end
end

-- Primeira varredura, apenas uma vez.
for _, item in ipairs(root:GetDescendants()) do
    if item:IsA("Model") and item.Name == "Player" then
        attach(item)
    end
end

-- Event-driven: sem while true, RenderStepped ou varreduras por frame.
listen(root.DescendantAdded, function(item)
    if not running then return end

    if item:IsA("Model") and item.Name == "Player" then
        task.defer(function()
            if running then attach(item) end
        end)
    elseif item.Name == "Torso" and item:IsA("BasePart") then
        local model = item.Parent
        if model and model:IsA("Model") then
            task.defer(function()
                if running then attach(model) end
            end)
        end
    end
end)

listen(root.DescendantRemoving, function(item)
    if highlights[item] then
        remove(item)
    elseif item:IsA("BasePart") and item.Name == "Torso" then
        local model = item.Parent
        if model and highlights[model] then
            remove(model)
        end
    end
end)

listen(player:GetPropertyChangedSignal("Team"), refresh)
listen(player:GetPropertyChangedSignal("TeamColor"), refresh)

listen(UserInputService.InputBegan, function(input, processed)
    if processed or input.KeyCode ~= config.toggleKey then
        return
    end
    config.enabled = not config.enabled
    refresh()
    print("[PELICAN] ESP " .. (config.enabled and "ATIVADO" or "DESATIVADO"))
end)

environment.PelicanPFESP_Stop = function()
    if not running then return end
    running = false
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
    for model in pairs(highlights) do
        remove(model)
    end
    print("[PELICAN] ESP encerrado")
end

print("[PELICAN] Phantom Forces ESP carregado | RightShift para alternar")
