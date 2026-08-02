--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function safeGetIndex(source: any): any
	if type(source) ~= "table" then
		return nil
	end
	return source.index
end

local function safeConcat(a: string, b: string, c: string): string
	return table.concat({ a, b, c })
end

local function clamp(n: number, minValue: number, maxValue: number): number
	if n < minValue then
		return minValue
	end
	if n > maxValue then
		return maxValue
	end
	return n
end

local function create(className: string, props: { [string]: any }?)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	return inst
end

local function tween(inst: Instance, info: TweenInfo, goal: { [string]: any })
	local tw = TweenService:Create(inst, info, goal)
	tw:Play()
	return tw
end

local function countTable(t: any): number
	if type(t) ~= "table" then
		return 0
	end
	local c = 0
	for _ in pairs(t) do
		c += 1
	end
	return c
end

local function firstGrapheme(s: string): string
	if s == "" then
		return ""
	end
	for startIndex, endIndex in utf8.graphemes(s) do
		return string.sub(s, startIndex, endIndex)
	end
	return ""
end

local function lastGrapheme(s: string): string
	if s == "" then
		return ""
	end
	local result = ""
	for startIndex, endIndex in utf8.graphemes(s) do
		result = string.sub(s, startIndex, endIndex)
	end
	return result
end

local function getClipParent(): Instance
	local ok = pcall(function()
		CoreGui:GetChildren()
	end)

	if ok then
		local existing = CoreGui:FindFirstChild("WordScriptCoreUI")
		if existing then
			existing:Destroy()
		end
		return CoreGui
	end

	local existing = PlayerGui:FindFirstChild("WordScriptCoreUI")
	if existing then
		existing:Destroy()
	end
	return PlayerGui
end

local parentGui = getClipParent()

local hubUrl = safeConcat(
	"https://raw.github",
	"usercontent.com",
	"/cjwstar25-png/rorwjm/main/word.lua"
)

local okHub, Hub = pcall(function()
	return loadstring(game:HttpGet(hubUrl))()
end)

if not okHub or type(Hub) ~= "table" then
	warn("[WordScript] Hub load failed")
	return
end

local IDX = safeGetIndex(Hub)
if not IDX then
	if type(Hub.buildIndex) == "function" then
		IDX = Hub.buildIndex()
		Hub.index = IDX
	else
		warn("[WordScript] index missing")
		return
	end
end

local function isPriority(word: string): boolean
	if type(Hub.isPriority) == "function" then
		local ok, result = pcall(Hub.isPriority, word)
		return ok and result == true
	end
	return false
end

local function getStatsText(): string
	if type(Hub.getStats) == "function" then
		local ok, st = pcall(Hub.getStats)
		if ok and type(st) == "table" then
			return string.format(
				"그룹 %d · 전체 %d · 우선 %d",
				tonumber(st.groups) or 0,
				tonumber(st.unique) or 0,
				tonumber(st.special) or 0
			)
		end
	end
	return "준비 완료"
end

local Gui = create("ScreenGui", {
	Name = "WordScriptCoreUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999999,
	Parent = parentGui,
})

local Shade = create("Frame", {
	Name = "Shade",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(368, 262),
	Position = UDim2.new(0.68, 4, 0.22, 6),
	Parent = Gui,
})
create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Shade })

local Root = create("Frame", {
	Name = "Root",
	Size = UDim2.fromOffset(360, 254),
	Position = UDim2.new(0.68, 0, 0.22, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = Gui,
})
create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Root })
create("UIStroke", {
	Color = Color3.fromRGB(64, 64, 76),
	Thickness = 1,
	Transparency = 0.12,
	Parent = Root,
})

local Scale = create("UIScale", {
	Scale = 0.96,
	Parent = Root,
})

create("UISizeConstraint", {
	MinSize = Vector2.new(320, 200),
	MaxSize = Vector2.new(920, 680),
	Parent = Root,
})

