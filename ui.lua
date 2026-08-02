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
	if type(WordHub.buildIndex) == "function" then
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

local function make(className: string, props: { [string]: any }?)
	local obj = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			obj[k] = v
		end
	end
	return obj
end

local function tween(instance: Instance, info: TweenInfo, goal: { [string]: any })
	local t = TweenService:Create(instance, info, goal)
	t:Play()
	return t
end

local function clamp(n: number, minValue: number, maxValue: number): number
	if n < minValue then
		return minValue
	elseif n > maxValue then
		return maxValue
	end
	return n
end

local function safeCount(t: any): number
	if type(t) ~= "table" then
		return 0
	end
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local gui = make("ScreenGui", {
	Name = "WordScriptGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PlayerGui,
})

local shadow = make("Frame", {
	Name = "Shadow",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(364, 256),
	Position = UDim2.new(0.68, 4, 0.22, 6),
	Parent = gui,
})
make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = shadow })

local main = make("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(360, 250),
	Position = UDim2.new(0.68, 0, 0.22, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = gui,
})
make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = main })
make("UIStroke", { Color = Color3.fromRGB(62, 62, 74), Thickness = 1, Transparency = 0.12, Parent = main })

local mainScale = make("UIScale", { Scale = 0.96, Parent = main })

local sizeConstraint = make("UISizeConstraint", {
	MinSize = Vector2.new(320, 200),
	MaxSize = Vector2.new(820, 640),
	Parent = main,
})

local topBar = make("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	BorderSizePixel = 0,
	Parent = main,
})
make("UICorner", { CornerRadius = UDim.new(0, 14), Parent = topBar })

local topCover = make("Frame", {
	Size = UDim2.new(1, 0, 0, 10),
	Position = UDim2.new(0, 0, 1, -10),
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	BorderSizePixel = 0,
	Parent = topBar,
})

local headerLine = make("Frame", {
	Size = UDim2.new(1, -20, 0, 1),
	Position = UDim2.new(0, 10, 1, -1),
	BackgroundColor3 = Color3.fromRGB(45, 45, 55),
	BorderSizePixel = 0,
	Parent = topBar,
})

local title = make("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "WordScript",
	TextColor3 = Color3.fromRGB(240, 240, 246),
	TextSize = 13,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = topBar,
})
title.Position = UDim2.new(0, 12, 0, 0)
title.Size = UDim2.new(1, -120, 1, 0)

local subtitle = make("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "검색 · 추천 · 복사",
	TextColor3 = Color3.fromRGB(150, 150, 160),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = topBar,
})
subtitle.Position = UDim2.new(0, 86, 0, 0)
subtitle.Size = UDim2.new(1, -190, 1, 0)

local minimize = make("TextButton", {
	Size = UDim2.fromOffset(24, 18),
	Position = UDim2.new(1, -54, 0, 7),
	BackgroundColor3 = Color3.fromRGB(39, 39, 48),
	BorderSizePixel = 0,
	Text = "–",
	TextColor3 = Color3.fromRGB(230, 230, 240),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = topBar,
})
make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = minimize })

local close = make("TextButton", {
	Size = UDim2.fromOffset(24, 18),
	Position = UDim2.new(1, -26, 0, 7),
	BackgroundColor3 = Color3.fromRGB(55, 36, 40),
	BorderSizePixel = 0,
	Text = "×",
	TextColor3 = Color3.fromRGB(255, 220, 220),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = topBar,
})
make("UICorner", { CornerRadius = UDim.new(0, 6), Parent = close })

local body = make("Frame", {
	Name = "Body",
	Size = UDim2.new(1, 0, 1, -32),
	Position = UDim2.new(0, 0, 0, 32),
	BackgroundTransparency = 1,
	Parent = main,
})

local bodyPadding = make("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	Parent = body,
})

local searchWrap = make("Frame", {
	Name = "SearchWrap",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Color3.fromRGB(25, 25, 31),
	BorderSizePixel = 0,
	Parent = body,
})
make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = searchWrap })
local searchStroke = make("UIStroke", {
	Color = Color3.fromRGB(49, 49, 60),
	Thickness = 1,
	Transparency = 0.05,
	Parent = searchWrap,
})

