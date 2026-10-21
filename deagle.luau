-- UniHub: noclip / fly / ESP / xray / anti-fling / fling (Shift) / infjump / god
-- Меню: RightShift. Бинды настраиваются во вкладке «Бинды».

local genv = (typeof(getgenv) == "function" and getgenv()) or _G;
if genv.UniHub then pcall(function() genv.UniHub:Destroy() end) genv.UniHub = nil; end

local Players = game:GetService("Players");
local UIS = game:GetService("UserInputService");
local RunService = game:GetService("RunService");

local LocalPlayer = Players.LocalPlayer;
local Camera = workspace.CurrentCamera;

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))();

local MODULE_LABELS = {
    fly = "Fly", noclip = "Noclip", esp = "ESP", xray = "X-Ray",
    antifling = "Anti-Fling", fling = "Fling (зажать)", infjump = "Беск. прыжок", god = "God Mode",
    aimbot = "Aimbot", bhop = "Bhop", triggerbot = "Triggerbot", silentaim = "Silent Aim (сквозь стены)",
};

local Hub = {
    conns = {},
    toggles = {},
    bindButtons = {},
    listening = nil,
    state = { fly = false, noclip = false, esp = false, xray = false, antifling = false, fling = false, infjump = false, god = false, aimbot = false, bhop = false, triggerbot = false, silentaim = false },
    holdActive = { fling = false, aimbot = false },
    binds = {
        fly = Enum.KeyCode.F, noclip = Enum.KeyCode.N, esp = Enum.KeyCode.E,
        xray = Enum.KeyCode.X, antifling = Enum.KeyCode.G, fling = Enum.KeyCode.LeftShift,
        infjump = Enum.KeyCode.J, god = Enum.KeyCode.H, aimbot = Enum.KeyCode.V, bhop = Enum.KeyCode.B,
        triggerbot = Enum.KeyCode.T, silentaim = Enum.KeyCode.C,
    },
    bindMode = { fling = "hold", aimbot = "toggle", bhop = "toggle", triggerbot = "toggle", silentaim = "toggle" },
    cfg = { flySpeed = 60, xrayTransparency = 0.6, espTeamCheck = true, walkSpeed = nil, jumpPower = nil,
        aimFOV = 120, aimSmooth = 0.35, aimPart = "Head", aimVisibleCheck = true, aimDeadzone = 4,
        aimTeamCheck = true, aimOnKey = false, aimKey = Enum.UserInputType.MouseButton2, aimMaxDist = 2500,
        bhopDelay = 0.05, showBindList = true,
        trigDelay = 0, trigHold = false, trigFOV = 10,
        silentWhitelist = "all",
    },
    modules = {},
};
genv.UniHub = Hub;

local function conn(signal, fn)
    local c = signal:Connect(fn);
    table.insert(Hub.conns, c);
    return c;
end

local function getChar() return LocalPlayer.Character; end
local function getHRP() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart"); end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid"); end

---------------------------------------------------------------- noclip
conn(RunService.Heartbeat, function()
    if not Hub.state.noclip then return; end
    local char = getChar();
    if not char then return; end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false; end
    end
end)

---------------------------------------------------------------- fly
local flyVel, flyGyro;
local keys = { w = false, a = false, s = false, d = false, space = false, lctrl = false };

local function ensureFlyParts(hrp)
    if flyVel and flyVel.Parent == hrp and flyGyro and flyGyro.Parent == hrp then return; end
    if flyVel then flyVel:Destroy() flyVel = nil; end
    if flyGyro then flyGyro:Destroy() flyGyro = nil; end
    flyVel = Instance.new("BodyVelocity");
    flyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9);
    flyVel.Velocity = Vector3.zero;
    flyVel.Parent = hrp;
    flyGyro = Instance.new("BodyGyro");
    flyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9);
    flyGyro.P = 9000;
    flyGyro.D = 500;
    flyGyro.CFrame = hrp.CFrame;
    flyGyro.Parent = hrp;
end
local function killFlyParts()
    if flyVel then flyVel:Destroy() flyVel = nil; end
    if flyGyro then flyGyro:Destroy() flyGyro = nil; end
end

function Hub.modules.fly(on)
    if not on then
        killFlyParts();
        local hum = getHum();
        if hum then hum.PlatformStand = false; end
    end
end

conn(RunService.RenderStepped, function()
    if not Hub.state.fly then return; end
    local hrp, hum = getHRP(), getHum();
    if not hrp or not hum or hum.Health <= 0 then return; end
    ensureFlyParts(hrp);
    if hum.PlatformStand == false then hum.PlatformStand = true; end
    local dir = Vector3.zero;
    local cf = Camera.CFrame;
    if keys.w then dir += cf.LookVector; end
    if keys.s then dir -= cf.LookVector; end
    if keys.d then dir += cf.RightVector; end
    if keys.a then dir -= cf.RightVector; end
    if keys.space then dir += Vector3.yAxis; end
    if keys.lctrl then dir -= Vector3.yAxis; end
    if dir.Magnitude > 0 then dir = dir.Unit * Hub.cfg.flySpeed; end
    flyVel.Velocity = dir;
    local look = cf.LookVector;
    if look.Magnitude > 0 then
        flyGyro.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(look.X, 0, look.Z));
    end