local Bar = create("Frame", {
	Name = "Bar",
	Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	BorderSizePixel = 0,
	Parent = Root,
})
create("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Bar })

create("Frame", {
	Size = UDim2.new(1, 0, 0, 10),
	Position = UDim2.new(0, 0, 1, -10),
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	BorderSizePixel = 0,
	Parent = Bar,
})

create("Frame", {
	Size = UDim2.new(1, -20, 0, 1),
	Position = UDim2.new(0, 10, 1, -1),
	BackgroundColor3 = Color3.fromRGB(45, 45, 55),
	BorderSizePixel = 0,
	Parent = Bar,
})

local Title = create("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "끝말잇기",
	TextColor3 = Color3.fromRGB(242, 242, 248),
	TextSize = 13,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Bar,
})
Title.Position = UDim2.new(0, 12, 0, 0)
Title.Size = UDim2.new(1, -120, 1, 0)

local Subtitle = create("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "Cube",
	TextColor3 = Color3.fromRGB(150, 150, 160),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Bar,
})
Subtitle.Position = UDim2.new(0, 108, 0, 0)
Subtitle.Size = UDim2.new(1, -190, 1, 0)

local MinButton = create("TextButton", {
	Size = UDim2.fromOffset(24, 18),
	Position = UDim2.new(1, -54, 0, 7),
	BackgroundColor3 = Color3.fromRGB(39, 39, 48),
	BorderSizePixel = 0,
	Text = "–",
	TextColor3 = Color3.fromRGB(232, 232, 240),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = Bar,
})
create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = MinButton })

local CloseButton = create("TextButton", {
	Size = UDim2.fromOffset(24, 18),
	Position = UDim2.new(1, -26, 0, 7),
	BackgroundColor3 = Color3.fromRGB(55, 36, 40),
	BorderSizePixel = 0,
	Text = "×",
	TextColor3 = Color3.fromRGB(255, 220, 220),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = Bar,
})
create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = CloseButton })

local Body = create("Frame", {
	Name = "Body",
	Size = UDim2.new(1, 0, 1, -32),
	Position = UDim2.new(0, 0, 0, 32),
	BackgroundTransparency = 1,
	Parent = Root,
})

create("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	Parent = Body,
})

local SearchWrap = create("Frame", {
	Name = "SearchWrap",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Color3.fromRGB(25, 25, 31),
	BorderSizePixel = 0,
	Parent = Body,
})
create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = SearchWrap })
local SearchStroke = create("UIStroke", {
	Color = Color3.fromRGB(49, 49, 60),
	Thickness = 1,
	Transparency = 0.05,
	Parent = SearchWrap,
})

local SearchBox = create("TextBox", {
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
	Parent = SearchWrap,
})

local Mode = create("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "준비 중",
	TextColor3 = Color3.fromRGB(182, 182, 190),
	TextSize = 11,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Body,
})
Mode.Position = UDim2.new(0, 2, 0, 46)
Mode.Size = UDim2.new(1, -4, 0, 16)

local Stats = create("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "불러오는 중...",
	TextColor3 = Color3.fromRGB(145, 145, 155),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Body,
})
Stats.Position = UDim2.new(0, 2, 0, 60)
Stats.Size = UDim2.new(1, -4, 0, 14)

local Results = create("ScrollingFrame", {
	Name = "Results",
	Size = UDim2.new(1, 0, 1, -96),
	Position = UDim2.new(0, 0, 0, 78),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Color3.fromRGB(96, 96, 112),
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Parent = Body,
})

local Layout = create("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
	Parent = Results,
})

create("UIPadding", {
	PaddingTop = UDim.new(0, 2),
	PaddingBottom = UDim.new(0, 2),
	Parent = Results,
})

local Foot = create("Frame", {
	Name = "Foot",
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.new(0, 0, 1, -18),
	BackgroundTransparency = 1,
	Parent = Body,
})

local Hint = create("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "클릭 시 단어 복사",
	TextColor3 = Color3.fromRGB(150, 150, 160),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Foot,
})
Hint.Size = UDim2.new(1, -110, 1, 0)

local Toast = create("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "",
	TextColor3 = Color3.fromRGB(210, 210, 220),
	TextTransparency = 1,
	TextSize = 10,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = Foot,
})
Toast.Size = UDim2.new(0, 110, 1, 0)
Toast.Position = UDim2.new(1, -110, 0, 0)