local searchBox = make("TextBox", {
	Size = UDim2.new(1, -16, 1, 0),
	Position = UDim2.new(0, 8, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	PlaceholderText = "끝글자 또는 검색어 입력",
	PlaceholderColor3 = Color3.fromRGB(130, 130, 140),
	Text = "",
	ClearTextOnFocus = false,
	TextColor3 = Color3.fromRGB(246, 246, 250),
	TextSize = 12,
	Font = Enum.Font.Gotham,
	Parent = searchWrap,
})

local modeLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "준비 중",
	TextColor3 = Color3.fromRGB(180, 180, 190),
	TextSize = 11,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = body,
})
modeLabel.Position = UDim2.new(0, 2, 0, 46)
modeLabel.Size = UDim2.new(1, -4, 0, 16)

local statsLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "불러오는 중...",
	TextColor3 = Color3.fromRGB(145, 145, 155),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = body,
})
statsLabel.Position = UDim2.new(0, 2, 0, 60)
statsLabel.Size = UDim2.new(1, -4, 0, 14)

local results = make("ScrollingFrame", {
	Name = "Results",
	Size = UDim2.new(1, 0, 1, -96),
	Position = UDim2.new(0, 0, 0, 78),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Color3.fromRGB(96, 96, 112),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.None,
	Parent = body,
})

local layout = make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
	Parent = results,
})

local resultsPadding = make("UIPadding", {
	PaddingTop = UDim.new(0, 2),
	PaddingBottom = UDim.new(0, 2),
	Parent = results,
})

local footer = make("Frame", {
	Name = "Footer",
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.new(0, 0, 1, -18),
	BackgroundTransparency = 1,
	Parent = body,
})

local footerLeft = make("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "클릭 시 단어 복사",
	TextColor3 = Color3.fromRGB(150, 150, 160),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = footer,
})
footerLeft.Size = UDim2.new(1, -110, 1, 0)

local toast = make("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "",
	TextColor3 = Color3.fromRGB(210, 210, 220),
	TextTransparency = 1,
	TextSize = 10,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = footer,
})
toast.Size = UDim2.new(0, 110, 1, 0)
toast.Position = UDim2.new(1, -110, 0, 0)

local resizeHandle = make("TextButton", {
	Name = "ResizeHandle",
	Size = UDim2.fromOffset(24, 24),
	Position = UDim2.new(1, -24, 1, -24),
	BackgroundColor3 = Color3.fromRGB(31, 31, 38),
	BorderSizePixel = 0,
	Text = "◢",
	TextColor3 = Color3.fromRGB(195, 195, 205),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = main,
})
make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = resizeHandle })

local resizeStroke = make("UIStroke", {
	Color = Color3.fromRGB(58, 58, 70),
	Thickness = 1,
	Transparency = 0.15,
	Parent = resizeHandle,
})

local function applyButtonStyle(btn: TextButton, normalBg: Color3, hoverBg: Color3)
	local function set(bg: Color3)
		btn.BackgroundColor3 = bg
	end

	btn.MouseEnter:Connect(function()
		tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = hoverBg })
	end)

	btn.MouseLeave:Connect(function()
		tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = normalBg })
	end)

	btn.MouseButton1Down:Connect(function()
		tween(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = hoverBg })
	end)

	btn.MouseButton1Up:Connect(function()
		tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = hoverBg })
	end)

	set(normalBg)
end

applyButtonStyle(minimize, Color3.fromRGB(39, 39, 48), Color3.fromRGB(49, 49, 60))
applyButtonStyle(close, Color3.fromRGB(55, 36, 40), Color3.fromRGB(76, 44, 50))

local minimized = false
local dragging = false
local draggingResize = false

local dragStart: Vector2? = nil
local startPos: UDim2? = nil

local resizeStart: Vector2? = nil
local startSize: Vector2? = nil
local startMainPos: UDim2? = nil

local MIN_W, MIN_H = 320, 200
local MAX_W, MAX_H = 820, 640

