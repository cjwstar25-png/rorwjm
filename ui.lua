--!strict2
local P = game:GetService("Players")
local U = game:GetService("UserInputService")
local T = game:GetService("TweenService")

local L = P.LocalPlayer
local G = L:WaitForChild("PlayerGui")

local function S(a: string, b: string, c: string): string
	return table.concat({ a, b, c })
end

local function N(n: number, a: number, b: number): number
	if n < a then
		return a
	end
	if n > b then
		return b
	end
	return n
end

local function M(className: string, props: { [string]: any }?)
	local o = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			o[k] = v
		end
	end
	return o
end

local function Tw(inst: Instance, ti: TweenInfo, goal: { [string]: any })
	local tw = T:Create(inst, ti, goal)
	tw:Play()
	return tw
end

local function Cnt(t: any): number
	if type(t) ~= "table" then
		return 0
	end
	local c = 0
	for _ in pairs(t) do
		c += 1
	end
	return c
end

local function GR(a: string): string
	if a == "" then
		return ""
	end
	local r = ""
	for s, e in utf8.graphemes(a) do
		r = string.sub(a, s, e)
		break
	end
	return r
end

local function GL(a: string): string
	if a == "" then
		return ""
	end
	local r = ""
	for s, e in utf8.graphemes(a) do
		r = string.sub(a, s, e)
	end
	return r
end

local UURL = S("https://", "raw.github", "usercontent.com/cjwstar25-png/rorwjm/main/word.lua")

local ok, Hub = pcall(function()
	return loadstring(game:HttpGet(UURL))()
end)

if not ok or type(Hub) ~= "table" then
	warn("[WordScript] load failed")
	return
end

local IDX = Hub.index
if not IDX then
	if type(Hub.buildIndex) == "function" then
		IDX = Hub.buildIndex()
		Hub.index = IDX
	else
		warn("[WordScript] index missing")
		return
	end
end

local Gui = M("ScreenGui", {
	Name = "WordScriptGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = G,
})

local Shade = M("Frame", {
	Name = "Shade",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.58,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(364, 256),
	Position = UDim2.new(0.68, 4, 0.22, 6),
	Parent = Gui,
})
M("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Shade })

local Root = M("Frame", {
	Name = "Root",
	Size = UDim2.fromOffset(360, 250),
	Position = UDim2.new(0.68, 0, 0.22, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 22),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = Gui,
})
M("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Root })
M("UIStroke", { Color = Color3.fromRGB(62, 62, 74), Thickness = 1, Transparency = 0.12, Parent = Root })

local Scale = M("UIScale", { Scale = 0.96, Parent = Root })

M("UISizeConstraint", {
	MinSize = Vector2.new(320, 200),
	MaxSize = Vector2.new(820, 640),
	Parent = Root,
})

local Bar = M("Frame", {
	Name = "Bar",
	Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	BorderSizePixel = 0,
	Parent = Root,
})
M("UICorner", { CornerRadius = UDim.new(0, 14), Parent = Bar })

M("Frame", {
	Size = UDim2.new(1, 0, 0, 10),
	Position = UDim2.new(0, 0, 1, -10),
	BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	BorderSizePixel = 0,
	Parent = Bar,
})

M("Frame", {
	Size = UDim2.new(1, -20, 0, 1),
	Position = UDim2.new(0, 10, 1, -1),
	BackgroundColor3 = Color3.fromRGB(45, 45, 55),
	BorderSizePixel = 0,
	Parent = Bar,
})

local T1 = M("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "WordScript",
	TextColor3 = Color3.fromRGB(240, 240, 246),
	TextSize = 13,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Bar,
})
T1.Position = UDim2.new(0, 12, 0, 0)
T1.Size = UDim2.new(1, -120, 1, 0)

local T2 = M("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "검색 · 추천 · 복사",
	TextColor3 = Color3.fromRGB(150, 150, 160),
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Bar,
})
T2.Position = UDim2.new(0, 86, 0, 0)
T2.Size = UDim2.new(1, -190, 1, 0)

local MinB = M("TextButton", {
	Size = UDim2.fromOffset(24, 18),
	Position = UDim2.new(1, -54, 0, 7),
	BackgroundColor3 = Color3.fromRGB(39, 39, 48),
	BorderSizePixel = 0,
	Text = "–",
	TextColor3 = Color3.fromRGB(230, 230, 240),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	Parent = Bar,
})
M("UICorner", { CornerRadius = UDim.new(0, 6), Parent = MinB })