end)

local function setKey(k, state)
    if k == Enum.KeyCode.W then keys.w = state; end
    if k == Enum.KeyCode.A then keys.a = state; end
    if k == Enum.KeyCode.S then keys.s = state; end
    if k == Enum.KeyCode.D then keys.d = state; end
    if k == Enum.KeyCode.Space then keys.space = state; end
    if k == Enum.KeyCode.LeftControl then keys.lctrl = state; end
end

---------------------------------------------------------------- ESP
local espCache = {};

local function removeESP(plr)
    local e = espCache[plr];
    if e then
        if e.hl then e.hl:Destroy(); end
        if e.bb then e.bb:Destroy(); end
        espCache[plr] = nil;
    end
end

local function attachESP(plr)
    local e = espCache[plr];
    if not e then return; end
    local char = plr.Character;
    local hrp = char and char:FindFirstChild("HumanoidRootPart");
    local head = char and (char:FindFirstChild("Head") or hrp);
    if not char or not hrp or not head then return; end
    -- пересоздаём объекты, если персонаж умер/респавнился и старые ушли со старым персонажем
    if e.hl and (e.hl.Parent ~= char or not e.hl.Parent) then
        e.hl:Destroy();
        e.hl = nil;
    end
    if e.bb and (e.bb.Parent ~= head or not e.bb.Parent) then
        e.bb:Destroy();
        e.bb = nil;
    end
    if not e.hl then
        e.hl = Instance.new("Highlight");
        e.hl.Name = "UniHub_ESP";
        e.hl.FillTransparency = 0.65;
        e.hl.OutlineTransparency = 0;
        e.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop;
        e.hl.Parent = char;
    end
    if not e.bb then
        e.bb = Instance.new("BillboardGui");
        e.bb.Name = "UniHub_ESP";
        e.bb.Size = UDim2.new(0, 200, 0, 46);
        e.bb.StudsOffset = Vector3.new(0, 2.6, 0);
        e.bb.AlwaysOnTop = true;
        e.bb.MaxDistance = 2500;
        local tl = Instance.new("TextLabel");
        tl.Name = "Name";
        tl.Size = UDim2.new(1, 0, 0.55, 0);
        tl.BackgroundTransparency = 1;
        tl.TextColor3 = Color3.new(1, 1, 1);
        tl.TextStrokeTransparency = 0.2;
        tl.Font = Enum.Font.GothamBold;
        tl.TextSize = 14;
        tl.Parent = e.bb;
        local tl2 = Instance.new("TextLabel");
        tl2.Name = "Info";
        tl2.Size = UDim2.new(1, 0, 0.45, 0);
        tl2.Position = UDim2.new(0, 0, 0.55, 0);
        tl2.BackgroundTransparency = 1;
        tl2.TextColor3 = Color3.fromRGB(200, 200, 200);
        tl2.TextStrokeTransparency = 0.2;
        tl2.Font = Enum.Font.Gotham;
        tl2.TextSize = 12;
        tl2.Parent = e.bb;
        e.bb.Parent = head;
    end
end

function Hub.modules.esp(on)
    if on then
        -- чистим записи с мёртвыми объектами (после смерти/респавна)
        for plr, e in pairs(espCache) do
            if not plr.Parent or (e.hl and not e.hl.Parent) or (e.bb and not e.bb.Parent) then
                removeESP(plr);
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and not espCache[plr] then
                espCache[plr] = {};
                attachESP(plr);
            end
        end
    else
        for plr in pairs(espCache) do removeESP(plr); end
    end
end

conn(Players.PlayerAdded, function(plr)
    if Hub.state.esp and plr ~= LocalPlayer then
        espCache[plr] = {};
        attachESP(plr);
    end
end)
conn(Players.PlayerRemoving, function(plr) removeESP(plr); end)

task.spawn(function()
    while true do
        task.wait(0.15);
        if Hub.state.esp then
            local myTeam = LocalPlayer.Team;
            for plr, e in pairs(espCache) do
                if not plr.Parent then removeESP(plr) continue; end
                attachESP(plr);
                local char = plr.Character;
                local hrp = char and char:FindFirstChild("HumanoidRootPart");
                local hum = char and char:FindFirstChildOfClass("Humanoid");
                if hrp and hum and e.bb and e.hl then
                    local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude);
                    local nameL = e.bb:FindFirstChild("Name");
                    local infoL = e.bb:FindFirstChild("Info");
                    if nameL then nameL.Text = plr.DisplayName; end
                    if infoL then
                        local hp = math.max(0, math.floor(hum.Health));
                        infoL.Text = dist .. " м | HP " .. hp;
                    end
                    if Hub.cfg.espTeamCheck then
                        if plr.Team ~= myTeam then
                            e.hl.FillColor = Color3.fromRGB(255, 60, 60);
                            e.hl.OutlineColor = Color3.fromRGB(255, 90, 90);
                        else
                            e.hl.FillColor = Color3.fromRGB(60, 255, 120);
                            e.hl.OutlineColor = Color3.fromRGB(90, 255, 140);
                        end
                    else
                        e.hl.FillColor = Color3.fromRGB(120, 160, 255);
                        e.hl.OutlineColor = Color3.fromRGB(160, 190, 255);
                    end
                    e.hl.Enabled = true;
                    e.bb.Enabled = true;
                else
                    if e.hl then e.hl.Enabled = false; end
                    if e.bb then e.bb.Enabled = false; end
                end
            end
        end
    end