local function updateShadow()
	shadow.Size = UDim2.new(0, main.AbsoluteSize.X + 8, 0, main.AbsoluteSize.Y + 8)
	shadow.Position = UDim2.new(main.Position.X.Scale, main.Position.X.Offset + 4, main.Position.Y.Scale, main.Position.Y.Offset + 6)
end

local function setMainSize(w: number, h: number)
	w = clamp(w, MIN_W, MAX_W)
	h = clamp(h, MIN_H, MAX_H)
	main.Size = UDim2.fromOffset(w, h)
	updateShadow()
end

local function animateOpen()
	mainScale.Scale = 0.96
	tween(mainScale, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 })
end

local function setMinimized(state: boolean)
	minimized = state
	body.Visible = not state
	resizeHandle.Visible = not state

	local targetHeight = state and 32 or 250
	local targetWidth = main.AbsoluteSize.X > 0 and main.AbsoluteSize.X or 360

	tween(main, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(targetWidth, targetHeight),
	})

	updateShadow()
end

local function clearResults()
	for _, child in ipairs(results:GetChildren()) do
		if child:IsA("GuiObject") and child ~= layout and child ~= resultsPadding then
			child:Destroy()
		end
	end
end

local function notify(message: string)
	toast.Text = message
	toast.TextTransparency = 1
	tween(toast, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
	task.delay(1.2, function()
		if toast.Parent then
			tween(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 })
		end
	end)
end

local function copyWord(word: string)
	if typeof(setclipboard) == "function" then
		setclipboard(word)
		notify("복사됨")
	else
		notify("클립보드 미지원")
	end
end

local function createResultCard(word: string, tagColor: Color3?)
	local item = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = results,
	})

	make("UICorner", { CornerRadius = UDim.new(0, 9), Parent = item })
	local stroke = make("UIStroke", {
		Color = Color3.fromRGB(44, 44, 54),
		Thickness = 1,
		Transparency = 0.1,
		Parent = item,
	})

	local accent = make("Frame", {
		Size = UDim2.new(0, 4, 1, -10),
		Position = UDim2.new(0, 8, 0, 5),
		BackgroundColor3 = tagColor or Color3.fromRGB(110, 130, 255),
		BorderSizePixel = 0,
		Parent = item,
	})
	make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = accent })

	local wordLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = word,
		TextColor3 = Color3.fromRGB(240, 240, 246),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = item,
	})
	wordLabel.Position = UDim2.new(0, 20, 0, 0)
	wordLabel.Size = UDim2.new(1, -28, 1, 0)

	local function hover(on: boolean)
		if on then
			tween(item, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = Color3.fromRGB(30, 30, 38),
			})
			tween(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = Color3.fromRGB(66, 66, 78),
			})
		else
			tween(item, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = Color3.fromRGB(24, 24, 30),
			})
			tween(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = Color3.fromRGB(44, 44, 54),
			})
		end
	end

	item.MouseEnter:Connect(function()
		hover(true)
	end)

	item.MouseLeave:Connect(function()
		hover(false)
	end)

	item.MouseButton1Click:Connect(function()
		copyWord(word)
	end)
end

local function sortWords(list: { string })
	table.sort(list, function(a: string, b: string)
		local ap = false
		local bp = false

		if type(WordHub.isPriority) == "function" then
			ap = WordHub.isPriority(a) and true or false
			bp = WordHub.isPriority(b) and true or false
		end

		if ap ~= bp then
			return ap and not bp
		end

		if #a ~= #b then
			return #a < #b
		end

		return a < b
	end)
end

local function collectCandidates(query: string): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}

	local function push(word: string)
		if not seen[word] then
			seen[word] = true
			table.insert(out, word)
		end
	end

	local special = WordHub.special
	local indexAll = Index and Index.all or {}
	local byFirst = Index and Index.byFirst or {}

	if query == "" then
		if type(special) == "table" then
			for _, word in ipairs(special) do
				if type(word) == "string" then
					push(word)
				end
			end
		end
		return out
	end

	local seed = getLastCharacter(query)

	if seed ~= "" then
		local fromSeed = byFirst[seed]
		if type(fromSeed) == "table" then
			for _, word in ipairs(fromSeed) do
				if type(word) == "string" then
					push(word)
				end
			end
		end
	end

	if #query > 1 then
		for _, word in ipairs(indexAll) do
			if type(word) == "string" and string.find(word, query, 1, true) then
				push(word)
			end
		end
	end

	if type(special) == "table" then
		for _, word in ipairs(special) do
			if type(word) == "string" and (string.find(word, query, 1, true) or (seed ~= "" and string.find(word, seed, 1, true))) then
				push(word)
			end
		end
	end

	return out
