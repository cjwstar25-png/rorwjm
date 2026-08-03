--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local WORD_URL = "https://raw.githubusercontent.com/cjwstar25-png/rorwjm/refs/heads/main/word.lua"
local SCAN_INTERVAL = 0.1
local MAX_RESULTS = 10

local GUI_NAME = "WordScriptHub_Core"

local Q_MARKS = { "'", '"', "‘", "’", "“", "”" }

local state = {
	dictionaryLoaded = false,
	dictionaryLoading = false,
	dictionaryError = "",
	totalWords = 0,

	activeTab = "load",

	autoDetect = true,
	currentRawPrompt = "",
	currentPrefix = "",
	currentSource = "",
}

local dictionaryWords: {string} = {}
local indexByStart: {[string]: {string}} = {}
local seenWords: {[string]: boolean} = {}

local specialForcedByPrefix: {[string]: {string}} = {
	["기"] = { "기동돓", "기역" },
}

local rareTokens = {
	"슘", "듐", "븀", "륨", "튬", "늄", "뮴", "윰", "돓", "긿", "읅",
	"가녘", "가취끗", "가뿟", "가뿐", "가재무릇", "가짓부렁",
	"화학연료료켓", "역추진로켓", "왕듸", "듸레", "차풰",
}

local blacklistTexts = {
	["단어검색"] = true,
	["불러오기"] = true,
	["검색"] = true,
	["새로고침"] = true,
	["갱신"] = true,
	["닫기"] = true,
	["X"] = true,
	["열기"] = true,
	["접기"] = true,
	["WordScript"] = true,
	["WordScript Hub"] = true,
	["감지 대기"] = true,
	["추천 후보"] = true,
	["검색 준비"] = true,
	["불러오기 상태"] = true,
	["현재 문구"] = true,
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 9999

pcall(function()
	screenGui.Parent = CoreGui
end)

if screenGui.Parent == nil then
	screenGui.Parent = PlayerGui
end

local function trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeHangul(text: string): string
	text = tostring(text or "")
	text = text:gsub("%s+", "")
	text = text:gsub("[^가-힣]", "")
	return text
end

local function isHangulOnly(text: string): boolean
	return text ~= "" and text:match("^[가-힣]+$") ~= nil
end

local function graphemeCount(text: string): number
	local count = 0
	for _ in utf8.graphemes(text) do
		count += 1
	end
	return count
end

local function firstGrapheme(text: string): string
	for s, e in utf8.graphemes(text) do
		return string.sub(text, s, e)
	end
	return ""
end

local function lastGrapheme(text: string): string
	local result = ""
	for s, e in utf8.graphemes(text) do
		result = string.sub(text, s, e)
	end
	return result
end

local function makeTween(obj: Instance, ti: TweenInfo, props: {[string]: any})
	local tween = TweenService:Create(obj, ti, props)
	tween:Play()
	return tween
end

local function safeTextOf(instance: Instance): string
	local ok, text = pcall(function()
		return (instance :: any).Text
	end)
	if not ok then
		return ""
	end

	local result = trim(tostring(text or ""))
	if result == "" then
		return ""
	end

	if blacklistTexts[result] then
		return ""
	end

	return result
end

local function extractPromptPrefix(text: string): string
	text = trim(text)
	if text == "" then
		return ""
	end

	if not text:find("시작하는 단어", 1, true) then
		return ""
	end

	for _, q in ipairs(Q_MARKS) do
		local startPos = text:find(q, 1, true)
		if startPos then
			local endPos = text:find(q, startPos + #q, true)
			if endPos and endPos > startPos then
				local inner = text:sub(startPos + #q, endPos - 1)
				inner = normalizeHangul(inner)
				if inner ~= "" then
					return inner
				end
			end
		end
	end

	return ""
end

local function extractSearchPrefix(text: string): string
	text = trim(text)
	if text == "" then
		return ""
	end

	local prefix = extractPromptPrefix(text)
	if prefix ~= "" then
		return prefix
	end

	-- manual input fallback
	local clean = normalizeHangul(text)
	if clean ~= "" and graphemeCount(clean) <= 10 then
		return clean
	end

	return ""
end

local function rarityScore(word: string): number
	local score = 0

	for _, token in ipairs(rareTokens) do
		if word:find(token, 1, true) then
			score += 20
		end
	end

	if word:find("돓", 1, true) then
		score += 50
	end
	if word:find("긿", 1, true) then
		score += 50
	end
	if word:find("읅", 1, true) then
		score += 16
	end
	if word:find("무릇", 1, true) then
		score += 8
	end
	if word:find("부렁", 1, true) then
		score += 10
	end
	if word:find("로켓", 1, true) then
		score += 8
	end
	if word:find("화학", 1, true) then
		score += 6
	end
	if word:find("연료", 1, true) then
		score += 4
	end
	if word:find("추진", 1, true) then
		score += 6
	end
	if word:find("기동", 1, true) then
		score += 5
	end

	return score
end

local function candidateScore(word: string): number
	local len = graphemeCount(word)
	local score = len * 14
	score += rarityScore(word)

	if len >= 4 then
		score += 10
	end
	if len >= 6 then
		score += 18
	end
	if len >= 8 then
		score += 24
	end

	return score
end

local function clearChildren(frame: Instance)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end
end

local function addWord(rawWord: string)
	local word = trim(tostring(rawWord or ""))
	local key = normalizeHangul(word)
	if key == "" then
		return
	end

	if seenWords[key] then
		return
	end

	seenWords[key] = true
	table.insert(dictionaryWords, word)

	local first = firstGrapheme(key)
	if first ~= "" then
		indexByStart[first] = indexByStart[first] or {}
		table.insert(indexByStart[first], word)
	end
end

local function ingestDictionary(result: any)
	if type(result) ~= "table" then
		return
	end

	local function ingestArray(arr: any)
		if type(arr) ~= "table" then
			return
		end
		for _, v in ipairs(arr) do
			if type(v) == "string" then
				addWord(v)
			end
		end
	end

	if type(result.words) == "table" then
		ingestArray(result.words)
		return
	end

	if type(result.Words) == "table" then
		ingestArray(result.Words)
		return
	end

	if type(result.data) == "table" then
		ingestArray(result.data)
		return
	end

	ingestArray(result)
end

local function loadDictionary()
	if state.dictionaryLoading then
		return
	end

	state.dictionaryLoading = true
	state.dictionaryLoaded = false
	state.dictionaryError = ""

	table.clear(dictionaryWords)
	table.clear(indexByStart)
	table.clear(seenWords)

	local ok, result = pcall(function()
		return loadstring(game:HttpGet(WORD_URL))()
	end)

	if not ok then
		state.dictionaryError = tostring(result)
		state.dictionaryLoading = false
		return
	end

	if type(result) ~= "table" then
		state.dictionaryError = "word.lua가 table을 반환하지 않았습니다."
		state.dictionaryLoading = false
		return
	end

	ingestDictionary(result)

	state.totalWords = #dictionaryWords
	state.dictionaryLoaded = true
	state.dictionaryLoading = false
end

local function mergeForcedCandidates(prefix: string, pool: {string}): {string}
	local result: {string} = {}
	local used: {[string]: boolean} = {}

	local forced = specialForcedByPrefix[prefix]
	if forced then
		for _, word in ipairs(forced) do
			local key = normalizeHangul(word)
			if key ~= "" and not used[key] then
				used[key] = true
				table.insert(result, word)
			end
		end
	end

	for _, word in ipairs(pool) do
		local key = normalizeHangul(word)
		if key ~= "" and not used[key] then
			used[key] = true
			table.insert(result, word)
		end
	end

	return result
end

local function sortCandidates(prefix: string, candidates: {string}): {string}
	local forcedOrder: {[string]: number} = {}
	local forced = specialForcedByPrefix[prefix]
	if forced then
		for i, word in ipairs(forced) do
			forcedOrder[normalizeHangul(word)] = 1000 - i
		end
	end

	table.sort(candidates, function(a, b)
		local ka = normalizeHangul(a)
		local kb = normalizeHangul(b)

		local fa = forcedOrder[ka] or 0
		local fb = forcedOrder[kb] or 0
		if fa ~= fb then
			return fa > fb
		end

		local sa = candidateScore(ka)
		local sb = candidateScore(kb)
		if sa ~= sb then
			return sa > sb
		end

		local la = graphemeCount(ka)
		local lb = graphemeCount(kb)
		if la ~= lb then
			return la > lb
		end

		local ra = rarityScore(ka)
		local rb = rarityScore(kb)
		if ra ~= rb then
			return ra > rb
		end

		return a < b
	end)

	return candidates
end

local function getPrefixCandidates(prefix: string): {string}
	prefix = normalizeHangul(prefix)
	if prefix == "" then
		return {}
	end

	local first = firstGrapheme(prefix)
	local pool = indexByStart[first] or {}

	local filtered: {string} = {}
	for _, word in ipairs(pool) do
		local key = normalizeHangul(word)
		if key:sub(1, #prefix) == prefix then
			table.insert(filtered, word)
		end
	end

	filtered = mergeForcedCandidates(prefix, filtered)
	filtered = sortCandidates(prefix, filtered)

	local out: {string} = {}
	for i = 1, math.min(MAX_RESULTS, #filtered) do
		out[i] = filtered[i]
	end
	return out
end

local function getSearchCandidates(query: string): (string, {string})
	query = trim(query)
	local prefix = extractSearchPrefix(query)
	if prefix == "" then
		return "", {}
	end

	return prefix, getPrefixCandidates(prefix)
end

local function makeChip(parent: Instance, label: string, x: number, w: number, color: Color3)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(w, 28)
	btn.Position = UDim2.fromOffset(x, 0)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = 0.06
	btn.BorderSizePixel = 0
	btn.Text = label
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamSemibold
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = false
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.82
	stroke.Thickness = 1
	stroke.Parent = btn

	return btn
end

local function makeCard(parent: Instance, height: number, background: Color3)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.BackgroundColor3 = background
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = frame

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(85, 85, 104)
	s.Transparency = 0.36
	s.Thickness = 1
	s.Parent = frame

	return frame, s
end

local function buildUI()
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Size = UDim2.fromOffset(560, 380)
	main.Position = UDim2.new(0.5, 0, 0.42, 0)
	main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	main.BackgroundTransparency = 0.25
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 16)
	mainCorner.Parent = main

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(88, 88, 108)
	mainStroke.Transparency = 0.18
	mainStroke.Thickness = 1
	mainStroke.Parent = main

	local mainScale = Instance.new("UIScale")
	mainScale.Scale = 0.94
	mainScale.Parent = main

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 16, 1, 16)
	shadow.Position = UDim2.fromOffset(-8, -8)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 1
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = main

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 46)
	topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	topBar.BackgroundTransparency = 0.05
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 2
	topBar.Parent = main

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 16)
	topCorner.Parent = topBar

	local topCover = Instance.new("Frame")
	topCover.Size = UDim2.new(1, 0, 0, 10)
	topCover.Position = UDim2.new(0, 0, 1, -10)
	topCover.BackgroundColor3 = topBar.BackgroundColor3
	topCover.BackgroundTransparency = topBar.BackgroundTransparency
	topCover.BorderSizePixel = 0
	topCover.ZIndex = 2
	topCover.Parent = topBar

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -220, 1, 0)
	title.Font = Enum.Font.GothamSemibold
	title.Text = "WordScript Hub"
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(243, 243, 250)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 3
	title.Parent = topBar

	local statusChip = Instance.new("TextLabel")
	statusChip.BackgroundColor3 = Color3.fromRGB(56, 86, 170)
	statusChip.BackgroundTransparency = 0.08
	statusChip.BorderSizePixel = 0
	statusChip.Size = UDim2.fromOffset(118, 26)
	statusChip.Position = UDim2.new(1, -134, 0, 10)
	statusChip.Font = Enum.Font.GothamSemibold
	statusChip.Text = "CoreGUI / LIVE"
	statusChip.TextSize = 11
	statusChip.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusChip.ZIndex = 3
	statusChip.Parent = topBar

	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 8)
	statusCorner.Parent = statusChip

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(14, 56)
	tabs.Size = UDim2.new(1, -28, 0, 36)
	tabs.ZIndex = 3
	tabs.Parent = main

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 10)
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Parent = tabs

	local function tabButton(text: string)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(128, 34)
		btn.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
		btn.BackgroundTransparency = 0.06
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = text
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamSemibold
		btn.TextColor3 = Color3.fromRGB(220, 220, 230)
		btn.ZIndex = 4
		btn.Parent = tabs

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = btn

		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(255, 255, 255)
		s.Transparency = 0.88
		s.Thickness = 1
		s.Parent = btn

		return btn, s
	end

	local searchTabBtn = tabButton("단어검색")
	local loadTabBtn = tabButton("불러오기")

	local tabIndicator = Instance.new("Frame")
	tabIndicator.Name = "TabIndicator"
	tabIndicator.Size = UDim2.fromOffset(128, 3)
	tabIndicator.Position = UDim2.fromOffset(14, 89)
	tabIndicator.BackgroundColor3 = Color3.fromRGB(94, 129, 255)
	tabIndicator.BorderSizePixel = 0
	tabIndicator.ZIndex = 4
	tabIndicator.Parent = main

	local indCorner = Instance.new("UICorner")
	indCorner.CornerRadius = UDim.new(1, 0)
	indCorner.Parent = tabIndicator

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(14, 100)
	content.Size = UDim2.new(1, -28, 1, -114)
	content.ClipsDescendants = true
	content.ZIndex = 2
	content.Parent = main

	local searchPage = Instance.new("CanvasGroup")
	searchPage.Name = "SearchPage"
	searchPage.BackgroundTransparency = 1
	searchPage.Size = UDim2.new(1, 0, 1, 0)
	searchPage.Visible = false
	searchPage.GroupTransparency = 1
	searchPage.Position = UDim2.new(0, 26, 0, 0)
	searchPage.Parent = content

	local loadPage = Instance.new("CanvasGroup")
	loadPage.Name = "LoadPage"
	loadPage.BackgroundTransparency = 1
	loadPage.Size = UDim2.new(1, 0, 1, 0)
	loadPage.Visible = true
	loadPage.GroupTransparency = 0
	loadPage.Position = UDim2.new(0, 0, 0, 0)
	loadPage.Parent = content

	local function pagePanel(parent: Instance, y: number, height: number)
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(1, 0, 0, height)
		panel.Position = UDim2.fromOffset(0, y)
		panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		panel.BackgroundTransparency = 0.08
		panel.BorderSizePixel = 0
		panel.Parent = parent

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 14)
		c.Parent = panel

		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(92, 92, 110)
		s.Transparency = 0.36
		s.Thickness = 1
		s.Parent = panel

		return panel
	end

	-- Search page
	local searchControls = pagePanel(searchPage, 0, 84)
	local searchSpotlight = pagePanel(searchPage, 94, 62)
	local searchListPanel = pagePanel(searchPage, 164, 138)

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(1, -120, 0, 36)
	searchBox.Position = UDim2.fromOffset(12, 12)
	searchBox.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
	searchBox.BackgroundTransparency = 0.02
	searchBox.BorderSizePixel = 0
	searchBox.ClearTextOnFocus = false
	searchBox.Font = Enum.Font.GothamMedium
	searchBox.PlaceholderText = "'다' 로 시작하는 단어"
	searchBox.PlaceholderColor3 = Color3.fromRGB(154, 154, 164)
	searchBox.Text = ""
	searchBox.TextSize = 13
	searchBox.TextColor3 = Color3.fromRGB(250, 250, 250)
	searchBox.Parent = searchControls

	local searchBoxCorner = Instance.new("UICorner")
	searchBoxCorner.CornerRadius = UDim.new(0, 10)
	searchBoxCorner.Parent = searchBox

	local searchRunBtn = Instance.new("TextButton")
	searchRunBtn.Size = UDim2.fromOffset(92, 36)
	searchRunBtn.Position = UDim2.new(1, -104, 0, 12)
	searchRunBtn.BackgroundColor3 = Color3.fromRGB(66, 93, 182)
	searchRunBtn.BackgroundTransparency = 0.04
	searchRunBtn.BorderSizePixel = 0
	searchRunBtn.Text = "검색"
	searchRunBtn.Font = Enum.Font.GothamSemibold
	searchRunBtn.TextSize = 13
	searchRunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	searchRunBtn.Parent = searchControls

	local searchRunCorner = Instance.new("UICorner")
	searchRunCorner.CornerRadius = UDim.new(0, 10)
	searchRunCorner.Parent = searchRunBtn

	local searchStatus = Instance.new("TextLabel")
	searchStatus.BackgroundTransparency = 1
	searchStatus.Position = UDim2.fromOffset(14, 52)
	searchStatus.Size = UDim2.new(1, -28, 0, 18)
	searchStatus.Font = Enum.Font.Gotham
	searchStatus.Text = "문구를 입력하면 시작 문자열을 자동 추출합니다."
	searchStatus.TextSize = 12
	searchStatus.TextColor3 = Color3.fromRGB(180, 180, 190)
	searchStatus.TextXAlignment = Enum.TextXAlignment.Left
	searchStatus.Parent = searchControls

	local searchSpotTitle = Instance.new("TextLabel")
	searchSpotTitle.BackgroundTransparency = 1
	searchSpotTitle.Position = UDim2.fromOffset(14, 10)
	searchSpotTitle.Size = UDim2.new(1, -28, 0, 18)
	searchSpotTitle.Font = Enum.Font.GothamSemibold
	searchSpotTitle.Text = "최우선 추천"
	searchSpotTitle.TextSize = 13
	searchSpotTitle.TextColor3 = Color3.fromRGB(235, 235, 245)
	searchSpotTitle.TextXAlignment = Enum.TextXAlignment.Left
	searchSpotTitle.Parent = searchSpotlight

	local searchSpotText = Instance.new("TextLabel")
	searchSpotText.BackgroundTransparency = 1
	searchSpotText.Position = UDim2.fromOffset(14, 28)
	searchSpotText.Size = UDim2.new(1, -28, 0, 22)
	searchSpotText.Font = Enum.Font.GothamMedium
	searchSpotText.Text = "-"
	searchSpotText.TextSize = 14
	searchSpotText.TextColor3 = Color3.fromRGB(110, 190, 255)
	searchSpotText.TextXAlignment = Enum.TextXAlignment.Left
	searchSpotText.Parent = searchSpotlight

	local searchSpotInfo = Instance.new("TextLabel")
	searchSpotInfo.BackgroundTransparency = 1
	searchSpotInfo.Position = UDim2.fromOffset(14, 42)
	searchSpotInfo.Size = UDim2.new(1, -28, 0, 16)
	searchSpotInfo.Font = Enum.Font.Gotham
	searchSpotInfo.Text = "길이/희귀도 기반 정렬"
	searchSpotInfo.TextSize = 11
	searchSpotInfo.TextColor3 = Color3.fromRGB(175, 175, 185)
	searchSpotInfo.TextXAlignment = Enum.TextXAlignment.Left
	searchSpotInfo.Parent = searchSpotlight

	local searchList = Instance.new("ScrollingFrame")
	searchList.BackgroundTransparency = 1
	searchList.Size = UDim2.new(1, -20, 1, -18)
	searchList.Position = UDim2.fromOffset(10, 8)
	searchList.BorderSizePixel = 0
	searchList.ScrollBarThickness = 4
	searchList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	searchList.Parent = searchListPanel

	local searchListLayout = Instance.new("UIListLayout")
	searchListLayout.Padding = UDim.new(0, 6)
	searchListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	searchListLayout.Parent = searchList

	local searchListPad = Instance.new("UIPadding")
	searchListPad.PaddingTop = UDim.new(0, 2)
	searchListPad.Parent = searchList

	-- Load page
	local loadControls = pagePanel(loadPage, 0, 84)
	local loadSpotlight = pagePanel(loadPage, 94, 62)
	local loadListPanel = pagePanel(loadPage, 164, 138)

	local currentPromptLabel = Instance.new("TextLabel")
	currentPromptLabel.BackgroundTransparency = 1
	currentPromptLabel.Position = UDim2.fromOffset(14, 10)
	currentPromptLabel.Size = UDim2.new(1, -28, 0, 18)
	currentPromptLabel.Font = Enum.Font.GothamSemibold
	currentPromptLabel.Text = "탐지 문구"
	currentPromptLabel.TextSize = 13
	currentPromptLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
	currentPromptLabel.TextXAlignment = Enum.TextXAlignment.Left
	currentPromptLabel.Parent = loadControls

	local currentPromptValue = Instance.new("TextLabel")
	currentPromptValue.BackgroundTransparency = 1
	currentPromptValue.Position = UDim2.fromOffset(14, 28)
	currentPromptValue.Size = UDim2.new(1, -170, 0, 20)
	currentPromptValue.Font = Enum.Font.GothamMedium
	currentPromptValue.Text = "감지 대기"
	currentPromptValue.TextSize = 13
	currentPromptValue.TextColor3 = Color3.fromRGB(140, 210, 255)
	currentPromptValue.TextXAlignment = Enum.TextXAlignment.Left
	currentPromptValue.Parent = loadControls

	local sourceLabel = Instance.new("TextLabel")
	sourceLabel.BackgroundTransparency = 1
	sourceLabel.Position = UDim2.fromOffset(14, 46)
	sourceLabel.Size = UDim2.new(1, -170, 0, 16)
	sourceLabel.Font = Enum.Font.Gotham
	sourceLabel.Text = "출처: -"
	sourceLabel.TextSize = 11
	sourceLabel.TextColor3 = Color3.fromRGB(170, 170, 182)
	sourceLabel.TextXAlignment = Enum.TextXAlignment.Left
	sourceLabel.Parent = loadControls

	local reloadBtn = Instance.new("TextButton")
	reloadBtn.Size = UDim2.fromOffset(92, 36)
	reloadBtn.Position = UDim2.new(1, -104, 0, 12)
	reloadBtn.BackgroundColor3 = Color3.fromRGB(62, 132, 95)
	reloadBtn.BackgroundTransparency = 0.04
	reloadBtn.BorderSizePixel = 0
	reloadBtn.Text = "불러오기"
	reloadBtn.Font = Enum.Font.GothamSemibold
	reloadBtn.TextSize = 13
	reloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	reloadBtn.Parent = loadControls

	local reloadCorner = Instance.new("UICorner")
	reloadCorner.CornerRadius = UDim.new(0, 10)
	reloadCorner.Parent = reloadBtn

	local autoBtn = Instance.new("TextButton")
	autoBtn.Size = UDim2.fromOffset(92, 36)
	autoBtn.Position = UDim2.new(1, -200, 0, 12)
	autoBtn.BackgroundColor3 = Color3.fromRGB(66, 93, 182)
	autoBtn.BackgroundTransparency = 0.04
	autoBtn.BorderSizePixel = 0
	autoBtn.Text = "자동감지: ON"
	autoBtn.Font = Enum.Font.GothamSemibold
	autoBtn.TextSize = 12
	autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoBtn.Parent = loadControls

	local autoCorner = Instance.new("UICorner")
	autoCorner.CornerRadius = UDim.new(0, 10)
	autoCorner.Parent = autoBtn

	local loadSpotTitle = Instance.new("TextLabel")
	loadSpotTitle.BackgroundTransparency = 1
	loadSpotTitle.Position = UDim2.fromOffset(14, 10)
	loadSpotTitle.Size = UDim2.new(1, -28, 0, 18)
	loadSpotTitle.Font = Enum.Font.GothamSemibold
	loadSpotTitle.Text = "최우선 추천"
	loadSpotTitle.TextSize = 13
	loadSpotTitle.TextColor3 = Color3.fromRGB(235, 235, 245)
	loadSpotTitle.TextXAlignment = Enum.TextXAlignment.Left
	loadSpotTitle.Parent = loadSpotlight

	local loadSpotText = Instance.new("TextLabel")
	loadSpotText.BackgroundTransparency = 1
	loadSpotText.Position = UDim2.fromOffset(14, 28)
	loadSpotText.Size = UDim2.new(1, -28, 0, 22)
	loadSpotText.Font = Enum.Font.GothamMedium
	loadSpotText.Text = "-"
	loadSpotText.TextSize = 14
	loadSpotText.TextColor3 = Color3.fromRGB(110, 190, 255)
	loadSpotText.TextXAlignment = Enum.TextXAlignment.Left
	loadSpotText.Parent = loadSpotlight

	local loadSpotInfo = Instance.new("TextLabel")
	loadSpotInfo.BackgroundTransparency = 1
	loadSpotInfo.Position = UDim2.fromOffset(14, 42)
	loadSpotInfo.Size = UDim2.new(1, -28, 0, 16)
	loadSpotInfo.Font = Enum.Font.Gotham
	loadSpotInfo.Text = "탐지 후 자동 추천"
	loadSpotInfo.TextSize = 11
	loadSpotInfo.TextColor3 = Color3.fromRGB(175, 175, 185)
	loadSpotInfo.TextXAlignment = Enum.TextXAlignment.Left
	loadSpotInfo.Parent = loadSpotlight

	local loadList = Instance.new("ScrollingFrame")
	loadList.BackgroundTransparency = 1
	loadList.Size = UDim2.new(1, -20, 1, -18)
	loadList.Position = UDim2.fromOffset(10, 8)
	loadList.BorderSizePixel = 0
	loadList.ScrollBarThickness = 4
	loadList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	loadList.Parent = loadListPanel

	local loadListLayout = Instance.new("UIListLayout")
	loadListLayout.Padding = UDim.new(0, 6)
	loadListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	loadListLayout.Parent = loadList

	local loadListPad = Instance.new("UIPadding")
	loadListPad.PaddingTop = UDim.new(0, 2)
	loadListPad.Parent = loadList

	local function updateCanvas(frame: ScrollingFrame, layout: UIListLayout)
		task.defer(function()
			frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
		end)
	end

	local function cardItem(parent: Instance, text: string, highlight: boolean, rank: number?)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -2, 0, 30)
		row.BackgroundColor3 = highlight and Color3.fromRGB(56, 78, 140) or Color3.fromRGB(34, 34, 42)
		row.BackgroundTransparency = 0.05
		row.BorderSizePixel = 0
		row.Parent = parent

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = row

		local s = Instance.new("UIStroke")
		s.Color = highlight and Color3.fromRGB(125, 153, 255) or Color3.fromRGB(82, 82, 100)
		s.Transparency = 0.35
		s.Thickness = 1
		s.Parent = row

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -14, 1, 0)
		label.Position = UDim2.fromOffset(10, 0)
		label.Font = highlight and Enum.Font.GothamSemibold or Enum.Font.Gotham
		label.TextSize = 12
		label.TextColor3 = Color3.fromRGB(245, 245, 250)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = rank and string.format("%d. %s", rank, text) or text
		label.Parent = row

		return row
	end

	local function renderResults(frame: ScrollingFrame, layout: UIListLayout, sourceText: string, sourcePrefix: string, candidates: {string}, spotText: TextLabel, spotInfo: TextLabel, headlineLabel: TextLabel)
		clearChildren(frame)

		if sourcePrefix == "" then
			spotText.Text = "-"
			spotInfo.Text = "대기 중"
			headlineLabel.Text = "문구를 기다리는 중"
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.BackgroundTransparency = 1
			empty.Text = "검색할 시작 문자열이 없습니다."
			empty.TextColor3 = Color3.fromRGB(172, 172, 182)
			empty.TextSize = 12
			empty.Font = Enum.Font.Gotham
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Parent = frame
			updateCanvas(frame, layout)
			return
		end

		if #candidates == 0 then
			spotText.Text = "-"
			spotInfo.Text = "후보 없음"
			headlineLabel.Text = string.format("'%s' 로 시작하는 단어", sourcePrefix)
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.BackgroundTransparency = 1
			empty.Text = "후보를 찾지 못했습니다."
			empty.TextColor3 = Color3.fromRGB(172, 172, 182)
			empty.TextSize = 12
			empty.Font = Enum.Font.Gotham
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Parent = frame
			updateCanvas(frame, layout)
			return
		end

		local best = candidates[1]
		local bestKey = normalizeHangul(best)
		spotText.Text = best
		spotInfo.Text = string.format("길이 %d / 점수 %d", graphemeCount(bestKey), candidateScore(bestKey))
		headlineLabel.Text = string.format("'%s' 로 시작하는 단어", sourcePrefix)

		for i, word in ipairs(candidates) do
			local key = normalizeHangul(word)
			local score = candidateScore(key)
			cardItem(frame, string.format("%s  ·  점수 %d", word, score), i == 1, i)
		end

		updateCanvas(frame, layout)
	end

	local searchHeadline = Instance.new("TextLabel")
	searchHeadline.BackgroundTransparency = 1
	searchHeadline.Position = UDim2.fromOffset(14, 8)
	searchHeadline.Size = UDim2.new(1, -28, 0, 18)
	searchHeadline.Font = Enum.Font.GothamSemibold
	searchHeadline.Text = "'다' 로 시작하는 단어"
	searchHeadline.TextSize = 13
	searchHeadline.TextColor3 = Color3.fromRGB(235, 235, 245)
	searchHeadline.TextXAlignment = Enum.TextXAlignment.Left
	searchHeadline.Parent = searchPage

	local loadHeadline = Instance.new("TextLabel")
	loadHeadline.BackgroundTransparency = 1
	loadHeadline.Position = UDim2.fromOffset(14, 8)
	loadHeadline.Size = UDim2.new(1, -28, 0, 18)
	loadHeadline.Font = Enum.Font.GothamSemibold
	loadHeadline.Text = "'다' 로 시작하는 단어"
	loadHeadline.TextSize = 13
	loadHeadline.TextColor3 = Color3.fromRGB(235, 235, 245)
	loadHeadline.TextXAlignment = Enum.TextXAlignment.Left
	loadHeadline.Parent = loadPage

	local function updateSearch()
		local prefix, candidates = getSearchCandidates(searchBox.Text)
		searchHeadline.Text = prefix ~= "" and string.format("'%s' 로 시작하는 단어", prefix) or "검색 결과"
		renderResults(searchList, searchListLayout, searchBox.Text, prefix, candidates, searchSpotText, searchSpotInfo, searchHeadline)
	end

	local function updateLoad()
		local prefix = state.currentPrefix
		local prompt = state.currentRawPrompt

		currentPromptValue.Text = prompt ~= "" and prompt or "감지 대기"
		sourceLabel.Text = state.currentSource ~= "" and ("출처: " .. state.currentSource) or "출처: -"

		if not state.dictionaryLoaded and state.dictionaryError ~= "" then
			loadHeadline.Text = "불러오기 실패"
			loadSpotText.Text = "word.lua 오류"
			loadSpotInfo.Text = "로드 실패"

			clearChildren(loadList)
			local err = Instance.new("TextLabel")
			err.Size = UDim2.new(1, 0, 0, 24)
			err.BackgroundTransparency = 1
			err.Text = "word.lua 로드 실패: " .. state.dictionaryError
			err.TextColor3 = Color3.fromRGB(255, 150, 150)
			err.TextSize = 12
			err.Font = Enum.Font.Gotham
			err.TextXAlignment = Enum.TextXAlignment.Left
			err.Parent = loadList
			updateCanvas(loadList, loadListLayout)
			return
		end
		loadHeadline.Text = prefix ~= "" and string.format("'%s' 로 시작하는 단어", prefix) or "탐지 대기"

		local candidates = getPrefixCandidates(prefix)
		renderResults(loadList, loadListLayout, prompt, prefix, candidates, loadSpotText, loadSpotInfo, loadHeadline)
	end

	local tabsState = {
		search = {
			btn = searchTabBtn,
			page = searchPage,
			x = 14,
		},
		load = {
			btn = loadTabBtn,
			page = loadPage,
			x = 152,
		},
	}

	local function setActiveTab(tabName: "search" | "load")
		state.activeTab = tabName

		local target = tabsState[tabName]
		local other = tabsState[tabName == "search" and "load" or "search"]

		for key, item in pairs(tabsState) do
			local active = key == tabName
			item.btn.BackgroundColor3 = active and Color3.fromRGB(66, 93, 182) or Color3.fromRGB(34, 34, 42)
			item.btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 220, 230)
		end

		makeTween(tabIndicator, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(target.x, 89),
		})

		target.page.Visible = true
		makeTween(target.page, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
			Position = UDim2.new(0, 0, 0, 0),
		})

		makeTween(other.page, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			GroupTransparency = 1,
			Position = UDim2.new(0, -24, 0, 0),
		})
		task.delay(0.22, function()
			if state.activeTab ~= (tabName == "search" and "load" or "search") then
				other.page.Visible = false
			end
		end)

		if tabName == "search" then
			updateSearch()
		else
			updateLoad()
		end
	end

	searchTabBtn.MouseButton1Click:Connect(function()
		setActiveTab("search")
	end)

	loadTabBtn.MouseButton1Click:Connect(function()
		setActiveTab("load")
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if state.activeTab == "search" then
			updateSearch()
		end
	end)

	searchRunBtn.MouseButton1Click:Connect(function()
		setActiveTab("search")
		updateSearch()
	end)

	reloadBtn.MouseButton1Click:Connect(function()
		loadDictionary()
		updateLoad()
	end)

	autoBtn.MouseButton1Click:Connect(function()
		state.autoDetect = not state.autoDetect
		autoBtn.Text = state.autoDetect and "자동감지: ON" or "자동감지: OFF"
		autoBtn.BackgroundColor3 = state.autoDetect and Color3.fromRGB(66, 93, 182) or Color3.fromRGB(110, 84, 84)
	end)

	-- Dragging with top bar only
	do
		local dragging = false
		local dragStart: Vector2? = nil
		local startPos: UDim2? = nil

		topBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
			end
		end)

		topBar.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			if not dragStart or not startPos then
				return
			end

			local delta = input.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end)
	end

	local function animateIntro()
		mainScale.Scale = 0.94
		main.Position = UDim2.new(0.5, 0, 0.44, 0)
		makeTween(mainScale, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Scale = 1,
		})
		makeTween(main, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.42, 0),
		})
	end

	local function detectPrompt()
		if not state.autoDetect then
			return
		end

		local roots = { PlayerGui, CoreGui }
		local bestRaw = ""
		local bestPrefix = ""
		local bestSource = ""

		for _, root in ipairs(roots) do
			for _, obj in ipairs(root:GetDescendants()) do
				if obj:IsDescendantOf(screenGui) then
					continue
				end

				if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
					local text = safeTextOf(obj)
					if text ~= "" and text:find("시작하는 단어", 1, true) then
						local prefix = extractPromptPrefix(text)
						if prefix ~= "" then
							bestRaw = text
							bestPrefix = prefix
							bestSource = obj:GetFullName()
						end
					end
				end
			end
		end

		if bestPrefix ~= "" and (bestPrefix ~= state.currentPrefix or bestRaw ~= state.currentRawPrompt or bestSource ~= state.currentSource) then
			state.currentRawPrompt = bestRaw
			state.currentPrefix = bestPrefix
			state.currentSource = bestSource

			if state.activeTab == "load" then
				updateLoad()
			end
		end
	end

	-- Startup
	loadDictionary()
	animateIntro()
	setActiveTab("load")

	task.spawn(function()
		while screenGui.Parent do
			detectPrompt()
			task.wait(SCAN_INTERVAL)
		end
	end)

	task.defer(function()
		if not state.dictionaryLoaded and state.dictionaryError ~= "" then
			currentPromptValue.Text = "word.lua 로드 실패"
			sourceLabel.Text = "출처: -"
			loadSpotText.Text = "오류"
			loadSpotInfo.Text = state.dictionaryError
		end
	end)

	-- Initial paint for both pages
	task.delay(0.1, function()
		updateLoad()
		updateSearch()
	end)
end

buildUI()