end)

---------------------------------------------------------------- xray
local xrayParts = {};
local function xrayApply(part)
    if not part:IsA("BasePart") then return; end
    if part.Transparency >= 1 then return; end
    if xrayParts[part] ~= nil then return; end
    local plr = Players:GetPlayerFromCharacter(part.Parent);
    if plr then return; end
    local myChar = getChar();
    if myChar and part:IsDescendantOf(myChar) then return; end
    xrayParts[part] = part.LocalTransparencyModifier;
    part.LocalTransparencyModifier = Hub.cfg.xrayTransparency;
end
function Hub.modules.xray(on)
    if on then
        for _, inst in ipairs(workspace:GetDescendants()) do xrayApply(inst); end
    else
        for part, orig in pairs(xrayParts) do
            if part.Parent then pcall(function() part.LocalTransparencyModifier = orig; end); end
        end
        xrayParts = {};
    end
end
conn(workspace.DescendantAdded, function(inst)
    if Hub.state.xray then xrayApply(inst); end
end)

---------------------------------------------------------------- anti-fling
local lastSafeCF = nil;
conn(RunService.Heartbeat, function()
    local hrp = getHRP();
    if not hrp then return; end
    local flinging = Hub.state.fling and Hub.holdActive.fling;
    if Hub.state.antifling and not flinging then
        local v = hrp.AssemblyLinearVelocity;
        if v.Magnitude < 60 then
            lastSafeCF = hrp.CFrame;
        elseif v.Magnitude > 350 then
            hrp.AssemblyLinearVelocity = Vector3.zero;
            hrp.AssemblyAngularVelocity = Vector3.zero;
            if lastSafeCF then pcall(function() hrp.CFrame = lastSafeCF; end); end
        end
    end
end)

---------------------------------------------------------------- fling (зажать Shift)
conn(RunService.Heartbeat, function()
    if not (Hub.state.fling and Hub.holdActive.fling) then return; end
    local hrp, hum = getHRP(), getHum();
    if not hrp or not hum or hum.Health <= 0 then return; end
    hrp.AssemblyAngularVelocity = Vector3.new(0, 1e5, 0);
    local v = hrp.AssemblyLinearVelocity;
    if v.Y < 20 then hrp.AssemblyLinearVelocity = Vector3.new(v.X, 25, v.Z); end
end)

---------------------------------------------------------------- bhop (bunny hop)
local bhopLastJump = 0;
function Hub.modules.bhop(on) bhopLastJump = 0; end
conn(RunService.Heartbeat, function()
    if not Hub.state.bhop then return; end
    if not UIS:IsKeyDown(Enum.KeyCode.Space) then return; end
    local hum = getHum();
    if not hum or hum.Health <= 0 then return; end
    if os.clock() - bhopLastJump < Hub.cfg.bhopDelay then return; end
    -- прыгаем в момент касания земли, чтобы не терять скорость
    if hum.FloorMaterial ~= Enum.Material.Air and hum:GetState() ~= Enum.HumanoidStateType.Freefall then
        hum:ChangeState(Enum.HumanoidStateType.Jumping);
        bhopLastJump = os.clock();
    end
end)

---------------------------------------------------------------- triggerbot
local trigLastShot = 0;
function Hub.modules.triggerbot(on) end
conn(RunService.RenderStepped, function()
    if not Hub.state.triggerbot then return; end
    -- стреляем только когда зажат ЛКМ (или включён режим «всегда»)
    if Hub.cfg.trigHold and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return; end
    if os.clock() - trigLastShot < Hub.cfg.trigDelay then return; end
    local camCF = Camera.CFrame;
    local rayDir = camCF.LookVector * 5000;
    local myChar = getChar();
    local rp = RaycastParams.new();
    rp.FilterType = Enum.RaycastFilterType.Exclude;
    rp.FilterDescendantsInstances = { myChar, Camera };
    local res = workspace:Raycast(camCF.Position, rayDir, rp);
    if res and res.Instance then
        local char = res.Instance.Parent;
        local plr = Players:GetPlayerFromCharacter(char);
        if not plr then
            -- accessory на персонаже
            local acc = res.Instance:FindFirstAncestorOfClass("Accessory");
            char = acc and acc.Parent or char;
            plr = Players:GetPlayerFromCharacter(char);
        end
        if plr and plr ~= LocalPlayer then
            -- командная проверка
            local myTeam = LocalPlayer.Team;
            if not (Hub.cfg.aimTeamCheck and plr.Team == myTeam and myTeam ~= nil) then
                local hum = char:FindFirstChildOfClass("Humanoid");
                if hum and hum.Health > 0 then
                    trigLastShot = os.clock();
                    pcall(mouse1click);
                end
            end
        end
    end
end)

