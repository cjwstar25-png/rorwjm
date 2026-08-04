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

type TabName = "search" | "load"

type State = {
	dictionaryLoaded: boolean,
	dictionaryLoading: boolean,
	dictionaryError: string,
	totalWords: number,
	activeTab: TabName,
	autoDetect: boolean,
	currentRawPrompt: string,
	currentPrefix: string,
	currentSource: string,
	version: string,
	title: string,
}

local state: State = {
	dictionaryLoaded = false,
	dictionaryLoading = false,
	dictionaryError = "",
	totalWords = 0,
	activeTab = "load",
	autoDetect = true,
	currentRawPrompt = "",
	currentPrefix = "",
	currentSource = "",
	version = "",
	title = "",
}

local specialForcedByPrefix: {[string]: {string}} = {
	["기"] = { "기동돓", "기역" },
}

local rareTokens = {
	"슘", "듐", "븀", "륨", "튬", "늄", "뮴", "윰", "돓", "긿", "읅",
	"가녘", "가취끗", "가뿟", "가뿐", "가재무릇", "가짓부렁",
	"화학연료로켓", "역추진로켓", "왕듸", "듸레", "차풰",
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
	["탐지 문구"] = true,
	["최우선 추천"] = true,
	["길이/희귀도 기반 정렬"] = true,
	["탐지 후 자동 추천"] = true,
	["대기 중"] = true,
	["후보 없음"] = true,
	["후보를 찾지 못했습니다."] = true,
	["문구를 기다리는 중"] = true,
	["검색 결과"] = true,
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

	-- manual fallback: allow a raw prefix like "기"
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

local dictionary: any = nil
local dictionaryWords: {string} = {}
local indexByFirst: {[string]: {string}} = {}
local indexByLast: {[string]: {string}} = {}
local priorityMap: {[string]: boolean} = {}
local seenWords: {[string]: boolean} = {}

local function addWord(rawWord: string, forcePriority: boolean?)
	local word = trim(tostring(rawWord or ""))
	local key = normalizeHangul(word)
	if key == "" then
		return
	end
	if seenWords[key] then
		if forcePriority then
			priorityMap[key] = true
		end
		return
	end

	seenWords[key] = true
	table.insert(dictionaryWords, word)

	local first = firstGrapheme(key)
	local last = lastGrapheme(key)

	if first ~= "" then
		indexByFirst[first] = indexByFirst[first] or {}
		table.insert(indexByFirst[first], word)
	end

	if last ~= "" then
		indexByLast[last] = indexByLast[last] or {}
		table.insert(indexByLast[last], word)
	end

	if forcePriority then
		priorityMap[key] = true
	end
end

local function ingestArray(arr: any, forcePriority: boolean?)
	if type(arr) ~= "table" then
		return
	end
	for _, v in ipairs(arr) do
		if type(v) == "string" then
			addWord(v, forcePriority)
		end
	end
end

local function ingestDictionary(result: any)
	if type(result) ~= "table" then
		return
	end

	-- New WordHub format
	if type(result.index) == "table" then
		if type(result.index.all) == "table" then
			ingestArray(result.index.all, false)
		end
		if type(result.special) == "table" then
			ingestArray(result.special, true)
		end
		return
	end

	-- Fallback formats
	if type(result.words) == "table" then
		ingestArray(result.words, false)
		return
	end
	if type(result.Words) == "table" then
		ingestArray(result.Words, false)
		return
	end
	if type(result.data) == "table" then
		ingestArray(result.data, false)
		return
	end

	ingestArray(result, false)
end

local function loadDictionary()
	if state.dictionaryLoading then
		return
	end

	state.dictionaryLoading = true
	state.dictionaryLoaded = false
	state.dictionaryError = ""
	state.totalWords = 0

	table.clear(dictionaryWords)
	table.clear(indexByFirst)
	table.clear(indexByLast)
	table.clear(priorityMap)
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

	dictionary = result
	if type(result.version) == "string" then
		state.version = result.version
	end
	if type(result.title) == "string" then
		state.title = result.title
	end

	ingestDictionary(result)

	state.totalWords = #dictionaryWords
	state.dictionaryLoaded = state.totalWords > 0
	if not state.dictionaryLoaded then
		state.dictionaryError = "word.lua에서 단어를 읽지 못했습니다."
	end

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

		local pa = priorityMap[ka] and 1 or 0
		local pb = priorityMap[kb] and 1 or 0
		if pa ~= pb then
			return pa > pb
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
	local pool = indexByFirst[first] or {}
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

local function makeRounded(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function styleStroke(parent: Instance, color: Color3, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = 1
	stroke.Parent = parent
	return stroke
end

local function createCard(parent: Instance, height: number, background: Color3)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.BackgroundColor3 = background
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = parent
	makeRounded(frame, 12)
	styleStroke(frame, Color3.fromRGB(90, 90, 110), 0.42)
	return frame
end

local function createHeaderLabel(parent: Instance, text: string, y: number)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, 18)
	label.Font = Enum.Font.GothamSemibold
	label.Text = text
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(236, 236, 246)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createBodyLabel(parent: Instance, text: string, y: number, height: number, color: Color3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(14, y)
	label.Size = UDim2.new(1, -28, 0, height)
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextSize = 12
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = parent
	return label
end

local function makeResultRow(parent: Instance, text: string, rank: number, highlight: boolean)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -2, 0, 32)
	row.BackgroundColor3 = highlight and Color3.fromRGB(60, 82, 146) or Color3.fromRGB(34, 34, 42)
	row.BackgroundTransparency = 0.05
	row.BorderSizePixel = 0
	row.Parent = parent
	makeRounded(row, 10)
	styleStroke(row, highlight and Color3.fromRGB(125, 153, 255) or Color3.fromRGB(82, 82, 100), 0.38)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(10, 0)
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Font = highlight and Enum.Font.GothamSemibold or Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(245, 245, 250)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = string.format("%d. %s", rank, text)
	label.Parent = row

	return row
end

local function buildUI()
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.new(0.5, 0, 0.42, 0)
	main.Size = UDim2.fromOffset(610, 410)
	main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	main.BackgroundTransparency = 0.25
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.Parent = screenGui
	makeRounded(main, 16)
	styleStroke(main, Color3.fromRGB(88, 88, 108), 0.18)

	local mainScale = Instance.new("UIScale")
	mainScale.Scale = 0.96
	mainScale.Parent = main

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 48)
	topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	topBar.BackgroundTransparency = 0.05
	topBar.BorderSizePixel = 0
	topBar.Parent = main
	makeRounded(topBar, 16)

	local topCover = Instance.new("Frame")
	topCover.Size = UDim2.new(1, 0, 0, 10)
	topCover.Position = UDim2.new(0, 0, 1, -10)
	topCover.BackgroundColor3 = topBar.BackgroundColor3
	topCover.BackgroundTransparency = topBar.BackgroundTransparency
	topCover.BorderSizePixel = 0
	topCover.Parent = topBar

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -210, 1, 0)
	title.Font = Enum.Font.GothamSemibold
	title.Text = "WordScript Hub"
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(243, 243, 250)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = topBar

	local meta = Instance.new("TextLabel")
	meta.BackgroundColor3 = Color3.fromRGB(56, 86, 170)
	meta.BackgroundTransparency = 0.08
	meta.BorderSizePixel = 0
	meta.Position = UDim2.new(1, -134, 0, 11)
	meta.Size = UDim2.fromOffset(118, 26)
	meta.Font = Enum.Font.GothamSemibold
	meta.Text = "CoreGUI / LIVE"
	meta.TextSize = 11
	meta.TextColor3 = Color3.fromRGB(255, 255, 255)
	meta.Parent = topBar
	makeRounded(meta, 8)

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(14, 58)
	tabs.Size = UDim2.new(1, -28, 0, 38)
	tabs.Parent = main

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 10)
	tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabsLayout.Parent = tabs

	local function createTabButton(text: string)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(136, 34)
		btn.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
		btn.BackgroundTransparency = 0.06
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = text
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamSemibold
		btn.TextColor3 = Color3.fromRGB(220, 220, 230)
		btn.Parent = tabs
		makeRounded(btn, 10)
		styleStroke(btn, Color3.fromRGB(255, 255, 255), 0.88)
		return btn
	end

	local searchTabBtn = createTabButton("단어검색")
	local loadTabBtn = createTabButton("불러오기")

	local tabIndicator = Instance.new("Frame")
	tabIndicator.Size = UDim2.fromOffset(136, 3)
	tabIndicator.Position = UDim2.fromOffset(14, 92)
	tabIndicator.BackgroundColor3 = Color3.fromRGB(94, 129, 255)
	tabIndicator.BorderSizePixel = 0
	tabIndicator.Parent = main
	makeRounded(tabIndicator, 2)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(14, 102)
	content.Size = UDim2.new(1, -28, 1, -116)
	content.Parent = main

	local searchPage = Instance.new("CanvasGroup")
	searchPage.Name = "SearchPage"
	searchPage.BackgroundTransparency = 1
	searchPage.Size = UDim2.new(1, 0, 1, 0)
	searchPage.Position = UDim2.new(0, 0, 0, 0)
	searchPage.GroupTransparency = 1
	searchPage.Visible = false
	searchPage.Parent = content

	local loadPage = Instance.new("CanvasGroup")
	loadPage.Name = "LoadPage"
	loadPage.BackgroundTransparency = 1
	loadPage.Size = UDim2.new(1, 0, 1, 0)
	loadPage.Position = UDim2.new(0, 0, 0, 0)
	loadPage.GroupTransparency = 0
	loadPage.Visible = true
	loadPage.Parent = content

	local function createPagePanel(parent: Instance, y: number, h: number)
		return createCard((function()
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.Size = UDim2.new(1, 0, 0, h)
			f.Position = UDim2.fromOffset(0, y)
			f.Parent = parent
			return f
		end)(), h, Color3.fromRGB(28, 28, 34))
	end

	local searchControls = createPagePanel(searchPage, 0, 84)
	local searchSpotlight = createPagePanel(searchPage, 90, 70)
	local searchListPanel = createPagePanel(searchPage, 166, 122)

	local loadControls = createPagePanel(loadPage, 0, 84)
	local loadSpotlight = createPagePanel(loadPage, 90, 70)
	local loadListPanel = createPagePanel(loadPage, 166, 122)

	-- Search controls
	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -126, 0, 36)
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
	makeRounded(searchBox, 10)
	styleStroke(searchBox, Color3.fromRGB(255, 255, 255), 0.9)

	local searchRunBtn = Instance.new("TextButton")
	searchRunBtn.Size = UDim2.fromOffset(98, 36)
	searchRunBtn.Position = UDim2.new(1, -110, 0, 12)
	searchRunBtn.BackgroundColor3 = Color3.fromRGB(66, 93, 182)
	searchRunBtn.BackgroundTransparency = 0.04
	searchRunBtn.BorderSizePixel = 0
	searchRunBtn.Text = "검색"
	searchRunBtn.Font = Enum.Font.GothamSemibold
	searchRunBtn.TextSize = 13
	searchRunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	searchRunBtn.Parent = searchControls
	makeRounded(searchRunBtn, 10)

	local searchStatus = createBodyLabel(searchControls, "문구를 입력하면 시작 문자열을 자동 추출합니다.", 52, 18, Color3.fromRGB(180, 180, 190))

	local searchSpotTitle = createHeaderLabel(searchSpotlight, "최우선 추천", 10)
	local searchSpotText = createBodyLabel(searchSpotlight, "-", 28, 22, Color3.fromRGB(110, 190, 255))
	local searchSpotInfo = createBodyLabel(searchSpotlight, "길이/희귀도 기반 정렬", 42, 16, Color3.fromRGB(175, 175, 185))

	local searchList = Instance.new("ScrollingFrame")
	searchList.BackgroundTransparency = 1
	searchList.BorderSizePixel = 0
	searchList.Position = UDim2.fromOffset(10, 8)
	searchList.Size = UDim2.new(1, -20, 1, -16)
	searchList.ScrollBarThickness = 6
	searchList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	searchList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	searchList.CanvasSize = UDim2.new(0, 0, 0, 0)
	searchList.Parent = searchListPanel

	local searchListLayout = Instance.new("UIListLayout")
	searchListLayout.Padding = UDim.new(0, 6)
	searchListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	searchListLayout.Parent = searchList

	local searchListPad = Instance.new("UIPadding")
	searchListPad.PaddingTop = UDim.new(0, 2)
	searchListPad.PaddingBottom = UDim.new(0, 4)
	searchListPad.Parent = searchList

	local currentPromptValue = createBodyLabel(loadControls, "감지 대기", 28, 20, Color3.fromRGB(140, 210, 255))
	local sourceLabel = createBodyLabel(loadControls, "출처: -", 46, 16, Color3.fromRGB(170, 170, 182))

	local reloadBtn = Instance.new("TextButton")
	reloadBtn.Size = UDim2.fromOffset(98, 36)
	reloadBtn.Position = UDim2.new(1, -110, 0, 12)
	reloadBtn.BackgroundColor3 = Color3.fromRGB(62, 132, 95)
	reloadBtn.BackgroundTransparency = 0.04
	reloadBtn.BorderSizePixel = 0
	reloadBtn.Text = "불러오기"
	reloadBtn.Font = Enum.Font.GothamSemibold
	reloadBtn.TextSize = 13
	reloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	reloadBtn.Parent = loadControls
	makeRounded(reloadBtn, 10)

	local autoBtn = Instance.new("TextButton")
	autoBtn.Size = UDim2.fromOffset(98, 36)
	autoBtn.Position = UDim2.new(1, -214, 0, 12)
	autoBtn.BackgroundColor3 = Color3.fromRGB(66, 93, 182)
	autoBtn.BackgroundTransparency = 0.04
	autoBtn.BorderSizePixel = 0
	autoBtn.Text = "자동감지: ON"
	autoBtn.Font = Enum.Font.GothamSemibold
	autoBtn.TextSize = 12
	autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoBtn.Parent = loadControls
	makeRounded(autoBtn, 10)

	local loadSpotTitle = createHeaderLabel(loadSpotlight, "최우선 추천", 10)
	local loadSpotText = createBodyLabel(loadSpotlight, "-", 28, 22, Color3.fromRGB(110, 190, 255))
	local loadSpotInfo = createBodyLabel(loadSpotlight, "탐지 후 자동 추천", 42, 16, Color3.fromRGB(175, 175, 185))

	local loadList = Instance.new("ScrollingFrame")
	loadList.BackgroundTransparency = 1
	loadList.BorderSizePixel = 0
	loadList.Position = UDim2.fromOffset(10, 8)
	loadList.Size = UDim2.new(1, -20, 1, -16)
	loadList.ScrollBarThickness = 6
	loadList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	loadList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	loadList.CanvasSize = UDim2.new(0, 0, 0, 0)
	loadList.Parent = loadListPanel

	local loadListLayout = Instance.new("UIListLayout")
	loadListLayout.Padding = UDim.new(0, 6)
	loadListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	loadListLayout.Parent = loadList

	local loadListPad = Instance.new("UIPadding")
	loadListPad.PaddingTop = UDim.new(0, 2)
	loadListPad.PaddingBottom = UDim.new(0, 4)
	loadListPad.Parent = loadList

	local function renderResults(
		frame: ScrollingFrame,
		sourcePrefix: string,
		candidates: {string},
		spotText: TextLabel,
		spotInfo: TextLabel,
		headlineLabel: TextLabel,
		emptyText: string
	)
		clearChildren(frame)

		if sourcePrefix == "" then
			spotText.Text = "-"
			spotInfo.Text = "대기 중"
			headlineLabel.Text = "문구를 기다리는 중"

			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.BackgroundTransparency = 1
			empty.Text = emptyText
			empty.TextColor3 = Color3.fromRGB(172, 172, 182)
			empty.TextSize = 12
			empty.Font = Enum.Font.Gotham
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Parent = frame
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
			makeResultRow(frame, string.format("%s  ·  점수 %d", word, score), i, i == 1)
		end
	end

	local searchHeadline = createHeaderLabel(searchPage, "'다' 로 시작하는 단어", 8)
	local loadHeadline = createHeaderLabel(loadPage, "'다' 로 시작하는 단어", 8)

	local function updateSearch()
		local prefix, candidates = getSearchCandidates(searchBox.Text)
		searchHeadline.Text = prefix ~= "" and string.format("'%s' 로 시작하는 단어", prefix) or "검색 결과"
		renderResults(searchList, prefix, candidates, searchSpotText, searchSpotInfo, searchHeadline, "검색할 시작 문자열이 없습니다.")
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
			return
		end

		loadHeadline.Text = prefix ~= "" and string.format("'%s' 로 시작하는 단어", prefix) or "탐지 대기"
		local candidates = getPrefixCandidates(prefix)
		renderResults(loadList, prefix, candidates, loadSpotText, loadSpotInfo, loadHeadline, "탐지 문구를 기다리는 중")
	end

	local tabsState = {
		search = { btn = searchTabBtn, page = searchPage, x = 14 },
		load = { btn = loadTabBtn, page = loadPage, x = 160 },
	}

	local function setActiveTab(tabName: TabName)
		state.activeTab = tabName

		for key, item in pairs(tabsState) do
			local active = key == tabName
			item.btn.BackgroundColor3 = active and Color3.fromRGB(66, 93, 182) or Color3.fromRGB(34, 34, 42)
			item.btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 220, 230)
		end

		makeTween(tabIndicator, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(tabsState[tabName].x, 92),
		})

		for key, item in pairs(tabsState) do
			local active = key == tabName
			item.page.Visible = true
			makeTween(item.page, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				GroupTransparency = active and 0 or 1,
			})
			local targetX = active and 0 or -26
			makeTween(item.page, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, targetX, 0, 0),
			})
		end

		task.delay(0.24, function()
			for key, item in pairs(tabsState) do
				if key ~= tabName then
					item.page.Visible = false
				end
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

	-- Dragging
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

	-- Resize handle
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2.fromOffset(18, 18)
	resizeHandle.AnchorPoint = Vector2.new(1, 1)
	resizeHandle.Position = UDim2.new(1, -6, 1, -6)
	resizeHandle.BackgroundColor3 = Color3.fromRGB(84, 84, 102)
	resizeHandle.BackgroundTransparency = 0.05
	resizeHandle.BorderSizePixel = 0
	resizeHandle.Text = "◢"
	resizeHandle.TextSize = 10
	resizeHandle.Font = Enum.Font.GothamBold
	resizeHandle.TextColor3 = Color3.fromRGB(245, 245, 250)
	resizeHandle.Parent = main
	makeRounded(resizeHandle, 6)

	do
		local resizing = false
		local resizeStart: Vector2? = nil
		local startSize: UDim2? = nil

		resizeHandle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				resizeStart = input.Position
				startSize = main.Size
			end
		end)

		resizeHandle.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not resizing then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			if not resizeStart or not startSize then
				return
			end

			local delta = input.Position - resizeStart
			local newW = math.clamp(startSize.X.Offset + delta.X, 500, 860)
			local newH = math.clamp(startSize.Y.Offset + delta.Y, 320, 620)
			main.Size = UDim2.fromOffset(newW, newH)
		end)
	end

	local function animateIntro()
		mainScale.Scale = 0.96
		main.Position = UDim2.new(0.5, 0, 0.44, 0)
		makeTween(mainScale, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 })
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

	-- Initial state
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

	task.delay(0.1, function()
		updateLoad()
		updateSearch()
	end)
end

loadDictionary()
buildUI()
