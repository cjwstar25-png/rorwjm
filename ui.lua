--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local WORD_URL = "https://raw.githubusercontent.com/cjwstar25-png/rorwjm/main/word.lua"

local ok, WordHub = pcall(function()
    return loadstring(game:HttpGet(WORD_URL))()
end)

if not ok or type(WordHub) ~= "table" then
    warn("[WordScript] word.lua load failed")
    return
end

local Index = WordHub.index
if not Index then
    if WordHub.buildIndex then
        Index = WordHub.buildIndex()
        WordHub.index = Index
    else
        warn("[WordScript] index missing")
        return
    end
end

local function getFirstCharacter(text: string): string
    if text == "" then
        return ""
    end
    local first = ""
    for startPos, endPos in utf8.graphemes(text) do
        first = string.sub(text, startPos, endPos)
        break
    end
    return first
end

local function getLastCharacter(text: string): string
    if text == "" then
        return ""
    end
    local last = ""
    for startPos, endPos in utf8.graphemes(text) do
        last = string.sub(text, startPos, endPos)
    end
    return last
end

local function make(className: string, props)
    local obj = Instance.new(className)
    for k, v in pairs(props) do
        obj[k] = v
    end
    return obj
end

local function cloneText(parent, text, color, xalign)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = color,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = xalign or Enum.TextXAlignment.Left,
        RichText = false,
        Parent = parent,
    })
end

local gui = make("ScreenGui", {
    Name = "WordScriptGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    Parent = PlayerGui,
})

local main = make("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(320, 220),
    Position = UDim2.new(0.68, 0, 0.22, 0),
    BackgroundColor3 = Color3.fromRGB(18, 18, 22),
    BorderSizePixel = 0,
    Parent = gui,
})

make("UICorner", {
    CornerRadius = UDim.new(0, 12),
    Parent = main,
})

make("UIStroke", {
    Color = Color3.fromRGB(55, 55, 65),
    Thickness = 1,
    Parent = main,
})

local topBar = make("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(24, 24, 30),
    BorderSizePixel = 0,
    Parent = main,
})

make("UICorner", {
    CornerRadius = UDim.new(0, 12),
    Parent = topBar,
})

local topCover = make("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = Color3.fromRGB(24, 24, 30),
    BorderSizePixel = 0,
    Parent = topBar,
})

local title = cloneText(topBar, "WordScript", Color3.fromRGB(235, 235, 245))
title.TextSize = 13
title.Font = Enum.Font.GothamSemibold
title.Position = UDim2.new(0, 10, 0, 0)
title.Size = UDim2.new(1, -90, 1, 0)

local minimize = make("TextButton", {
    Size = UDim2.fromOffset(22, 18),
    Position = UDim2.new(1, -48, 0, 5),
    BackgroundColor3 = Color3.fromRGB(40, 40, 48),
    BorderSizePixel = 0,
    Text = "–",
    TextColor3 = Color3.fromRGB(230, 230, 240),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    Parent = topBar,
})
make("UICorner", {CornerRadius = UDim.new(0, 6), Parent = minimize})

local close = make("TextButton", {
    Size = UDim2.fromOffset(22, 18),
    Position = UDim2.new(1, -22, 0, 5),
    BackgroundColor3 = Color3.fromRGB(52, 36, 40),
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = Color3.fromRGB(255, 220, 220),
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    Parent = topBar,
})
make("UICorner", {CornerRadius = UDim.new(0, 6), Parent = close})

local body = make("Frame", {
    Size = UDim2.new(1, 0, 1, -28),
    Position = UDim2.new(0, 0, 0, 28),
    BackgroundTransparency = 1,
    Parent = main,
})

local searchBox = make("TextBox", {
    Size = UDim2.new(1, -20, 0, 28),
    Position = UDim2.new(0, 10, 0, 8),
    BackgroundColor3 = Color3.fromRGB(28, 28, 34),
    BorderSizePixel = 0,
    PlaceholderText = "끝글자 입력",
    PlaceholderColor3 = Color3.fromRGB(130, 130, 140),
    Text = "",
    ClearTextOnFocus = false,
    TextColor3 = Color3.fromRGB(245, 245, 250),
    TextSize = 12,
    Font = Enum.Font.Gotham,
    Parent = body,
})
make("UICorner", {CornerRadius = UDim.new(0, 8), Parent = searchBox})
make("UIStroke", {Color = Color3.fromRGB(48, 48, 58), Thickness = 1, Parent = searchBox})

local modeLabel = cloneText(body, "끝글자", Color3.fromRGB(180, 180, 190))
modeLabel.TextSize = 11
modeLabel.Position = UDim2.new(0, 12, 0, 42)
modeLabel.Size = UDim2.new(1, -24, 0, 14)

local statsLabel = cloneText(body, "불러오는 중...", Color3.fromRGB(150, 150, 160))
statsLabel.TextSize = 10
statsLabel.Position = UDim2.new(0, 12, 0, 56)
statsLabel.Size = UDim2.new(1, -24, 0, 13)