---------------------------------------------------------------- silent aim (стрельба сквозь стены)
local silentHooked = false;
local oldNamecall;
function Hub.modules.silentaim(on)
    if on and not silentHooked then
        silentHooked = true;
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod();
            local args = { ... };
            if Hub.state.silentaim and (method == "Raycast" or method == "FindPartOnRay"
                or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist")
                and not checkcaller() then
                local origin, dir = args[1], args[2];
                if typeof(origin) == "CFrame" then
                    origin = origin.Position;
                end
                if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" then
                    local part = getTarget();
                    if part then
                        -- подменяем направление луча: летит из точки выстрела точно в цель.
                        -- Стены больше не помеха: игра видит попадание в цель.
                        local newDir = part.Position - origin;
                        if newDir.Magnitude > 0 then
                            args[2] = newDir;
                        end
                    end
                end
            end
            return oldNamecall(self, unpack(args));
        end));
    end
    -- хук стоит постоянно, но подменяет только при включённом модульном флаге — отключение мгновенное
end

---------------------------------------------------------------- infinite jump
conn(UIS.JumpRequest, function()
    if not Hub.state.infjump then return; end
    local hum = getHum();
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping); end
end)

---------------------------------------------------------------- god
function Hub.modules.god(on)
    local hum = getHum();
    if on then
        if hum then hum.MaxHealth = 1e9 hum.Health = 1e9; end
    else
        if hum then hum.MaxHealth = 100 hum.Health = math.min(hum.Health, 100); end
    end
end
conn(RunService.Heartbeat, function()
    if Hub.state.god then
        local hum = getHum();
        if hum and hum.Health < 1e8 then hum.Health = 1e9; end
    end
end)

---------------------------------------------------------------- aimbot
local fovCircle;
local function initFovCircle()
    if not Drawing then return; end
    if fovCircle then return; end
    fovCircle = Drawing.new("Circle");
    fovCircle.Thickness = 1;
    fovCircle.Transparency = 1;
    fovCircle.Color = Color3.fromRGB(255, 255, 255);
    fovCircle.Filled = false;
    fovCircle.Radius = Hub.cfg.aimFOV;
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2);
    fovCircle.Visible = false;
end
local function removeFovCircle()
    if fovCircle then
        fovCircle:Remove();
        fovCircle = nil;
    end
end

local rayParams = RaycastParams.new();
rayParams.FilterType = Enum.RaycastFilterType.Exclude;
rayParams.RespectCanCollide = true;
rayParams.IgnoreWater = true;

local function isVisible(part)
    if not Hub.cfg.aimVisibleCheck then return true; end
    local myChar = getChar();
    rayParams.FilterDescendantsInstances = { myChar };
    local res = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rayParams);
    return res == nil or res.Instance == part or res.Instance:IsDescendantOf(part.Parent);
end

local function getTarget()
    local best, bestDist = nil, math.huge;
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2);
    local myTeam = LocalPlayer.Team;
    local camPos = Camera.CFrame.Position;
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if not (Hub.cfg.aimTeamCheck and plr.Team == myTeam and myTeam ~= nil) then
                local char = plr.Character;
                local hum = char:FindFirstChildOfClass("Humanoid");
                local part = char:FindFirstChild(Hub.cfg.aimPart) or char:FindFirstChild("HumanoidRootPart");
                if hum and hum.Health > 0 and part then
                    local dist3d = (part.Position - camPos).Magnitude;
                    if dist3d <= Hub.cfg.aimMaxDist then
                        local screen, onScreen = Camera:WorldToViewportPoint(part.Position);
                        if onScreen then
                            local dist2d = (Vector2.new(screen.X, screen.Y) - center).Magnitude;
                            if dist2d <= Hub.cfg.aimFOV and dist2d < bestDist and isVisible(part) then
                                best = part;
                                bestDist = dist2d;
                            end
                        end
                    end
                end
            end
        end
    end
    if best then return best; end
    return nil;
end

local function aimActive()
    if not Hub.state.aimbot then return false; end
    if not Hub.cfg.aimOnKey then return true; end
    return Hub.holdActive.aimbot == true;
end

-- Плавное наведение «с помощью игрока»:
-- держим виртуальную ориентацию, каждый кадр вплетаем движение мыши игрока,
-- затем подтягиваем к цели с FPS-независимой плавностью. Игрок может уводить прицел.
local aimYaw, aimPitch = nil, nil;
local aimLastPart = nil;
local lastFrameTime = os.clock();

