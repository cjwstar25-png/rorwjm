--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local WORD_URL = "https://raw.githubusercontent.com/cjwstar25-png/rorwjm/refs/heads/main/word.lua"
local GUI_NAME = "WordScriptHub_Core"
local SCAN_INTERVAL = 0.1
local MAX_RESULTS = 12
local Q_MARKS = { "'", '"', "‘", "’", "“", "”" }

type TabName = "search" | "load" | "favorites" | "history" | "settings"

local state = {
	dictionaryLoaded = false,
	dictionaryLoading = false,
	dictionaryError = "",
	totalWords = 0,
	version = "",
	title = "WordScript",
	activeTab = "load" :: TabName,
	autoDetect = true,
	autoCopy = true,
	safeAutoPlay = false,
	sortMode = "priority",
	onlyPriority = false,
	minLength = 1,
	currentRawPrompt = "",
	currentPrefix = "",
	currentSource = "",
	currentBest = "",
	lastAutoCopied = "",
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
	["단어검색"] = true, ["불러오기"] = true, ["즐겨찾기"] = true, ["기록"] = true, ["설정"] = true,
	["검색"] = true, ["새로고침"] = true, ["갱신"] = true, ["닫기"] = true, ["X"] = true,
	["열기"] = true, ["접기"] = true, ["WordScript"] = true, ["WordScript Hub"] = true,
	["감지 대기"] = true, ["추천 후보"] = true, ["검색 준비"] = true, ["불러오기 상태"] = true,
	["현재 문구"] = true, ["탐지 문구"] = true, ["최우선 추천"] = true,
	["대기 중"] = true, ["후보 없음"] = true, ["후보를 찾지 못했습니다."] = true,
	["문구를 기다리는 중"] = true, ["검색 결과"] = true,
}

local function trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeHangul(text: string): string
	text = tostring(text or "")
	text = text:gsub("%s+", "")
	text = text:gsub("[^가-힣]", "")
	return text
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
	if not ok then return "" end
	local result = trim(tostring(text or ""))
	if result == "" then return "" end
	if blacklistTexts[result] then return "" end
	return result
end