local ResizeHandle = create("TextButton", {
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
	Parent = Root,
})
create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = ResizeHandle })
create("UIStroke", {
	Color = Color3.fromRGB(58, 58, 70),
	Thickness = 1,
	Transparency = 0.15,
	Parent = ResizeHandle,
})

local function styleButton(btn: TextButton, normalBg: Color3, hoverBg: Color3)
	btn.BackgroundColor3 = normalBg
	btn.MouseEnter:Connect(function()
		tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverBg,
		})
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = normalBg,
		})
	end)
	btn.MouseButton1Down:Connect(function()
		tween(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverBg,
		})
	end)
	btn.MouseButton1Up:Connect(function()
		tween(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverBg,
		})
	end)
end

styleButton(MinButton, Color3.fromRGB(39, 39, 48), Color3.fromRGB(49, 49, 60))
styleButton(CloseButton, Color3.fromRGB(55, 36, 40), Color3.fromRGB(76, 44, 50))

local minimized = false
local dragging = false
local resizing = false
local dragStart: Vector2? = nil
local dragPos: UDim2? = nil
local resizeStart: Vector2? = nil
local resizeSize: Vector2? = nil

local MIN_W, MIN_H = 320, 200
local MAX_W, MAX_H = 920, 680

local function syncShade()
	Shade.Size = UDim2.fromOffset(Root.AbsoluteSize.X + 8, Root.AbsoluteSize.Y + 8)
	Shade.Position = UDim2.new(
		Root.Position.X.Scale,
		Root.Position.X.Offset + 4,
		Root.Position.Y.Scale,
		Root.Position.Y.Offset + 6
	)
end

local function refreshCanvas()
	Results.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 6)
end

local function safeSetSize(w: number, h: number)
	Root.Size = UDim2.fromOffset(clamp(w, MIN_W, MAX_W), clamp(h, MIN_H, MAX_H))
	syncShade()
	refreshCanvas()
end

local function openAnim()
	Scale.Scale = 0.96
	tween(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Scale = 1,
	})
end

local function fadeToast(msg: string)
	Toast.Text = msg
	Toast.TextTransparency = 1
	tween(Toast, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	})
	task.delay(1.15, function()
		if Toast.Parent then
			tween(Toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 1,
			})
		end
	end)
end

local function copyWord(word: string)
	if typeof(setclipboard) == "function" then
		setclipboard(word)
		fadeToast("복사됨")
	else
		fadeToast("클립보드 미지원")
	end
end

local function clearResults()
	for _, child in ipairs(Results:GetChildren()) do
		if child:IsA("GuiObject") and child ~= Layout then
			child:Destroy()
		end
	end
end

local function addItem(word: string, tagColor: Color3?)
	local item = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = Results,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 9), Parent = item })
	local stroke = create("UIStroke", {
		Color = Color3.fromRGB(44, 44, 54),
		Thickness = 1,
		Transparency = 0.1,
		Parent = item,
	})
	local accent = create("Frame", {
		Size = UDim2.new(0, 4, 1, -10),
		Position = UDim2.new(0, 8, 0, 5),
		BackgroundColor3 = tagColor or Color3.fromRGB(110, 130, 255),
		BorderSizePixel = 0,
		Parent = item,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = accent })

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = word,
		TextColor3 = Color3.fromRGB(240, 240, 246),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = item,
	})
	label.Position = UDim2.new(0, 20, 0, 0)
	label.Size = UDim2.new(1, -28, 1, 0)

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
		local ap = isPriority(a)
		local bp = isPriority(b)

		if ap ~= bp then
			return ap and not bp
		end
		if #a ~= #b then
			return #a < #b
		end
		return a < b
	end)
end

local function collect(query: string): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}

	local function push(word: string)
		if not seen[word] then
			seen[word] = true
			table.insert(out, word)
		end
	end

	local special = Hub.special
	local all = IDX and IDX.all or {}
	local byFirst = IDX and IDX.byFirst or {}

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

	local seed = lastGrapheme(query)

	if seed ~= "" then
		local firstList = byFirst[seed]
		if type(firstList) == "table" then
			for _, word in ipairs(firstList) do
				if type(word) == "string" then
					push(word)
				end
			end
		end
	end

	if #query > 1 then
		for _, word in ipairs(all) do
			if type(word) == "string" and string.find(word, query, 1, true) then
				push(word)
			end
		end
	end

	if type(special) == "table" then
		for _, word in ipairs(special) do
			if type(word) == "string" and (
				string.find(word, query, 1, true) or
				(seed ~= "" and string.find(word, seed, 1, true))
			) then
				push(word)
			end
		end
	end

	return out