conn(RunService.RenderStepped, function()
    local now = os.clock();
    local dt = math.clamp(now - lastFrameTime, 0.001, 0.1);
    lastFrameTime = now;

    -- FOV-круг
    local showCircle = Hub.state.aimbot and Drawing ~= nil;
    if showCircle then
        initFovCircle();
        if fovCircle then
            fovCircle.Radius = Hub.cfg.aimFOV;
            fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2);
            fovCircle.Visible = true;
        end
    elseif fovCircle then
        fovCircle.Visible = false;
    end

    if not aimActive() then
        aimYaw, aimPitch, aimLastPart = nil, nil, nil;
        return;
    end
    local part = getTarget();
    if not part then
        aimLastPart = nil;
        return;
    end
    -- цель сменилась — не телепортируем прицел, продолжаем с текущей ориентации
    local camCF = Camera.CFrame;
    local look = camCF.LookVector;
    if aimYaw == nil or aimLastPart ~= part then
        aimYaw = math.atan2(-look.X, -look.Z);
        aimPitch = math.asin(math.clamp(look.Y, -1, 1));
        aimLastPart = part;
    end
    -- 1) движение мыши игрока вплетается в прицел (можно помогать и уводить)
    local delta = UIS:GetMouseDelta();
    if delta.Magnitude > 0 then
        local sens = 0.0035;
        aimYaw -= delta.X * sens;
        aimPitch = math.clamp(aimPitch - delta.Y * sens, -1.5, 1.5);
    end
    -- 2) подтягиваем к цели с FPS-независимой плавностью
    local camPos = camCF.Position;
    local toTarget = (part.Position - camPos).Unit;
    local tYaw = math.atan2(-toTarget.X, -toTarget.Z);
    local tPitch = math.asin(math.clamp(toTarget.Y, -1, 1));
    local smooth = math.clamp(Hub.cfg.aimSmooth, 0.02, 1);
    local halfTime = 1 / math.max(smooth, 0.02) * 0.02; -- условная скорость
    local alpha = 1 - math.exp(-dt / math.max(halfTime, 0.001));
    local function angLerp(a, b, alpha)
        local diff = (b - a + math.pi) % (2 * math.pi) - math.pi;
        return a + diff * alpha;
    end
    aimYaw = angLerp(aimYaw, tYaw, alpha);
    aimPitch = angLerp(aimPitch, tPitch, alpha);
    -- дедзона: почти навелись — доводим
    if (Vector3.new(-math.sin(aimYaw) * math.cos(aimPitch), math.sin(aimPitch), -math.cos(aimYaw) * math.cos(aimPitch)) - toTarget).Magnitude < Hub.cfg.aimDeadzone / 100 then
        aimYaw, aimPitch = tYaw, tPitch;
    end
    -- 3) применяем
    Camera.CFrame = CFrame.lookAt(camPos, camPos + Vector3.new(
        -math.sin(aimYaw) * math.cos(aimPitch),
        math.sin(aimPitch),
        -math.cos(aimYaw) * math.cos(aimPitch)
    ));
end)

function Hub.modules.aimbot(on)
    if not on then
        if fovCircle then fovCircle.Visible = false; end
        removeFovCircle();
    end
end

conn(LocalPlayer.CharacterAdded, function(char)
    task.wait(0.5);
    local hum = char:WaitForChild("Humanoid", 5);
    local hrp = char:WaitForChild("HumanoidRootPart", 5);
    if not hum or not hrp then return; end
    if Hub.cfg.walkSpeed then hum.WalkSpeed = Hub.cfg.walkSpeed; end
    if Hub.cfg.jumpPower and hum.UseJumpPower then hum.JumpPower = Hub.cfg.jumpPower; end
    if Hub.state.god then hum.MaxHealth = 1e9 hum.Health = 1e9; end
    if Hub.state.fly then ensureFlyParts(hrp); end
end)

---------------------------------------------------------------- setModule
function Hub.setModule(name, on)
    if Hub.state[name] == on then return; end
    Hub.state[name] = on;
    local fn = Hub.modules[name];
    if fn then
        local ok, err = pcall(fn, on);
        if not ok then warn("[UniHub] " .. name .. ": " .. tostring(err)); end
    end
    local t = Hub.toggles[name];
    if t then pcall(function() t:Set(on); end); end
end

---------------------------------------------------------------- input / binds
local function updateBindButton(name)
    local b = Hub.bindButtons[name];
    if b then
        pcall(function()
            b:SetTitle(MODULE_LABELS[name] .. " — " .. (Hub.binds[name] and Hub.binds[name].Name or "нет"));
        end);
    end
end

-- Сравнение клавиши бинда с инпутом: бинд может быть KeyCode или UserInputType (мышь)
local function keyMatches(bind, input)
    if bind == input.KeyCode and bind ~= Enum.KeyCode.Unknown then return true; end
    return bind == input.UserInputType;
end

conn(UIS.InputBegan, function(input, gp)
    local kc = input.KeyCode;
    if Hub.listening then
        local picked = nil;
        if kc ~= Enum.KeyCode.Unknown and kc ~= Enum.KeyCode.Escape then
            picked = kc;
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            picked = input.UserInputType;
        end
        if picked then
            local name = Hub.listening;
            Hub.listening = nil;
            if name == "aimKey" then
                Hub.cfg.aimKey = picked;
                WindUI:Notify({ Title = "Клавиша назначена", Content = "Активация аима → " .. picked.Name, Duration = 2 });
            else
                Hub.binds[name] = picked;
                updateBindButton(name);
                WindUI:Notify({ Title = "Бинд назначен", Content = MODULE_LABELS[name] .. " → " .. picked.Name, Duration = 2 });
            end
        end
        return;
    end
    setKey(kc, true);
    -- aim-активация клавишей (напр. ПКМ), независимо от геймпад-блокировки
    if Hub.cfg.aimOnKey and keyMatches(Hub.cfg.aimKey, input) then
        Hub.holdActive.aimbot = true;
    end
    if gp then return; end
    for name, bind in pairs(Hub.binds) do
        if keyMatches(bind, input) then
            if (Hub.bindMode[name] or "toggle") == "hold" then
                Hub.holdActive[name] = true;
            else
                Hub.setModule(name, not Hub.state[name]);
                WindUI:Notify({ Title = MODULE_LABELS[name], Content = Hub.state[name] and "включён" or "выключен", Duration = 1.5 });
            end
        end
    end
end)