local function extractPromptPrefix(text: string): string
	text = trim(text)
	if text == "" or not text:find("시작하는 단어", 1, true) then
		return ""
	end
	for _, q in ipairs(Q_MARKS) do
		local startPos = text:find(q, 1, true)
		if startPos then
			local endPos = text:find(q, startPos + #q, true)
			if endPos and endPos > startPos then
				local inner = normalizeHangul(text:sub(startPos + #q, endPos - 1))
				if inner ~= "" then return inner end
			end
		end
	end
	return ""
end

local function extractSearchPrefix(text: string): string
	text = trim(text)
	if text == "" then return "" end
	local prefix = extractPromptPrefix(text)
	if prefix ~= "" then return prefix end
	local clean = normalizeHangul(text)
	if clean ~= "" and graphemeCount(clean) <= 10 then
		return clean
	end
	return ""
end

local function rarityScore(word: string): number
	local score = 0
	for _, token in ipairs(rareTokens) do
		if word:find(token, 1, true) then score += 20 end
	end
	if word:find("돓", 1, true) then score += 50 end
	if word:find("긿", 1, true) then score += 50 end
	if word:find("읅", 1, true) then score += 16 end
	if word:find("무릇", 1, true) then score += 8 end
	if word:find("부렁", 1, true) then score += 10 end
	if word:find("로켓", 1, true) then score += 8 end
	if word:find("화학", 1, true) then score += 6 end
	if word:find("연료", 1, true) then score += 4 end
	if word:find("추진", 1, true) then score += 6 end
	if word:find("기동", 1, true) then score += 5 end
	return score
end

local function candidateScore(word: string): number
	local len = graphemeCount(word)
	local score = len * 14 + rarityScore(word)
	if len >= 4 then score += 10 end
	if len >= 6 then score += 18 end
	if len >= 8 then score += 24 end
	return score
end

local function clearChildren(frame: Instance)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 9999
pcall(function() screenGui.Parent = CoreGui end)
if screenGui.Parent == nil then screenGui.Parent = PlayerGui end

-- Dictionary
local dictionary: any = nil
local dictAll: {string} = {}
local dictByFirst: {[string]: {string}} = {}
local dictPriority: {[string]: boolean} = {}
local seenWords: {[string]: boolean} = {}

local function addWord(rawWord: string, forcePriority: boolean?)
	local word = trim(rawWord)
	local key = normalizeHangul(word)
	if key == "" then return end
	if seenWords[key] then
		if forcePriority then dictPriority[key] = true end
		return
	end
	seenWords[key] = true
	table.insert(dictAll, word)
	local first = firstGrapheme(key)
	if first ~= "" then
		dictByFirst[first] = dictByFirst[first] or {}
		table.insert(dictByFirst[first], word)
	end
	if forcePriority then dictPriority[key] = true end
end

local function ingestArray(arr: any, forcePriority: boolean?)
	if type(arr) ~= "table" then return end
	for _, v in ipairs(arr) do
		if type(v) == "string" then addWord(v, forcePriority) end
	end
end

local function ingestDictionary(result: any)
	if type(result) ~= "table" then return end
	if type(result.index) == "table" then
		if type(result.index.all) == "table" then ingestArray(result.index.all, false) end
		if type(result.index.priority) == "table" then
			for word, on in pairs(result.index.priority) do
				if type(word) == "string" and on == true then
					dictPriority[normalizeHangul(word)] = true
				end
			end
		end
		if type(result.special) == "table" then ingestArray(result.special, true) end
		return
	end
	if type(result.words) == "table" then ingestArray(result.words, false); return end
	if type(result.Words) == "table" then ingestArray(result.Words, false); return end
	if type(result.data) == "table" then ingestArray(result.data, false); return end
	ingestArray(result, false)
end

local function loadDictionary()
	if state.dictionaryLoading then return end
	state.dictionaryLoading = true
	state.dictionaryLoaded = false
	state.dictionaryError = ""
	state.totalWords = 0
	table.clear(dictAll)
	table.clear(dictByFirst)
	table.clear(dictPriority)
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
	if type(result.version) == "string" then state.version = result.version end
	if type(result.title) == "string" then state.title = result.title end

	ingestDictionary(result)

	state.totalWords = #dictAll
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
		if fa ~= fb then return fa > fb end

		local pa = dictPriority[ka] and 1 or 0
		local pb = dictPriority[kb] and 1 or 0
		if pa ~= pb then return pa > pb end

		if state.sortMode == "length" then
			local la, lb = graphemeCount(ka), graphemeCount(kb)
			if la ~= lb then return la > lb end
		elseif state.sortMode == "rarity" then
			local ra, rb = rarityScore(ka), rarityScore(kb)
			if ra ~= rb then return ra > rb end
		elseif state.sortMode == "alpha" then
			return a < b
		end

		local sa, sb = candidateScore(ka), candidateScore(kb)
		if sa ~= sb then return sa > sb end
		local la, lb = graphemeCount(ka), graphemeCount(kb)
		if la ~= lb then return la > lb end
		local ra, rb = rarityScore(ka), rarityScore(kb)
		if ra ~= rb then return ra > rb end
		return a < b
	end)

	return candidates
end

local function getPrefixCandidates(prefix: string): {string}
	prefix = normalizeHangul(prefix)
	if prefix == "" then return {} end
	local first = firstGrapheme(prefix)
	local pool = dictByFirst[first] or {}
	local filtered: {string} = {}
	for _, word in ipairs(pool) do
		local key = normalizeHangul(word)
		if key:sub(1, #prefix) == prefix and graphemeCount(key) >= state.minLength then
			if not state.onlyPriority or dictPriority[key] then
				table.insert(filtered, word)
			end
		end
	end
	filtered = mergeForcedCandidates(prefix, filtered)
	filtered = sortCandidates(prefix, filtered)
	local out: {string} = {}
	for i = 1, math.min(MAX_RESULTS, #filtered) do out[i] = filtered[i] end
	return out
end

local function getSearchCandidates(query: string): (string, {string})
	local prefix = extractSearchPrefix(query)
	if prefix == "" then return "", {} end
	return prefix, getPrefixCandidates(prefix)
end

-- local lists
local favorites: {string} = {}
local history: {string} = {}

local function dedupePush(list: {string}, word: string, maxCount: number, front: boolean)
	local key = normalizeHangul(word)
	if key == "" then return end
	for i = #list, 1, -1 do
		if normalizeHangul(list[i]) == key then table.remove(list, i) end
	end
	if front then table.insert(list, 1, word) else table.insert(list, word) end
	while #list > maxCount do
		if front then table.remove(list) else table.remove(list, 1) end
	end
end

local function tryClipboard(text: string)
	local setter = _G.setclipboard
	if type(setter) == "function" then
		pcall(setter, text)
	end
end

local function createRound(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, transparency: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency
	s.Thickness = 1
	s.Parent = parent
	return s
end

local function createCard(parent: Instance, y: number, h: number)
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.Position = UDim2.fromOffset(0, y)
	wrap.Size = UDim2.new(1, 0, 0, h)
	wrap.Parent = parent

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = wrap
	createRound(card, 12)
	stroke(card, Color3.fromRGB(90, 90, 110), 0.42)
	return card
end

local function smallButton(parent: Instance, text: string, x: number, w: number, color: Color3)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(w, 28)
	btn.Position = UDim2.fromOffset(x, 0)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = 0.06
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamSemibold
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = false
	btn.Parent = parent
	createRound(btn, 8)
	stroke(btn, Color3.fromRGB(255, 255, 255), 0.82)
	return btn
end

local function header(parent: Instance, text: string, y: number)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.new(1, -28, 0, 18)
	l.Font = Enum.Font.GothamSemibold
	l.Text = text
	l.TextSize = 13
	l.TextColor3 = Color3.fromRGB(236, 236, 246)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function body(parent: Instance, text: string, y: number, h: number, color: Color3)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.new(1, -28, 0, h)
	l.Font = Enum.Font.Gotham
	l.Text = text
	l.TextSize = 12
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Parent = parent
	return l
end

local function renderRow(parent: Instance, word: string, rank: number, highlight: boolean, onStar: (() -> ())?, onCopy: (() -> ())?, onSelect: (() -> ())?)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -2, 0, 38)
	row.BackgroundColor3 = highlight and Color3.fromRGB(60, 82, 146) or Color3.fromRGB(34, 34, 42)
	row.BackgroundTransparency = 0.05
	row.BorderSizePixel = 0
	row.Parent = parent
	createRound(row, 10)
	stroke(row, highlight and Color3.fromRGB(125, 153, 255) or Color3.fromRGB(82, 82, 100), 0.38)

	local lbl = Instance.new("TextButton")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.Size = UDim2.new(1, -170, 1, 0)
	lbl.Font = highlight and Enum.Font.GothamSemibold or Enum.Font.Gotham
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.fromRGB(245, 245, 250)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = string.format("%d. %s", rank, word)
	lbl.AutoButtonColor = false
	lbl.Parent = row

	local star = smallButton(row, "★", 1, 30, Color3.fromRGB(90, 114, 180))
	star.Position = UDim2.new(1, -150, 0.5, -14)
	local copy = smallButton(row, "복사", 1, 54, Color3.fromRGB(86, 136, 104))
	copy.Position = UDim2.new(1, -112, 0.5, -14)

	lbl.MouseButton1Click:Connect(function()
		if onSelect then onSelect() end
	end)
	star.MouseButton1Click:Connect(function()
		if onStar then onStar() end
	end)
	copy.MouseButton1Click:Connect(function()
		if onCopy then onCopy() end
	end)

	return row
end

local function refreshContainer(frame: ScrollingFrame, items: {string}, bestText: string?, bestInfo: string?, headline: TextLabel?)
	clearChildren(frame)
	if #items == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 24)
		empty.BackgroundTransparency = 1
		empty.Text = "결과가 없습니다."
		empty.TextColor3 = Color3.fromRGB(172, 172, 182)
		empty.TextSize = 12
		empty.Font = Enum.Font.Gotham
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = frame
		return
	end
	for i, w in ipairs(items) do
		local word = w
		renderRow(frame, word, i, i == 1, function()
			dedupePush(favorites, word, 100, true)
		end, function()
			trySetClipboard(word)
			dedupePush(history, word, 50, true)
		end, function()
			trySetClipboard(word)
		end)
	end
end

local function buildUI()
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.new(0.5, 0, 0.42, 0)
	main.Size = UDim2.fromOffset(640, 440)
	main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	main.BackgroundTransparency = 0.25
	main.BorderSizePixel = 0
	main.ClipsDescendants = true
	main.Parent = screenGui
	createRound(main, 16)
	stroke(main, Color3.fromRGB(88, 88, 108), 0.18)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.96
	scale.Parent = main

	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 48)
	topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	topBar.BackgroundTransparency = 0.05
	topBar.BorderSizePixel = 0
	topBar.Parent = main
	createRound(topBar, 16)

	local cover = Instance.new("Frame")
	cover.Size = UDim2.new(1, 0, 0, 10)
	cover.Position = UDim2.new(0, 0, 1, -10)
	cover.BackgroundColor3 = topBar.BackgroundColor3
	cover.BackgroundTransparency = topBar.BackgroundTransparency
	cover.BorderSizePixel = 0
	cover.Parent = topBar

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -220, 1, 0)
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
	createRound(meta, 8)

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(14, 58)
	tabs.Size = UDim2.new(1, -28, 0, 38)
	tabs.Parent = main

	local tlayout = Instance.new("UIListLayout")
	tlayout.FillDirection = Enum.FillDirection.Horizontal
	tlayout.Padding = UDim.new(0, 8)
	tlayout.SortOrder = Enum.SortOrder.LayoutOrder
	tlayout.Parent = tabs

	local function tabButton(text: string)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(120, 34)
		btn.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
		btn.BackgroundTransparency = 0.06
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		btn.Text = text
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamSemibold
		btn.TextColor3 = Color3.fromRGB(220, 220, 230)
		btn.Parent = tabs
		createRound(btn, 10)
		stroke(btn, Color3.fromRGB(255, 255, 255), 0.88)
		return btn
	end

	local tabSearch = tabButton("단어검색")
	local tabLoad = tabButton("불러오기")
	local tabFav = tabButton("즐겨찾기")
	local tabHist = tabButton("기록")
	local tabSet = tabButton("설정")

	local indicator = Instance.new("Frame")
	indicator.Size = UDim2.fromOffset(120, 3)
	indicator.Position = UDim2.fromOffset(14, 92)
	indicator.BackgroundColor3 = Color3.fromRGB(94, 129, 255)
	indicator.BorderSizePixel = 0
	indicator.Parent = main
	createRound(indicator, 2)

	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(14, 102)
	content.Size = UDim2.new(1, -28, 1, -116)
	content.Parent = main

	local pages: {[TabName]: CanvasGroup} = {}
	local xMap = { search = 14, load = 142, favorites = 270, history = 398, settings = 526 }

	local function makePage(name: TabName)
		local page = Instance.new("CanvasGroup")
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, 0, 1, 0)
		page.GroupTransparency = 1
		page.Visible = false
		page.Parent = content
		pages[name] = page
		return page
	end

	local pageSearch = makePage("search")
	local pageLoad = makePage("load")
	local pageFav = makePage("favorites")
	local pageHist = makePage("history")
	local pageSet = makePage("settings")

	local function makePageCard(parent: Instance, y: number, h: number)
		local wrap = Instance.new("Frame")
		wrap.BackgroundTransparency = 1
		wrap.Position = UDim2.fromOffset(0, y)
		wrap.Size = UDim2.new(1, 0, 0, h)
		wrap.Parent = parent
		return createCard(wrap, 0, h)
	end

	-- SEARCH PAGE
	local sControls = makePageCard(pageSearch, 0, 92)
	local sSpot = makePageCard(pageSearch, 98, 72)
	local sListCard = makePageCard(pageSearch, 176, 146)

	local sBox = Instance.new("TextBox")
	sBox.Size = UDim2.new(1, -240, 0, 36)
	sBox.Position = UDim2.fromOffset(12, 12)
	sBox.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
	sBox.BackgroundTransparency = 0.02
	sBox.BorderSizePixel = 0
	sBox.ClearTextOnFocus = false
	sBox.Font = Enum.Font.GothamMedium
	sBox.PlaceholderText = "'다' 로 시작하는 단어"
	sBox.PlaceholderColor3 = Color3.fromRGB(154, 154, 164)
	sBox.TextSize = 13
	sBox.TextColor3 = Color3.fromRGB(250, 250, 250)
	sBox.Parent = sControls
	createRound(sBox, 10)
	stroke(sBox, Color3.fromRGB(255, 255, 255), 0.9)

	local sSearchBtn = smallButton(sControls, "검색", 418, 72, Color3.fromRGB(66, 93, 182))
	local sCopyBtn = smallButton(sControls, "복사", 494, 72, Color3.fromRGB(86, 136, 104))
	local sFavBtn = smallButton(sControls, "즐겨찾기", 570, 84, Color3.fromRGB(118, 92, 170))
	sSearchBtn.Position = UDim2.new(1, -226, 0, 12)
	sCopyBtn.Position = UDim2.new(1, -150, 0, 12)
	sFavBtn.Position = UDim2.new(1, -74, 0, 12)

	local sStatus = body(sControls, "문구를 입력하면 시작 문자열을 자동 추출합니다.", 54, 18, Color3.fromRGB(180, 180, 190))

	local sHeadline = header(sSpot, "최우선 추천", 10)
	local sBest = body(sSpot, "-", 28, 20, Color3.fromRGB(110, 190, 255))
	local sInfo = body(sSpot, "길이/희귀도 기반 정렬", 44, 16, Color3.fromRGB(175, 175, 185))

	local sList = Instance.new("ScrollingFrame")
	sList.BackgroundTransparency = 1
	sList.BorderSizePixel = 0
	sList.Position = UDim2.fromOffset(10, 8)
	sList.Size = UDim2.new(1, -20, 1, -16)
	sList.ScrollBarThickness = 6
	sList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	sList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sList.CanvasSize = UDim2.new(0, 0, 0, 0)
	sList.Parent = sListCard
	local sLayout = Instance.new("UIListLayout", sList)
	sLayout.Padding = UDim.new(0, 6)
	sLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", sList).PaddingTop = UDim.new(0, 2)

	-- LOAD PAGE
	local lControls = makePageCard(pageLoad, 0, 92)
	local lSpot = makePageCard(pageLoad, 98, 72)
	local lListCard = makePageCard(pageLoad, 176, 146)

	local lPrompt = body(lControls, "감지 대기", 28, 20, Color3.fromRGB(140, 210, 255))
	local lSource = body(lControls, "출처: -", 46, 16, Color3.fromRGB(170, 170, 182))
	local lReload = smallButton(lControls, "불러오기", 418, 72, Color3.fromRGB(62, 132, 95))
	local lAuto = smallButton(lControls, "자동감지: ON", 338, 96, Color3.fromRGB(66, 93, 182))
	local lCopy = smallButton(lControls, "자동복사: ON", 236, 96, Color3.fromRGB(118, 92, 170))
	local lPlay = smallButton(lControls, "AutoPlay: OFF", 130, 106, Color3.fromRGB(86, 136, 104))
	lReload.Position = UDim2.new(1, -74, 0, 12)
	lAuto.Position = UDim2.new(1, -176, 0, 12)
	lCopy.Position = UDim2.new(1, -280, 0, 12)
	lPlay.Position = UDim2.new(1, -392, 0, 12)

	local lHeadline = header(lSpot, "최우선 추천", 10)
	local lBest = body(lSpot, "-", 28, 20, Color3.fromRGB(110, 190, 255))
	local lInfo = body(lSpot, "탐지 후 자동 추천", 44, 16, Color3.fromRGB(175, 175, 185))

	local lList = Instance.new("ScrollingFrame")
	lList.BackgroundTransparency = 1
	lList.BorderSizePixel = 0
	lList.Position = UDim2.fromOffset(10, 8)
	lList.Size = UDim2.new(1, -20, 1, -16)
	lList.ScrollBarThickness = 6
	lList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	lList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lList.CanvasSize = UDim2.new(0, 0, 0, 0)
	lList.Parent = lListCard
	local lLayout = Instance.new("UIListLayout", lList)
	lLayout.Padding = UDim.new(0, 6)
	lLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", lList).PaddingTop = UDim.new(0, 2)

	-- FAVORITES PAGE
	local fControls = makePageCard(pageFav, 0, 58)
	local fListCard = makePageCard(pageFav, 64, 158)
	header(fControls, "즐겨찾기", 10)
	body(fControls, "단어를 별표로 저장합니다.", 28, 16, Color3.fromRGB(175, 175, 185))
	local fClear = smallButton(fControls, "전체삭제", 438, 84, Color3.fromRGB(150, 90, 90))
	local fReload = smallButton(fControls, "갱신", 356, 72, Color3.fromRGB(66, 93, 182))
	fClear.Position = UDim2.new(1, -98, 0, 14)
	fReload.Position = UDim2.new(1, -178, 0, 14)
	local fList = Instance.new("ScrollingFrame")
	fList.BackgroundTransparency = 1
	fList.BorderSizePixel = 0
	fList.Position = UDim2.fromOffset(10, 8)
	fList.Size = UDim2.new(1, -20, 1, -16)
	fList.ScrollBarThickness = 6
	fList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	fList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	fList.CanvasSize = UDim2.new(0, 0, 0, 0)
	fList.Parent = fListCard
	local fLayout = Instance.new("UIListLayout", fList)
	fLayout.Padding = UDim.new(0, 6)
	fLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", fList).PaddingTop = UDim.new(0, 2)

	-- HISTORY PAGE
	local hControls = makePageCard(pageHist, 0, 58)
	local hListCard = makePageCard(pageHist, 64, 158)
	header(hControls, "기록", 10)
	body(hControls, "최근 사용 단어를 저장합니다.", 28, 16, Color3.fromRGB(175, 175, 185))
	local hClear = smallButton(hControls, "전체삭제", 438, 84, Color3.fromRGB(150, 90, 90))
	local hReload = smallButton(hControls, "갱신", 356, 72, Color3.fromRGB(66, 93, 182))
	hClear.Position = UDim2.new(1, -98, 0, 14)
	hReload.Position = UDim2.new(1, -178, 0, 14)
	local hList = Instance.new("ScrollingFrame")
	hList.BackgroundTransparency = 1
	hList.BorderSizePixel = 0
	hList.Position = UDim2.fromOffset(10, 8)
	hList.Size = UDim2.new(1, -20, 1, -16)
	hList.ScrollBarThickness = 6
	hList.ScrollBarImageColor3 = Color3.fromRGB(116, 132, 220)
	hList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	hList.CanvasSize = UDim2.new(0, 0, 0, 0)
	hList.Parent = hListCard
	local hLayout = Instance.new("UIListLayout", hList)
	hLayout.Padding = UDim.new(0, 6)
	hLayout.SortOrder = Enum.SortOrder.LayoutOrder
	Instance.new("UIPadding", hList).PaddingTop = UDim.new(0, 2)

	-- SETTINGS PAGE
	local setPanel = createCard(pageSet, 0, 240)
	header(setPanel, "설정", 10)
	body(setPanel, "UI와 정렬 방식, 안전 자동 기능을 조절합니다.", 28, 16, Color3.fromRGB(175, 175, 185))
	local minLabel = body(setPanel, "최소 글자수", 56, 16, Color3.fromRGB(220, 220, 230))
	local minBox = Instance.new("TextBox")
	minBox.Size = UDim2.fromOffset(76, 28)
	minBox.Position = UDim2.fromOffset(112, 52)
	minBox.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
	minBox.BackgroundTransparency = 0.02
	minBox.BorderSizePixel = 0
	minBox.ClearTextOnFocus = false
	minBox.Font = Enum.Font.GothamMedium
	minBox.Text = tostring(state.minLength)
	minBox.TextSize = 12
	minBox.TextColor3 = Color3.fromRGB(250, 250, 250)
	minBox.Parent = setPanel
	createRound(minBox, 8)
	stroke(minBox, Color3.fromRGB(255, 255, 255), 0.9)

	local modeLabel = body(setPanel, "정렬 모드", 92, 16, Color3.fromRGB(220, 220, 230))
	local bPri = smallButton(setPanel, "우선순위", 14, 84, Color3.fromRGB(66, 93, 182)); bPri.Position = UDim2.fromOffset(112, 88)
	local bLen = smallButton(setPanel, "길이", 106, 72, Color3.fromRGB(86, 136, 104)); bLen.Position = UDim2.fromOffset(202, 88)
	local bRar = smallButton(setPanel, "희귀도", 184, 84, Color3.fromRGB(118, 92, 170)); bRar.Position = UDim2.fromOffset(280, 88)
	local bAla = smallButton(setPanel, "가나다", 274, 84, Color3.fromRGB(150, 120, 90)); bAla.Position = UDim2.fromOffset(370, 88)

	local onlyPri = smallButton(setPanel, "희귀/특수만: OFF", 14, 140, Color3.fromRGB(95, 95, 120)); onlyPri.Position = UDim2.fromOffset(14, 128)
	local aDet = smallButton(setPanel, "자동감지: ON", 160, 120, Color3.fromRGB(66, 93, 182)); aDet.Position = UDim2.fromOffset(160, 128)
	local aCopy = smallButton(setPanel, "자동복사: ON", 286, 120, Color3.fromRGB(118, 92, 170)); aCopy.Position = UDim2.fromOffset(286, 128)
	local aPlay = smallButton(setPanel, "AutoPlay: OFF", 412, 128, Color3.fromRGB(86, 136, 104)); aPlay.Position = UDim2.fromOffset(412, 128)

	local reset = smallButton(setPanel, "위치/크기 초기화", 14, 142, Color3.fromRGB(150, 90, 90)); reset.Position = UDim2.fromOffset(14, 170)
	local favClear2 = smallButton(setPanel, "즐겨찾기 삭제", 162, 126, Color3.fromRGB(150, 90, 90)); favClear2.Position = UDim2.fromOffset(162, 170)
	local histClear2 = smallButton(setPanel, "기록 삭제", 294, 108, Color3.fromRGB(150, 90, 90)); histClear2.Position = UDim2.fromOffset(294, 170)

	local info = body(setPanel, "AutoPlay는 자동 추천/복사만 수행하며 외부 입력 자동화는 하지 않습니다.", 214, 20, Color3.fromRGB(170, 170, 182))

	local resizeHandle = Instance.new("TextButton")
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
	createRound(resizeHandle, 6)

	local function getCurrentCandidates(): {string}
		local prefix = state.currentPrefix
		if prefix == "" then return {} end
		return getPrefixCandidates(prefix)
	end

	local function renderList(frame: ScrollingFrame, items: {string}, emptyMessage: string)
		clearChildren(frame)
		if #items == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.BackgroundTransparency = 1
			empty.Text = emptyMessage
			empty.TextColor3 = Color3.fromRGB(172, 172, 182)
			empty.TextSize = 12
			empty.Font = Enum.Font.Gotham
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Parent = frame
			return
		end
		for i, word in ipairs(items) do
			renderRow(frame, word, i, i == 1, function()
				dedupePush(favorites, word, 100, true)
			end, function()
				tryClipboard(word)
				dedupePush(history, word, 50, true)
			end, function()
				tryClipboard(word)
			end)
		end
	end

	local function refreshSearch()
		local prefix, candidates = getSearchCandidates(sBox.Text)
		sHeadline.Text = prefix ~= "" and string.format("'%s' 로 시작하는 단어", prefix) or "검색 결과"
		if prefix ~= "" then sStatus.Text = "검색 기준: " .. prefix else sStatus.Text = "문구를 입력하면 시작 문자열을 자동 추출합니다." end
		clearChildren(sList)
		if #candidates == 0 then
			body(sList, "결과가 없습니다.", 0, 18, Color3.fromRGB(172, 172, 182))
			sBest.Text, sInfo.Text = "-", "길이/희귀도 기반 정렬"
			return
		end
		sBest.Text = candidates[1]
		sInfo.Text = string.format("길이 %d / 점수 %d", graphemeCount(normalizeHangul(candidates[1])), candidateScore(normalizeHangul(candidates[1])))
		state.currentBest = candidates[1]
		if state.autoCopy and state.safeAutoPlay and state.lastAutoCopied ~= candidates[1] then
			tryClipboard(candidates[1])
			state.lastAutoCopied = candidates[1]
		end
		renderList(sList, candidates, "검색할 시작 문자열이 없습니다.")
	end

	local function refreshLoad()
		lPrompt.Text = state.currentRawPrompt ~= "" and state.currentRawPrompt or "감지 대기"
		lSource.Text = state.currentSource ~= "" and ("출처: " .. state.currentSource) or "출처: -"
		if not state.dictionaryLoaded and state.dictionaryError ~= "" then
			lHeadline.Text = "불러오기 실패"
			lBest.Text = "word.lua 오류"
			lInfo.Text = "로드 실패"
			clearChildren(lList)
			body(lList, "word.lua 로드 실패: " .. state.dictionaryError, 0, 24, Color3.fromRGB(255, 150, 150))
			return
		end
		lHeadline.Text = state.currentPrefix ~= "" and string.format("'%s' 로 시작하는 단어", state.currentPrefix) or "탐지 대기"
		local candidates = getCurrentCandidates()
		clearChildren(lList)
		if #candidates == 0 then
			body(lList, "탐지 문구를 기다리는 중", 0, 18, Color3.fromRGB(172, 172, 182))
			lBest.Text, lInfo.Text = "-", "탐지 후 자동 추천"
			return
		end
		lBest.Text = candidates[1]
		lInfo.Text = string.format("길이 %d / 점수 %d", graphemeCount(normalizeHangul(candidates[1])), candidateScore(normalizeHangul(candidates[1])))
		state.currentBest = candidates[1]
		if state.autoCopy and state.safeAutoPlay and state.lastAutoCopied ~= candidates[1] then
			tryClipboard(candidates[1])
			state.lastAutoCopied = candidates[1]
		end
		renderList(lList, candidates, "탐지 문구를 기다리는 중")
	end

	local function refreshFavorites()
		clearChildren(fList)
		if #favorites == 0 then
			body(fList, "즐겨찾기가 비어 있습니다.", 0, 18, Color3.fromRGB(172, 172, 182))
			return
		end
		for i, word in ipairs(favorites) do
			renderRow(fList, word, i, false, function()
				-- keep
			end, function()
				tryClipboard(word)
				dedupePush(history, word, 50, true)
			end, function()
				tryClipboard(word)
			end)
		end
	end

	local function refreshHistory()
		clearChildren(hList)
		if #history == 0 then
			body(hList, "기록이 비어 있습니다.", 0, 18, Color3.fromRGB(172, 172, 182))
			return
		end
		for i, word in ipairs(history) do
			renderRow(hList, word, i, false, function() end, function() tryClipboard(word) end, function() tryClipboard(word) end)
		end
	end

	local function setTab(tab: TabName)
		state.activeTab = tab
		for name, btn in pairs({
			search = tabSearch,
			load = tabLoad,
			favorites = tabFav,
			history = tabHist,
			settings = tabSet,
		}) do
			local active = (name == tab)
			btn.BackgroundColor3 = active and Color3.fromRGB(66, 93, 182) or Color3.fromRGB(34, 34, 42)
			btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(220, 220, 230)
		end
		makeTween(indicator, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(xMap[tab], 92)
		})
		for name, page in pairs(pages) do
			page.Visible = true
			makeTween(page, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				GroupTransparency = (name == tab) and 0 or 1
			})
			makeTween(page, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, (name == tab) and 0 or -24, 0, 0)
			})
		end
		task.delay(0.24, function()
			for name, page in pairs(pages) do
				if name ~= tab then
					page.Visible = false
				end
			end
		end)
		if tab == "search" then refreshSearch()
		elseif tab == "load" then refreshLoad()
		elseif tab == "favorites" then refreshFavorites()
		elseif tab == "history" then refreshHistory()
		end
	end

	tabSearch.MouseButton1Click:Connect(function() setTab("search") end)
	tabLoad.MouseButton1Click:Connect(function() setTab("load") end)
	tabFav.MouseButton1Click:Connect(function() setTab("favorites") end)
	tabHist.MouseButton1Click:Connect(function() setTab("history") end)
	tabSet.MouseButton1Click:Connect(function() setTab("settings") end)

	sBox:GetPropertyChangedSignal("Text"):Connect(function()
		if state.activeTab == "search" then refreshSearch() end
	end)

	sSearchBtn.MouseButton1Click:Connect(function()
		setTab("search")
		refreshSearch()
	end)
	sCopyBtn.MouseButton1Click:Connect(function()
		local prefix, candidates = getSearchCandidates(sBox.Text)
		if candidates[1] then tryClipboard(candidates[1]); dedupePush(history, candidates[1], 50, true) end
		if prefix ~= "" then sBox.Text = prefix end
	end)
	sFavBtn.MouseButton1Click:Connect(function()
		local _, candidates = getSearchCandidates(sBox.Text)
		if candidates[1] then
			dedupePush(favorites, candidates[1], 100, true)
			refreshFavorites()
		end
	end)

	lReload.MouseButton1Click:Connect(function()
		loadDictionary()
		refreshLoad()
	end)
	lAuto.MouseButton1Click:Connect(function()
		state.autoDetect = not state.autoDetect
		lAuto.Text = state.autoDetect and "자동감지: ON" or "자동감지: OFF"
	end)
	lCopy.MouseButton1Click:Connect(function()
		state.autoCopy = not state.autoCopy
		lCopy.Text = state.autoCopy and "자동복사: ON" or "자동복사: OFF"
	end)
	lPlay.MouseButton1Click:Connect(function()
		state.safeAutoPlay = not state.safeAutoPlay
		lPlay.Text = state.safeAutoPlay and "AutoPlay: ON" or "AutoPlay: OFF"
	end)

	fClear.MouseButton1Click:Connect(function()
		table.clear(favorites)
		refreshFavorites()
	end)
	fReload.MouseButton1Click:Connect(function() refreshFavorites() end)

	hClear.MouseButton1Click:Connect(function()
		table.clear(history)
		refreshHistory()
	end)
	hReload.MouseButton1Click:Connect(function() refreshHistory() end)

	bPri.MouseButton1Click:Connect(function() state.sortMode = "priority"; if state.activeTab == "search" then refreshSearch() elseif state.activeTab == "load" then refreshLoad() end end)
	bLen.MouseButton1Click:Connect(function() state.sortMode = "length"; if state.activeTab == "search" then refreshSearch() elseif state.activeTab == "load" then refreshLoad() end end)
	bRar.MouseButton1Click:Connect(function() state.sortMode = "rarity"; if state.activeTab == "search" then refreshSearch() elseif state.activeTab == "load" then refreshLoad() end end)
	bAla.MouseButton1Click:Connect(function() state.sortMode = "alpha"; if state.activeTab == "search" then refreshSearch() elseif state.activeTab == "load" then refreshLoad() end end)

	onlyPri.MouseButton1Click:Connect(function()
		state.onlyPriority = not state.onlyPriority
		onlyPri.Text = state.onlyPriority and "희귀/특수만: ON" or "희귀/특수만: OFF"
		if state.activeTab == "search" then refreshSearch() elseif state.activeTab == "load" then refreshLoad() end
	end)
	aDet.MouseButton1Click:Connect(function()
		state.autoDetect = not state.autoDetect
		aDet.Text = state.autoDetect and "자동감지: ON" or "자동감지: OFF"
		lAuto.Text = aDet.Text
	end)
	aCopy.MouseButton1Click:Connect(function()
		state.autoCopy = not state.autoCopy
		aCopy.Text = state.autoCopy and "자동복사: ON" or "자동복사: OFF"
		lCopy.Text = aCopy.Text
	end)
	aPlay.MouseButton1Click:Connect(function()
		state.safeAutoPlay = not state.safeAutoPlay
		aPlay.Text = state.safeAutoPlay and "AutoPlay: ON" or "AutoPlay: OFF"
		lPlay.Text = aPlay.Text
	end)

	minBox.FocusLost:Connect(function()
		local n = tonumber(minBox.Text)
		if n then
			n = math.clamp(math.floor(n), 1, 20)
			state.minLength = n
			minBox.Text = tostring(n)
			if state.activeTab == "search" then refreshSearch() elseif state.activeTab == "load" then refreshLoad() end
		else
			minBox.Text = tostring(state.minLength)
		end
	end)

	reset.MouseButton1Click:Connect(function()
		main.Size = UDim2.fromOffset(640, 440)
		main.Position = UDim2.new(0.5, 0, 0.42, 0)
	end)

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
			if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement or not dragStart or not startPos then
				return
			end
			local delta = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end)
	end

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
			if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not resizing or input.UserInputType ~= Enum.UserInputType.MouseMovement or not resizeStart or not startSize then return end
			local delta = input.Position - resizeStart
			local newW = math.clamp(startSize.X.Offset + delta.X, 520, 920)
			local newH = math.clamp(startSize.Y.Offset + delta.Y, 340, 680)
			main.Size = UDim2.fromOffset(newW, newH)
		end)
	end

	local function animateIntro()
		scale.Scale = 0.96
		main.Position = UDim2.new(0.5, 0, 0.44, 0)
		makeTween(scale, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 })
		makeTween(main, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.42, 0) })
	end

	local function detectPrompt()
		if not state.autoDetect then return end
		local roots = { PlayerGui, CoreGui }
		local bestRaw, bestPrefix, bestSource = "", "", ""
		for _, root in ipairs(roots) do
			for _, obj in ipairs(root:GetDescendants()) do
				if obj:IsDescendantOf(screenGui) then continue end
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
			if state.autoCopy and state.safeAutoPlay and state.currentBest ~= "" and state.lastAutoCopied ~= state.currentBest then
				tryClipboard(state.currentBest)
				state.lastAutoCopied = state.currentBest
			end
			if state.activeTab == "load" then refreshLoad() end
		end
	end

	animateIntro()
	setTab("load")

	task.spawn(function()
		while screenGui.Parent do
			detectPrompt()
			task.wait(SCAN_INTERVAL)
		end
	end)

	task.defer(function()
		if not state.dictionaryLoaded and state.dictionaryError ~= "" then
			lPrompt.Text = "word.lua 로드 실패"
			lSource.Text = "출처: -"
			lBest.Text = "오류"
			lInfo.Text = state.dictionaryError
		end
	end)

	task.delay(0.1, function()
		refreshLoad()
		refreshSearch()
		refreshFavorites()
		refreshHistory()
	end)
end

loadDictionary()
buildUI()