local ClsB = M("TextButton", {
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
M("UICorner", { CornerRadius = UDim.new(0, 6), Parent = ClsB })

local Body = M("Frame", {
	Name = "Body",
	Size = UDim2.new(1, 0, 1, -32),
	Position = UDim2.new(0, 0, 0, 32),
	BackgroundTransparency = 1,
	Parent = Root,
})

M("UIPadding", {
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	Parent = Body,
})

local SW = M("Frame", {
	Name = "SW",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = Color3.fromRGB(25, 25, 31),
	BorderSizePixel = 0,
	Parent = Body,
})
M("UICorner", { CornerRadius = UDim.new(0, 10), Parent = SW })
local SStroke = M("UIStroke", {
	Color = Color3.fromRGB(49, 49, 60),
	Thickness = 1,
	Transparency = 0.05,
	Parent = SW,
})

local Search = M("TextBox", {
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
	Parent = SW,
})

local Mode = M("TextLabel", {
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "준비 중",
	TextColor3 = Color3.fromRGB(180, 180, 190),
	TextSize = 11,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Body,
})
Mode.Position = UDim2.new(0, 2, 0, 46)
Mode.Size = UDim2.new(1, -4, 0, 16)

local Stats = M("TextLabel", {
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

local Results = M("ScrollingFrame", {
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

local List = M("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
	Parent = Results,
})

M("UIPadding", {
	PaddingTop = UDim.new(0, 2),
	PaddingBottom = UDim.new(0, 2),
	Parent = Results,
})

local Foot = M("Frame", {
	Name = "Foot",
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.new(0, 0, 1, -18),
	BackgroundTransparency = 1,
	Parent = Body,
})

local Hint = M("TextLabel", {
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

local Toast = M("TextLabel", {
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

local RH = M("TextButton", {
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
M("UICorner", { CornerRadius = UDim.new(0, 8), Parent = RH })
M("UIStroke", { Color = Color3.fromRGB(58, 58, 70), Thickness = 1, Transparency = 0.15, Parent = RH })

local function BtnStyle(B: TextButton, normalBg: Color3, hoverBg: Color3)
	B.BackgroundColor3 = normalBg
	B.MouseEnter:Connect(function()
		Tw(B, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = hoverBg })
	end)
	B.MouseLeave:Connect(function()
		Tw(B, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = normalBg })
	end)
	B.MouseButton1Down:Connect(function()
		Tw(B, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = hoverBg })
	end)
	B.MouseButton1Up:Connect(function()
		Tw(B, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = hoverBg })
	end)
end

BtnStyle(MinB, Color3.fromRGB(39, 39, 48), Color3.fromRGB(49, 49, 60))
BtnStyle(ClsB, Color3.fromRGB(55, 36, 40), Color3.fromRGB(76, 44, 50))

local minimized = false
local dragging = false
local resizing = false

local dragStart: Vector2? = nil
local dragPos: UDim2? = nil

local resizeStart: Vector2? = nil
local resizeSize: Vector2? = nil

local MIN_W, MIN_H = 320, 200
local MAX_W, MAX_H = 820, 640

local function SyncShade()
	Shade.Size = UDim2.fromOffset(Root.AbsoluteSize.X + 8, Root.AbsoluteSize.Y + 8)
	Shade.Position = UDim2.new(Root.Position.X.Scale, Root.Position.X.Offset + 4, Root.Position.Y.Scale, Root.Position.Y.Offset + 6)
end

local function SafeSetSize(w: number, h: number)
	Root.Size = UDim2.fromOffset(N(w, MIN_W, MAX_W), N(h, MIN_H, MAX_H))
	SyncShade()
end

local function OpenAnim()
	Scale.Scale = 0.96
	Tw(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 })
end

local function FadeToast(msg: string)
	Toast.Text = msg
	Toast.TextTransparency = 1
	Tw(Toast, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
	task.delay(1.15, function()
		if Toast.Parent then
			Tw(Toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 })
		end
	end)
end

local function CopyWord(w: string)
	if typeof(setclipboard) == "function" then
		setclipboard(w)
		FadeToast("복사됨")
	else
		FadeToast("클립보드 미지원")
	end
end

local function ClearResults()
	for _, ch in ipairs(Results:GetChildren()) do
		if ch:IsA("GuiObject") and ch ~= List then
			ch:Destroy()
		end
	end
end

local function AddItem(word: string, tagColor: Color3?)
	local item = M("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = Results,
	})
	M("UICorner", { CornerRadius = UDim.new(0, 9), Parent = item })
	local st = M("UIStroke", {
		Color = Color3.fromRGB(44, 44, 54),
		Thickness = 1,
		Transparency = 0.1,
		Parent = item,
	})

	local a = M("Frame", {
		Size = UDim2.new(0, 4, 1, -10),
		Position = UDim2.new(0, 8, 0, 5),
		BackgroundColor3 = tagColor or Color3.fromRGB(110, 130, 255),
		BorderSizePixel = 0,
		Parent = item,
	})
	M("UICorner", { CornerRadius = UDim.new(1, 0), Parent = a })

	local lab = M("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = word,
		TextColor3 = Color3.fromRGB(240, 240, 246),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = item,
	})
	lab.Position = UDim2.new(0, 20, 0, 0)
	lab.Size = UDim2.new(1, -28, 1, 0)

	local function hov(on: boolean)
		if on then
			Tw(item, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = Color3.fromRGB(30, 30, 38),
			})
			Tw(st, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = Color3.fromRGB(66, 66, 78),
			})
		else
			Tw(item, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = Color3.fromRGB(24, 24, 30),
			})
			Tw(st, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = Color3.fromRGB(44, 44, 54),
			})
		end
	end

	item.MouseEnter:Connect(function()
		hov(true)
	end)
	item.MouseLeave:Connect(function()
		hov(false)
	end)
	item.MouseButton1Click:Connect(function()
		CopyWord(word)
	end)