conn(UIS.InputEnded, function(input)
    local kc = input.KeyCode;
    setKey(kc, false);
    if Hub.cfg.aimOnKey and keyMatches(Hub.cfg.aimKey, input) then
        Hub.holdActive.aimbot = false;
    end
    for name, bind in pairs(Hub.binds) do
        if keyMatches(bind, input) and (Hub.bindMode[name] or "toggle") == "hold" then
            Hub.holdActive[name] = false;
            if name == "fling" then
                local hrp = getHRP();
                if hrp then pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero; end); end
            end
        end
    end
end)

---------------------------------------------------------------- UI
local Window = WindUI:CreateWindow({
    Title = "UniHub",
    Icon = "zap",
    Author = "noclip · fly · esp · xray · anti-fling · fling",
    Folder = "UniHub",
    Size = UDim2.fromOffset(620, 470),
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightShift,
});
Hub.Window = Window;

local TabMove = Window:Tab({ Title = "Движение", Icon = "wind" });
local TabVis = Window:Tab({ Title = "Визуал", Icon = "eye" });
local TabProt = Window:Tab({ Title = "Защита", Icon = "shield" });
local TabAim = Window:Tab({ Title = "Аим", Icon = "crosshair" });
local TabBinds = Window:Tab({ Title = "Бинды", Icon = "keyboard" });

local function addToggle(tab, name, title, desc, icon)
    local t = tab:Toggle({
        Title = title, Desc = desc, Icon = icon, Value = false,
        Callback = function(v) Hub.setModule(name, v); end,
    });
    Hub.toggles[name] = t;
end

-- Движение
addToggle(TabMove, "fly", "Fly", "Полёт: W/A/S/D, Space — вверх, Ctrl — вниз", "wind");
TabMove:Slider({
    Title = "Скорость полёта", Value = { Min = 10, Max = 300, Default = 60 },
    Callback = function(v) Hub.cfg.flySpeed = v; end,
});
addToggle(TabMove, "noclip", "Noclip", "Проход сквозь стены", "ghost");
addToggle(TabMove, "infjump", "Бесконечный прыжок", nil, "chevrons-up");
addToggle(TabMove, "bhop", "Bhop (Bunny Hop)", "Зажми Space — прыгает мгновенно при касании земли", "rabbit");
TabMove:Slider({
    Title = "Задержка bhop (сек)",
    Desc = "Пауза между прыжками, 0 = максимальная скорость",
    Value = { Min = 0, Max = 0.5, Default = 0 },
    Step = 0.05,
    Callback = function(v) Hub.cfg.bhopDelay = v; end,
});
TabMove:Slider({
    Title = "WalkSpeed", Value = { Min = 16, Max = 300, Default = 16 },
    Callback = function(v)
        Hub.cfg.walkSpeed = (v > 16) and v or nil;
        local hum = getHum();
        if hum then hum.WalkSpeed = v; end
    end,
});
TabMove:Slider({
    Title = "JumpPower", Value = { Min = 50, Max = 400, Default = 50 },
    Callback = function(v)
        Hub.cfg.jumpPower = (v > 50) and v or nil;
        local hum = getHum();
        if hum and hum.UseJumpPower then hum.JumpPower = v; end
    end,
});

-- Визуал
addToggle(TabVis, "esp", "ESP игроков", "Подсветка, имя, дистанция и HP", "eye");
TabVis:Toggle({
    Title = "ESP: учитывать команду", Desc = "Красный — враг, зелёный — союзник", Value = true,
    Callback = function(v) Hub.cfg.espTeamCheck = v; end,
});
addToggle(TabVis, "xray", "X-Ray", "Стены становятся прозрачными", "scan-eye");
TabVis:Slider({
    Title = "Прозрачность X-Ray", Value = { Min = 0.2, Max = 0.9, Default = 0.6 },
    Callback = function(v)
        Hub.cfg.xrayTransparency = v;
        if Hub.state.xray then
            for part in pairs(xrayParts) do
                if part.Parent then pcall(function() part.LocalTransparencyModifier = v; end); end
            end
        end
    end,
});

-- Защита
addToggle(TabProt, "antifling", "Anti-Fling", "Сбрасывает телепорты-флинги и огромные скорости", "shield");
addToggle(TabProt, "fling", "Fling (по Shift)", "Зажми бинд-клавишу рядом с игроками — их разлетит", "tornado");
addToggle(TabProt, "god", "God Mode", "Бессмертие (может сбрасываться игрой)", "heart-pulse");