end

local function updateCanvas()
	task.defer(function()
		results.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 6)
	end)
end

local function updateStatsText(query: string, candidatesCount: number)
	if query == "" then
		modeLabel.Text = "특수 단어"
		statsLabel.Text = string.format(
			"전체 %d개 · 특수 %d개",
			safeCount(Index and Index.all or {}),
			safeCount(WordHub.special or {})
		)
	elseif #query == 1 then
		modeLabel.Text = "끝글자 추천"
		statsLabel.Text = string.format("%d개", candidatesCount)
	else
		modeLabel.Text = "전체 검색"
		statsLabel.Text = string.format("%d개", candidatesCount)
	end
end

local function update()
	local query = searchBox.Text or ""
	query = query:gsub("%s+", "")

	clearResults()

	local candidates = collectCandidates(query)
	sortWords(candidates)

	updateStatsText(query, #candidates)

	if #candidates == 0 then
		local empty = make("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "결과 없음",
			TextColor3 = Color3.fromRGB(160, 160, 170),
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = results,
		})
		empty.Size = UDim2.new(1, 0, 0, 24)
		updateCanvas()
		return
	end

	if query == "" then
		local shown = 0
		for _, word in ipairs(candidates) do
			shown += 1
			if shown > 18 then
				break
			end
			createResultCard(word, Color3.fromRGB(120, 150, 255))
		end
	else
		local shown = 0
		for _, word in ipairs(candidates) do
			shown += 1
			if shown > 26 then
				break
			end

			local tagColor: Color3? = nil
			if type(WordHub.isPriority) == "function" and WordHub.isPriority(word) then
				tagColor = Color3.fromRGB(255, 190, 70)
			end
			createResultCard(word, tagColor)
		end
	end

	updateCanvas()
end

searchBox:GetPropertyChangedSignal("Text"):Connect(update)

searchBox.Focused:Connect(function()
	tween(searchStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(96, 112, 255),
	})
end)

searchBox.FocusLost:Connect(function()
	tween(searchStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(49, 49, 60),
	})
end)

minimize.MouseButton1Click:Connect(function()
	setMinimized(not minimized)
end)

close.MouseButton1Click:Connect(function()
	tween(mainScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 })
	task.delay(0.05, function()
		if gui then
			gui:Destroy()
		end
	end)
end)

local dragInput: InputObject? = nil

topBar.InputBegan:Connect(function(input)
	if minimized then
		return
	end

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
		updateShadow()
	end
end)

local function beginResize(input: InputObject)
	if minimized then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingResize = true
		resizeStart = input.Position
		startSize = Vector2.new(main.AbsoluteSize.X, main.AbsoluteSize.Y)
		startMainPos = main.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				draggingResize = false
			end
		end)
	end
end

resizeHandle.InputBegan:Connect(beginResize)

resizeHandle.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if draggingResize and resizeStart and startSize and startMainPos then
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - resizeStart
			local newW = clamp(startSize.X + delta.X, MIN_W, MAX_W)
			local newH = clamp(startSize.Y + delta.Y, MIN_H, MAX_H)

			main.Size = UDim2.fromOffset(newW, newH)
			updateShadow()
		end
	end
end)

main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	updateShadow()
	if not minimized then
		updateCanvas()
	end
end)

if type(WordHub.getStats) == "function" then
	local stats = WordHub.getStats()
	if type(stats) == "table" then
		statsLabel.Text = string.format(
			"그룹 %d · 전체 %d · 우선 %d",
			tonumber(stats.groups) or 0,
			tonumber(stats.unique) or 0,
			tonumber(stats.special) or 0
		)
	else
		statsLabel.Text = "준비 완료"
	end
else
	statsLabel.Text = "준비 완료"
end

animateOpen()
update()
updateShadow()