local results = make("ScrollingFrame", {
    Size = UDim2.new(1, -20, 1, -78),
    Position = UDim2.new(0, 10, 0, 72),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(96, 96, 112),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = body,
})

local layout = make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
    Parent = results,
})

local minimized = false
local dragging = false
local dragStart
local startPos

local function setSize(isMin: boolean)
    local goal = isMin and UDim2.fromOffset(320, 28) or UDim2.fromOffset(320, 220)
    TweenService:Create(main, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = goal}):Play()
end

local function clearResults()
    for _, child in ipairs(results:GetChildren()) do
        if child:IsA("GuiObject") and child ~= layout then
            child:Destroy()
        end
    end
end

local function addResult(word, tagColor)
    local item = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundColor3 = Color3.fromRGB(26, 26, 32),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = results,
    })
    make("UICorner", {CornerRadius = UDim.new(0, 7), Parent = item})
    make("UIStroke", {Color = Color3.fromRGB(42, 42, 50), Thickness = 1, Parent = item})

    local wordLabel = cloneText(item, word, Color3.fromRGB(238, 238, 244))
    wordLabel.TextSize = 12
    wordLabel.Position = UDim2.new(0, 10, 0, 0)
    wordLabel.Size = UDim2.new(1, -20, 1, 0)

    if tagColor then
        local tag = make("Frame", {
            Size = UDim2.fromOffset(5, 5),
            Position = UDim2.new(0, 8, 0.5, -2),
            BackgroundColor3 = tagColor,
            BorderSizePixel = 0,
            Parent = item,
        })
        make("UICorner", {CornerRadius = UDim.new(1, 0), Parent = tag})
    end

    item.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(word)
        end
    end)
end

local function sortWords(list)
    table.sort(list, function(a, b)
        local ap = WordHub.isPriority and WordHub.isPriority(a) or false
        local bp = WordHub.isPriority and WordHub.isPriority(b) or false
        if ap ~= bp then
            return ap and not bp
        end
        if #a ~= #b then
            return #a < #b
        end
        return a < b
    end)
end

local function collectCandidates(query: string)
    local out = {}
    local seen = {}

    local function push(word)
        if not seen[word] then
            seen[word] = true
            table.insert(out, word)
        end
    end

    if query == "" then
        for _, word in ipairs(WordHub.special or {}) do
            push(word)
        end
        return out
    end

    local seed = getLastCharacter(query)

    if seed ~= "" then
        local fromSeed = Index.byFirst[seed]
        if fromSeed then
            for _, word in ipairs(fromSeed) do
                push(word)
            end
        end
    end

    if #query > 1 then
        for _, word in ipairs(Index.all) do
            if string.find(word, query, 1, true) then
                push(word)
            end
        end
    end

    for _, word in ipairs(WordHub.special or {}) do
        if string.find(word, query, 1, true) or (seed ~= "" and string.find(word, seed, 1, true)) then
            push(word)
        end
    end

    return out
end

local function update()
    local query = searchBox.Text or ""
    query = query:gsub("%s+", "")

    clearResults()

    local candidates = collectCandidates(query)
    sortWords(candidates)

    if query == "" then
        modeLabel.Text = "특수 단어"
        statsLabel.Text = string.format("총 %d개 / 우선 %d개", #(WordHub.index and WordHub.index.all or {}), #(WordHub.special or {}))
        local shown = 0
        for _, word in ipairs(candidates) do
            shown += 1
            if shown > 18 then
                break
            end
            addResult(word, Color3.fromRGB(120, 150, 255))
        end
    else
        if #query == 1 then
            modeLabel.Text = "끝글자 추천"
        else
            modeLabel.Text = "전체 검색"
        end
        statsLabel.Text = string.format("%d개", #candidates)
        local shown = 0
        for _, word in ipairs(candidates) do
            shown += 1
            if shown > 24 then
                break
            end
            local tagColor = nil
            if WordHub.isPriority and WordHub.isPriority(word) then
                tagColor = Color3.fromRGB(255, 190, 70)
            end
            addResult(word, tagColor)
        end
    end

    if #candidates == 0 then
        local empty = cloneText(results, "결과 없음", Color3.fromRGB(160, 160, 170))
        empty.TextSize = 12
        empty.Size = UDim2.new(1, 0, 0, 22)
        empty.Parent = results
    end

    results.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
end

searchBox:GetPropertyChangedSignal("Text"):Connect(update)

minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    setSize(minimized)
end)

close.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

local dragInput = nil

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragInput = nil
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and dragInput and input == dragInput and dragStart and startPos then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

local stats = WordHub.getStats and WordHub.getStats() or nil
if stats then
    statsLabel.Text = string.format("그룹 %d · 전체 %d · 우선 %d", stats.groups or 0, stats.unique or 0, stats.special or 0)
else
    statsLabel.Text = "준비 완료"
end

update()