-- Аим
addToggle(TabAim, "aimbot", "Aimbot", "Плавное наведение камеры на цель в FOV", "crosshair");
TabAim:Slider({
    Title = "FOV (радиус круга)",
    Desc = "Радиус зоны наведения в пикселях",
    Value = { Min = 20, Max = 800, Default = 120 },
    Callback = function(v) Hub.cfg.aimFOV = v; end,
});
TabAim:Slider({
    Title = "Плавность (0.01 = очень плавно)",
    Desc = "Меньше значение — плавнее и медленнее наведение",
    Value = { Min = 0.05, Max = 1, Default = 0.35 },
    Step = 0.05,
    Callback = function(v) Hub.cfg.aimSmooth = v; end,
});
TabAim:Dropdown({
    Title = "Точка наведения",
    Values = { "Head", "HumanoidRootPart", "Torso", "UpperTorso" },
    Value = "Head",
    Callback = function(v) Hub.cfg.aimPart = v; end,
});
TabAim:Toggle({
    Title = "Проверять видимость (за стенами не целиться)", Value = true,
    Callback = function(v) Hub.cfg.aimVisibleCheck = v; end,
});
TabAim:Toggle({
    Title = "Игнорировать свою команду", Value = true,
    Callback = function(v) Hub.cfg.aimTeamCheck = v; end,
});
TabAim:Toggle({
    Title = "Активация по клавише (ПКМ)",
    Desc = "Выключено — аим работает всегда, включено — только зажав ПКМ",
    Value = false,
    Callback = function(v) Hub.cfg.aimOnKey = v; end,
});
TabAim:Slider({
    Title = "Макс. дистанция цели (студы)",
    Value = { Min = 100, Max = 5000, Default = 2500 },
    Callback = function(v) Hub.cfg.aimMaxDist = v; end,
});
TabAim:Button({
    Title = "Сменить клавишу активации",
    Desc = "По умолчанию ПКМ (MouseButton2). Нажми, затем нажми новую клавишу",
    Callback = function()
        Hub.listening = "aimKey";
        WindUI:Notify({ Title = "Ожидаю клавишу", Content = "Нажми клавишу активации aimbot", Duration = 4 });
    end,
});

-- Triggerbot
TabAim:Toggle({
    Title = "Triggerbot",
    Desc = "Автоматически стреляет, когда противник в прицеле",
    Icon = "zap",
    Value = false,
    Callback = function(v) Hub.setModule("triggerbot", v); end,
});
TabAim:Toggle({
    Title = "Triggerbot: стрелять только при зажатом ЛКМ",
    Desc = "Включено — кликает только пока ты держишь ЛКМ. Выключено — стреляет всегда, когда цель в прицеле",
    Value = false,
    Callback = function(v) Hub.cfg.trigHold = v; end,
});
TabAim:Slider({
    Title = "Задержка триггера (сек)",
    Desc = "Пауза между автоматическими выстрелами",
    Value = { Min = 0, Max = 1, Default = 0 },
    Step = 0.05,
    Callback = function(v) Hub.cfg.trigDelay = v; end,
});

-- Silent Aim (сквозь стены)
TabAim:Toggle({
    Title = "Silent Aim — стрельба сквозь стены",
    Desc = "Подменяет лучи выстрелов игры: пуля летит точно в цель, даже если она за стеной. Прицел двигать не нужно",
    Icon = "crosshair",
    Value = false,
    Callback = function(v) Hub.setModule("silentaim", v); end,
});

-- Бинды
TabBinds:Toggle({
    Title = "Показывать окошко активных биндов",
    Desc = "Мини-окно со включёнными модулями (перетаскивается мышью)",
    Value = true,
    Callback = function(v)
        Hub.cfg.showBindList = v;
        updateBindList();
    end,
});
for _, name in ipairs({ "fly", "noclip", "esp", "xray", "antifling", "fling", "infjump", "god", "aimbot", "bhop", "triggerbot", "silentaim" }) do
    local b = TabBinds:Button({
        Title = MODULE_LABELS[name] .. " — " .. (Hub.binds[name] and Hub.binds[name].Name or "нет"),
        Desc = "Нажми, затем нажми новую клавишу",
        Callback = function()
            Hub.listening = name;
            WindUI:Notify({ Title = "Ожидаю клавишу", Content = "Нажми клавишу для «" .. MODULE_LABELS[name] .. "»", Duration = 4 });
        end,
    });
    Hub.bindButtons[name] = b;
end