end

local function setStats(query: string, count: number)
	if query == "" then
		Mode.Text = "특수 단어"
		Stats.Text = string.format("전체 %d개 · 특수 %d개", countTable(IDX and IDX.all or {}), countTable(Hub.special or {}))
	elseif #query == 1 then
		Mode.Text = "끝글자 추천"
		Stats.Text = string.format("%d개", count)
	else
		Mode.Text = "전체 검색"
		Stats.Text = string.format("%d개", count)
	end
end

local function refresh()
	local query = SearchBox.Text or ""
	query = query:gsub("%s+", "")

	clearResults()

	local found = collect(query)
	sortWords(found)
	setStats(query, #found)

	if #found == 0 then
		local empty = create("TextLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "결과 없음",
			TextColor3 = Color3.fromRGB(160, 160, 170),
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = Results,
		})
		empty.Size = UDim2.new(1, 0, 0, 24)
		refreshCanvas()
		return
	end

	if query == "" then
		local shown = 0
		for _, word in ipairs(found) do
			shown += 1
			if shown > 18 then
				break
			end
			addItem(word, Color3.fromRGB(120, 150, 255))
		end
	else
		local shown = 0
		for _, word in ipairs(found) do
			shown += 1
			if shown > 26 then
				break
			end
			local tag: Color3? = nil
			if isPriority(word) then
				tag = Color3.fromRGB(255, 190, 70)
			end
			addItem(word, tag)
		end
	end

	refreshCanvas()
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(refresh)

SearchBox.Focused:Connect(function()
	tween(SearchStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(96, 112, 255),
	})
end)

SearchBox.FocusLost:Connect(function()
	tween(SearchStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(49, 49, 60),
	})
end)

MinButton.MouseButton1Click:Connect(function()
	minimized = not minimized
	Body.Visible = not minimized
	ResizeHandle.Visible = not minimized

	local w = Root.AbsoluteSize.X > 0 and Root.AbsoluteSize.X or 360
	local h = minimized and 32 or 254

	tween(Root, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(w, h),
	})
	syncShade()
end)

CloseButton.MouseButton1Click:Connect(function()
	tween(Scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.94,
	})
	task.delay(0.05, function()
		if Gui then
			Gui:Destroy()
		end
	end)
end)

local dragInput: InputObject? = nil
Bar.InputBegan:Connect(function(input)
	if minimized then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		dragPos = Root.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				dragInput = nil
			end
		end)
	end
end)

Bar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and dragInput and input == dragInput and dragStart and dragPos then
		local delta = input.Position - dragStart
		Root.Position = UDim2.new(
			dragPos.X.Scale,
			dragPos.X.Offset + delta.X,
			dragPos.Y.Scale,
			dragPos.Y.Offset + delta.Y
		)
		syncShade()
	end
end)

local function beginResize(input: InputObject)
	if minimized then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStart = input.Position
		resizeSize = Vector2.new(Root.AbsoluteSize.X, Root.AbsoluteSize.Y)
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				resizing = false
			end
		end)
	end
end

ResizeHandle.InputBegan:Connect(beginResize)

UserInputService.InputChanged:Connect(function(input)
	if resizing and resizeStart and resizeSize then
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - resizeStart
			local newW = clamp(resizeSize.X + delta.X, MIN_W, MAX_W)
			local newH = clamp(resizeSize.Y + delta.Y, MIN_H, MAX_H)
			Root.Size = UDim2.fromOffset(newW, newH)
			syncShade()
			if not minimized then
				refreshCanvas()
			end
		end
	end
end)

Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	syncShade()
	if not minimized then
		refreshCanvas()
	end
end)

Stats.Text = getStatsText()
openAnim()
refresh()
syncShade()