end

local function SortWords(list: { string })
	table.sort(list, function(a: string, b: string)
		local ap = false
		local bp = false
		if type(Hub.isPriority) == "function" then
			ap = Hub.isPriority(a) and true or false
			bp = Hub.isPriority(b) and true or false
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

local function Collect(q: string): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}

	local function push(w: string)
		if not seen[w] then
			seen[w] = true
			table.insert(out, w)
		end
	end

	local special = Hub.special
	local all = IDX and IDX.all or {}
	local byFirst = IDX and IDX.byFirst or {}

	if q == "" then
		if type(special) == "table" then
			for _, w in ipairs(special) do
				if type(w) == "string" then
					push(w)
				end
			end
		end
		return out
	end

	local seed = GL(q)

	if seed ~= "" then
		local first = byFirst[seed]
		if type(first) == "table" then
			for _, w in ipairs(first) do
				if type(w) == "string" then
					push(w)
				end
			end
		end
	end

	if #q > 1 then
		for _, w in ipairs(all) do
			if type(w) == "string" and string.find(w, q, 1, true) then
				push(w)
			end
		end
	end

	if type(special) == "table" then
		for _, w in ipairs(special) do
			if type(w) == "string" and (string.find(w, q, 1, true) or (seed ~= "" and string.find(w, seed, 1, true))) then
				push(w)
			end
		end
	end

	return out
end

local function SetStats(q: string, count: number)
	if q == "" then
		Mode.Text = "특수 단어"
		Stats.Text = string.format("전체 %d개 · 특수 %d개", Cnt(IDX and IDX.all or {}), Cnt(Hub.special or {}))
	elseif #q == 1 then
		Mode.Text = "끝글자 추천"
		Stats.Text = string.format("%d개", count)
	else
		Mode.Text = "전체 검색"
		Stats.Text = string.format("%d개", count)
	end
end

local function Refresh()
	local q = Search.Text or ""
	q = q:gsub("%s+", "")

	ClearResults()

	local found = Collect(q)
	SortWords(found)
	SetStats(q, #found)

	if #found == 0 then
		local empty = M("TextLabel", {
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
		Results.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 6)
		return
	end

	if q == "" then
		local shown = 0
		for _, w in ipairs(found) do
			shown += 1
			if shown > 18 then
				break
			end
			AddItem(w, Color3.fromRGB(120, 150, 255))
		end
	else
		local shown = 0
		for _, w in ipairs(found) do
			shown += 1
			if shown > 26 then
				break
			end
			local tag: Color3? = nil
			if type(Hub.isPriority) == "function" and Hub.isPriority(w) then
				tag = Color3.fromRGB(255, 190, 70)
			end
			AddItem(w, tag)
		end
	end

	Results.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 6)
end

Search:GetPropertyChangedSignal("Text"):Connect(Refresh)

Search.Focused:Connect(function()
	Tw(SStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(96, 112, 255),
	})
end)

Search.FocusLost:Connect(function()
	Tw(SStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(49, 49, 60),
	})
end)

MinB.MouseButton1Click:Connect(function()
	minimized = not minimized
	Body.Visible = not minimized
	RH.Visible = not minimized

	local w = Root.AbsoluteSize.X > 0 and Root.AbsoluteSize.X or 360
	local h = minimized and 32 or 250

	Tw(Root, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(w, h),
	})
	SyncShade()
end)

ClsB.MouseButton1Click:Connect(function()
	Tw(Scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 })
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

U.InputChanged:Connect(function(input)
	if dragging and dragInput and input == dragInput and dragStart and dragPos then
		local d = input.Position - dragStart
		Root.Position = UDim2.new(
			dragPos.X.Scale,
			dragPos.X.Offset + d.X,
			dragPos.Y.Scale,
			dragPos.Y.Offset + d.Y
		)
		SyncShade()
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

RH.InputBegan:Connect(beginResize)

U.InputChanged:Connect(function(input)
	if resizing and resizeStart and resizeSize then
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - resizeStart
			local nw = N(resizeSize.X + d.X, MIN_W, MAX_W)
			local nh = N(resizeSize.Y + d.Y, MIN_H, MAX_H)
			Root.Size = UDim2.fromOffset(nw, nh)
			SyncShade()
			if not minimized then
				Results.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 6)
			end
		end
	end
end)

Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	SyncShade()
	if not minimized then
		Results.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 6)
	end
end)

if type(Hub.getStats) == "function" then
	local st = Hub.getStats()
	if type(st) == "table" then
		Stats.Text = string.format(
			"그룹 %d · 전체 %d · 우선 %d",
			tonumber(st.groups) or 0,
			tonumber(st.unique) or 0,
			tonumber(st.special) or 0
		)
	else
		Stats.Text = "준비 완료"
	end
else
	Stats.Text = "준비 완료"
end

OpenAnim()
Refresh()
SyncShade()