-- Перетаскиваемое окошко активных биндов (в стиле Neverlose)
local bindListGui = nil;
local bindListFrame = nil;
local function buildBindList()
    if bindListGui then return; end
    local gui = Instance.new("ScreenGui");
    gui.Name = "UniHub_BindList";
    gui.ResetOnSpawn = false;
    gui.IgnoreGuiInset = true;
    gui.DisplayOrder = 999;
    pcall(function() gui.Parent = (gethui and gethui()) or game.CoreGui; end);

    local frame = Instance.new("Frame");
    frame.Name = "BindWindow";
    frame.AnchorPoint = Vector2.new(0.5, 0);
    frame.Position = UDim2.new(0.5, 0, 0, 40);
    frame.Size = UDim2.new(0, 210, 0, 26);
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22);
    frame.BackgroundTransparency = 0.15;
    frame.BorderSizePixel = 0;
    frame.Active = true;
    frame.Parent = gui;

    local corner = Instance.new("UICorner");
    corner.CornerRadius = UDim.new(0, 8);
    corner.Parent = frame;

    local stroke = Instance.new("UIStroke");
    stroke.Color = Color3.fromRGB(255, 90, 90);
    stroke.Thickness = 1;
    stroke.Transparency = 0.2;
    stroke.Parent = frame;

    local title = Instance.new("TextLabel");
    title.Name = "Title";
    title.Size = UDim2.new(1, -16, 1, 0);
    title.Position = UDim2.new(0, 8, 0, 0);
    title.BackgroundTransparency = 1;
    title.Text = "Keybinds";
    title.TextColor3 = Color3.fromRGB(255, 90, 90);
    title.Font = Enum.Font.GothamBold;
    title.TextSize = 14;
    title.TextXAlignment = Enum.TextXAlignment.Left;
    title.Active = true;
    title.Parent = frame;

    local list = Instance.new("Frame");
    list.Name = "List";
    list.Position = UDim2.new(0, 0, 1, 4);
    list.Size = UDim2.new(1, 0, 0, 0);
    list.BackgroundTransparency = 1;
    list.AutomaticSize = Enum.AutomaticSize.Y;
    list.Parent = frame;

    local layout = Instance.new("UIListLayout");
    layout.Padding = UDim.new(0, 3);
    layout.SortOrder = Enum.SortOrder.LayoutOrder;
    layout.Parent = list;

    -- перетаскивание: зажал ЛКМ на заголовке → передвинул → отпустил ЛКМ — всё
    local dragStart, startPos = nil, nil;
    title.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
            dragStart = io.Position;
            startPos = frame.Position;
        end
    end);
    local uis = game:GetService("UserInputService");
    uis.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
            dragStart = nil;
        end
    end);
    uis.InputChanged:Connect(function(io)
        if dragStart and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
            local delta = io.Position - dragStart;
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y);
        end
    end);

    bindListGui = gui;
    bindListFrame = frame;
    gui.Enabled = false;
end

local function updateBindList()
    buildBindList();
    if not bindListGui then return; end
    local entries = {};
    for name, on in pairs(Hub.state) do
        if on and MODULE_LABELS[name] then
            table.insert(entries, { name = name, label = MODULE_LABELS[name] });
        end
    end
    table.sort(entries, function(a, b) return a.label < b.label; end);
    bindListGui.Enabled = Hub.cfg.showBindList and #entries > 0;
    local list = bindListFrame:FindFirstChild("List");
    -- обновляем/создаём строки
    local existing = {};
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextLabel") then
            existing[child.Name] = child;
        end
    end
    -- удаляем лишние
    local keep = {};
    for _, entry in ipairs(entries) do
        keep[entry.name] = true;
    end
    for name, label in pairs(existing) do
        if not keep[name] then label:Destroy(); end
    end
    -- добавляем/обновляем
    for i, entry in ipairs(entries) do
        local row = existing[entry.name];
        if not row then
            row = Instance.new("TextLabel");
            row.Name = entry.name;
            row.Size = UDim2.new(1, 0, 0, 20);
            row.BackgroundColor3 = Color3.fromRGB(24, 24, 30);
            row.BackgroundTransparency = 0.25;
            row.BorderSizePixel = 0;
            row.Font = Enum.Font.Gotham;
            row.TextSize = 12;
            row.TextXAlignment = Enum.TextXAlignment.Left;
            row.TextColor3 = Color3.new(1, 1, 1);
            local rc = Instance.new("UICorner");
            rc.CornerRadius = UDim.new(0, 5);
            rc.Parent = row;
            local pad = Instance.new("UIPadding");
            pad.PaddingLeft = UDim.new(0, 8);
            pad.PaddingRight = UDim.new(0, 8);
            pad.Parent = row;
            row.Parent = list;
            local keyL = Instance.new("TextLabel");
            keyL.Name = "Key";
            keyL.Size = UDim2.new(0, 60, 1, 0);
            keyL.Position = UDim2.new(1, -68, 0, 0);
            keyL.BackgroundTransparency = 1;
            keyL.Font = Enum.Font.GothamBold;
            keyL.TextSize = 11;
            keyL.TextXAlignment = Enum.TextXAlignment.Right;
            keyL.TextColor3 = Color3.fromRGB(255, 200, 200);
            keyL.Parent = row;
        end
        local keyL = row:FindFirstChild("Key");
        if keyL then
            local bind = Hub.binds[entry.name];
            local bindName = bind and bind.Name or "—";
            if bindName == "Unknown" then bindName = "—"; end
            keyL.Text = "[" .. bindName .. "]";
        end
        row.Text = entry.label;
        row.LayoutOrder = i;
    end
end

-- обновляем окошко при смене состояний и при смене биндов
local origSetModule = Hub.setModule;
Hub.setModule = function(name, on)
    origSetModule(name, on);
    updateBindList();
end
local origUpdateBindButton = updateBindButton;
updateBindButton = function(name)
    origUpdateBindButton(name);
    updateBindList();
end

function Hub:Destroy()
    for name in pairs(Hub.state) do
        if Hub.state[name] then Hub.setModule(name, false); end
    end
    for _, c in ipairs(Hub.conns) do pcall(function() c:Disconnect(); end); end
    Hub.conns = {};
    for plr in pairs(espCache) do removeESP(plr); end
    killFlyParts();
    removeFovCircle();
    if bindListGui then bindListGui:Destroy(); bindListGui = nil; end
    if Hub.Window then pcall(function() Hub.Window:Destroy(); end); end
end

WindUI:Notify({ Title = "UniHub загружен", Content = "Меню — RightShift · Fling — зажать LeftShift", Duration = 5 });
