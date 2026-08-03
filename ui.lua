```lua
--!strict
-- ui.lua | WordScript Hub
-- 기능:
-- 1) word.lua (GitHub Raw) 로드
-- 2) PlayerGui/CoreGui를 0.1초마다 감시
-- 3) 현재 표시 중인 한국어 단어를 추출
-- 4) 그 끝글자 기준으로 가장 길거나 희귀한 후보를 표시
-- 5) "단어검색" / "불러오기" 탭 분리
-- 6) 드래그 가능, 작은 크기, 배경 투명도 0.25

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local WORD_URL = "https://raw.githubusercontent.com/cjwstar25-png/rorwjm/main/word.lua"
local SCAN_INTERVAL = 0.1
local MAX_RESULTS = 8

local OurGuiName = "WordScriptHub"

local state = {
	dictionaryLoaded = false,
	dictionaryLoading = false,
	dictionaryError = "",
	totalWords = 0,
	currentWord = "",
	detectedSource = "",
	autoDetect = true,
	activeTab = "search",
	lastRefresh = 0,
}

local dictionaryWords: {string} = {}
local indexByStart: {[string]: {string}} = {}
local seenWords: {[string]: boolean} = {}
local objectTextCache: {[Instance]: string} = {}
local rareTokens = {
	"슘", "듐", "븀", "륨", "튬", "늄", "뮴", "윰", "돓", "긿", "읅", "가녘", "가취끗",
	"가뿟", "가뿐", "가재무릇", "가짓부렁", "기동돓", "화학연료료켓", "역추진로켓",
	"왕듸", "듸레", "차풰"
}

local blacklistTexts = {
	["단어검색"] = true,
	["불러오기"] = true,
	["검색"] = true,
	["불러오기"] = true,
	["새로고침"] = true,
	["갱신"] = true,
	["닫기"] = true,
	["접기"] = true,
	["열기"] = true,
	["탭"] = true,
	["WordScript"] = true,
	["WordScript Hub"] = true,
	["감지 대기"] = true,
	["현재 단어"] = true,
	["추천 후보"] = true,
	["데이터"] = true,
	["상태"] = true,
}

local function trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeForIndex(word: string): string
	word = tostring(word or "")
	word = word:gsub("%s+", "")
	word = word:gsub("[^가-힣]", "")
	return word
end

local function isHangulOnly(word: string): boolean
	return word ~= "" and word:match("^[가-힣]+$") ~= nil
end

local function getGraphemeCount(text: string): number
	local count = 0
	for _ in utf8.graphemes(text) do
		count += 1
	end
	return count
end

local function getFirstGrapheme(text: string): string
	for first, last in utf8.graphemes(text) do
		return string.sub(text, first, last)
	end
	return ""
end

local function getLastGrapheme(text: string): string
	local result = ""
	for first, last in utf8.graphemes(text) do
		result = string.sub(text, first, last)
	end
	return result
end

local function safeVisibleText(inst: Instance): string
	if inst:IsDescendantOf(workspace) then
		-- workspace 쪽은 이번 구조에서 감시 대상이 아님
	end

	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local okVisible, visible = pcall(function()
			return (inst :: any).Visible
		end)
		if okVisible and visible == false then
			return ""
		end

		local okText, txt = pcall(function()
			return (inst :: any).Text
		end)
		if not okText then
			return ""
		end

		txt = trim(tostring(txt or ""))
		if txt == "" then
			return ""
		end
		if blacklistTexts[txt] then
			return ""
		end

		local normalized = normalizeForIndex(txt)
		if not isHangulOnly(normalized) then
			return ""
		end

		if getGraphemeCount(normalized) < 1 or getGraphemeCount(normalized) > 12 then
			return ""
		end

		return normalized
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
		score += 18
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
	local len = getGraphemeCount(word)
	local score = len * 12
	score += rarityScore(word)

	if len >= 4 then
		score += 10
	end
	if len >= 6 then
		score += 15
	end
	if len >= 8 then
		score += 18
	end

	return score
end

local function clearList(frame: Frame | ScrollingFrame)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end
end

local function cloneArray<T>(arr: {T}): {T}
	local copy = table.create(#arr)
	for i, v in ipairs(arr) do
		copy[i] = v
	end
	return copy
end

local function addWord(word: string)
	word = trim(tostring(word or ""))
	local key = normalizeForIndex(word)
	if key == "" then
		return
	end
	if seenWords[key] then
		return
	end

	seenWords[key] = true
	table.insert(dictionaryWords, word)

	local first = getFirstGrapheme(key)
	if first ~= "" then
		indexByStart[first] = indexByStart[first] or {}
		table.insert(indexByStart[first], word)
	end
end

local function ingestTable(tbl: any)
	if type(tbl) ~= "table" then
		return
	end

	if type(tbl.words) == "table" then
		for _, v in ipairs(tbl.words) do
			if type(v) == "string" then
				addWord(v)
			end
		end
		return
	end

	if type(tbl.Words) == "table" then
		for _, v in ipairs(tbl.Words) do
			if type(v) == "string" then
				addWord(v)
			end
		end
		return
	end

	if type(tbl.data) == "table" then
		for _, v in ipairs(tbl.data) do
			if type(v) == "string" then
				addWord(v)
			end
		end
		return
	end

	for k, v in pairs(tbl) do
		if type(k) == "number" and type(v) == "string" then
			addWord(v)
		end
	end
end

local function loadDictionary()
	if state.dictionaryLoading then
		return
	end

	state.dictionaryLoading = true
	state.dictionaryError = ""
	state.dictionaryLoaded = false

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

	ingestTable(result)

	state.totalWords = #dictionaryWords
	state.dictionaryLoaded = true
	state.dictionaryLoading = false
end

local function getCandidatesFromWord(sourceWord: string): {string}
	sourceWord = normalizeForIndex(sourceWord)
	if sourceWord == "" then
		return {}
	end

	local lastChar = getLastGrapheme(sourceWord)
	if lastChar == "" then
		return {}
	end

	local pool = indexByStart[lastChar]
	if not pool or #pool == 0 then
		return {}
	end

	local scored = {}
	for _, word in ipairs(pool) do
		local display = trim(word)
		local key = normalizeForIndex(display)
		if key ~= "" then
			local score = candidateScore(key)
			table.insert(scored, {
				word = display,
				score = score,
				length = getGraphemeCount(key),
			})
		end
	end

	table.sort(scored, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		if a.length ~= b.length then
			return a.length > b.length
		end
		return a.word < b.word
	end)

	local results = {}
	for i = 1, math.min(MAX_RESULTS, #scored) do
		results[i] = scored[i].word
	end
	return results
end

local function getSearchMatches(queryWord: string): {string}
	queryWord = normalizeForIndex(queryWord)
	if queryWord == "" then
		return {}
	end

	local results = {}
	local qLen = getGraphemeCount(queryWord)

	for _, word in ipairs(dictionaryWords) do
		local key = normalizeForIndex(word)
		if key ~= "" then
			if key:sub(1, #queryWord) == queryWord then
				table.insert(results, word)
			end
		end
	end

	table.sort(results, function(a, b)
		local sa = candidateScore(normalizeForIndex(a))
		local sb = candidateScore(normalizeForIndex(b))
		if sa ~= sb then
			return sa > sb
		end
		local la = getGraphemeCount(normalizeForIndex(a))
		local lb = getGraphemeCount(normalizeForIndex(b))
		if la ~= lb then
			return la > lb
		end
		return a < b
	end)

	local trimmed = {}
	for i = 1, math.min(MAX_RESULTS, #results) do
		trimmed[i] = results[i]
	end
	return trimmed
end

local function detectCurrentWord(): (string, string)
	local bestWord = ""
	local bestSource = ""

	local roots = {PlayerGui}
	local okCore = pcall(function()
		return CoreGui.Parent ~= nil
	end)
	if okCore then
		table.insert(roots, CoreGui)
	end

	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetDescendants()) do
			if not obj:IsDescendantOf(script.Parent) then
				-- no-op
			end

			-- 우리의 UI는 제외
			if obj:IsDescendantOf(script.Parent) then
				continue
			end

			local text = safeVisibleText(obj)
			if text ~= "" then
				-- 너무 흔한 UI 문구는 제외
				if not blacklistTexts[text] then
					bestWord = text
					bestSource = obj:GetFullName()

					-- 최근 변경된 텍스트를 우선적으로 잡기 위해
					-- 현재 스캔에서 발견한 마지막 유효 텍스트를 사용
				end
			end
		end
	end

	return bestWord, bestSource
end

-- UI 생성
local screenGui = Instance.new("ScreenGui")
screenGui.Name = OurGuiName
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(390, 275)
main.Position = UDim2.new(0.5, -195, 0.35, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
main.BackgroundTransparency = 0.25
main.BorderSizePixel = 0
main.Active = true
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 1
mainStroke.Color = Color3.fromRGB(75, 75, 90)
mainStroke.Transparency = 0.2
mainStroke.Parent = main

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 38)
topBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
topBar.BackgroundTransparency = 0.08
topBar.BorderSizePixel = 0
topBar.Parent = main

local topBarCorner = Instance.new("UICorner")
topBarCorner.CornerRadius = UDim.new(0, 14)
topBarCorner.Parent = topBar

local topBarFix = Instance.new("Frame")
topBarFix.Size = UDim2.new(1, 0, 0, 10)
topBarFix.Position = UDim2.new(0, 0, 1, -10)
topBarFix.BackgroundColor3 = topBar.BackgroundColor3
topBarFix.BackgroundTransparency = topBar.BackgroundTransparency
topBarFix.BorderSizePixel = 0
topBarFix.Parent = topBar

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -100, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.Font = Enum.Font.GothamSemibold
title.Text = "WordScript"
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(235, 235, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
closeBtn.BackgroundTransparency = 0.05
closeBtn.Text = "×"
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(235, 235, 245)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Size = UDim2.new(1, -20, 0, 30)
tabBar.Position = UDim2.fromOffset(10, 44)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local function makeTabButton(text: string)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(104, 30)
	btn.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	btn.BackgroundTransparency = 0.05
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamMedium
	btn.TextColor3 = Color3.fromRGB(220, 220, 230)
	btn.AutoButtonColor = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = btn
	return btn
end

local searchTabBtn = makeTabButton("단어검색")
searchTabBtn.Parent = tabBar

local loadTabBtn = makeTabButton("불러오기")
loadTabBtn.Parent = tabBar

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -20, 1, -84)
content.Position = UDim2.fromOffset(10, 78)
content.BackgroundTransparency = 1
content.Parent = main

local searchPage = Instance.new("Frame")
searchPage.Name = "SearchPage"
searchPage.Size = UDim2.new(1, 0, 1, 0)
searchPage.BackgroundTransparency = 1
searchPage.Parent = content

local loadPage = Instance.new("Frame")
loadPage.Name = "LoadPage"
loadPage.Size = UDim2.new(1, 0, 1, 0)
loadPage.BackgroundTransparency = 1
loadPage.Visible = false
loadPage.Parent = content

local function makePanel(parent: Instance, height: number)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, 0, 0, height)
	panel.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = panel

	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = Color3.fromRGB(74, 74, 88)
	s.Transparency = 0.35
	s.Parent = panel

	return panel
end

local searchPanel = makePanel(searchPage, 185)
local loadPanel = makePanel(loadPage, 185)

local searchBox = Instance.new("TextBox")
searchBox.Name = "SearchBox"
searchBox.Size = UDim2.new(1, -20, 0, 32)
searchBox.Position = UDim2.fromOffset(10, 10)
searchBox.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
searchBox.BackgroundTransparency = 0.02
searchBox.TextColor3 = Color3.fromRGB(250, 250, 250)
searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
searchBox.PlaceholderText = "단어를 입력하거나 현재 단어를 확인하세요"
searchBox.Text = ""
searchBox.TextSize = 13
searchBox.Font = Enum.Font.GothamMedium
searchBox.ClearTextOnFocus = false
searchBox.BorderSizePixel = 0
searchBox.Parent = searchPanel

local searchBoxCorner = Instance.new("UICorner")
searchBoxCorner.CornerRadius = UDim.new(0, 8)
searchBoxCorner.Parent = searchBox

local searchBtn = Instance.new("TextButton")
searchBtn.Name = "SearchBtn"
searchBtn.Size = UDim2.fromOffset(70, 32)
searchBtn.Position = UDim2.new(1, -80, 0, 48)
searchBtn.BackgroundColor3 = Color3.fromRGB(70, 92, 170)
searchBtn.Text = "검색"
searchBtn.TextSize = 13
searchBtn.Font = Enum.Font.GothamSemibold
searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBtn.BorderSizePixel = 0
searchBtn.Parent = searchPanel

local searchBtnCorner = Instance.new("UICorner")
searchBtnCorner.CornerRadius = UDim.new(0, 8)
searchBtnCorner.Parent = searchBtn

local searchInfo = Instance.new("TextLabel")
searchInfo.Name = "SearchInfo"
searchInfo.BackgroundTransparency = 1
searchInfo.Size = UDim2.new(1, -100, 0, 20)
searchInfo.Position = UDim2.fromOffset(10, 48)
searchInfo.Font = Enum.Font.Gotham
searchInfo.Text = "검색 준비"
searchInfo.TextSize = 12
searchInfo.TextColor3 = Color3.fromRGB(180, 180, 190)
searchInfo.TextXAlignment = Enum.TextXAlignment.Left
searchInfo.Parent = searchPanel

local searchResults = Instance.new("ScrollingFrame")
searchResults.Name = "SearchResults"
searchResults.Size = UDim2.new(1, -20, 1, -90)
searchResults.Position = UDim2.fromOffset(10, 78)
searchResults.BackgroundTransparency = 1
searchResults.ScrollBarThickness = 4
searchResults.ScrollBarImageColor3 = Color3.fromRGB(110, 130, 220)
searchResults.BorderSizePixel = 0
searchResults.Parent = searchPanel

local searchLayout = Instance.new("UIListLayout")
searchLayout.Padding = UDim.new(0, 6)
searchLayout.SortOrder = Enum.SortOrder.LayoutOrder
searchLayout.Parent = searchResults

local searchPad = Instance.new("UIPadding")
searchPad.PaddingTop = UDim.new(0, 2)
searchPad.PaddingBottom = UDim.new(0, 4)
searchPad.Parent = searchResults

local loadHeader = Instance.new("TextLabel")
loadHeader.BackgroundTransparency = 1
loadHeader.Size = UDim2.new(1, -20, 0, 20)
loadHeader.Position = UDim2.fromOffset(10, 8)
loadHeader.Font = Enum.Font.GothamSemibold
loadHeader.Text = "불러오기 상태"
loadHeader.TextSize = 13
loadHeader.TextColor3 = Color3.fromRGB(235, 235, 245)
loadHeader.TextXAlignment = Enum.TextXAlignment.Left
loadHeader.Parent = loadPanel

local detectedLabel = Instance.new("TextLabel")
detectedLabel.BackgroundTransparency = 1
detectedLabel.Size = UDim2.new(1, -20, 0, 20)
detectedLabel.Position = UDim2.fromOffset(10, 32)
detectedLabel.Font = Enum.Font.Gotham
detectedLabel.Text = "현재 단어: 감지 대기"
detectedLabel.TextSize = 12
detectedLabel.TextColor3 = Color3.fromRGB(190, 190, 200)
detectedLabel.TextXAlignment = Enum.TextXAlignment.Left
detectedLabel.Parent = loadPanel

local sourceLabel = Instance.new("TextLabel")
sourceLabel.BackgroundTransparency = 1
sourceLabel.Size = UDim2.new(1, -20, 0, 18)
sourceLabel.Position = UDim2.fromOffset(10, 52)
sourceLabel.Font = Enum.Font.Gotham
sourceLabel.Text = "출처: -"
sourceLabel.TextSize = 11
sourceLabel.TextColor3 = Color3.fromRGB(160, 160, 175)
sourceLabel.TextXAlignment = Enum.TextXAlignment.Left
sourceLabel.Parent = loadPanel

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.fromOffset(86, 28)
refreshBtn.Position = UDim2.new(1, -96, 0, 76)
refreshBtn.BackgroundColor3 = Color3.fromRGB(62, 128, 92)
refreshBtn.Text = "데이터 불러오기"
refreshBtn.TextSize = 11
refreshBtn.Font = Enum.Font.GothamSemibold
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.BorderSizePixel = 0
refreshBtn.Parent = loadPanel

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 8)
refreshCorner.Parent = refreshBtn

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.fromOffset(86, 28)
autoBtn.Position = UDim2.new(1, -188, 0, 76)
autoBtn.BackgroundColor3 = Color3.fromRGB(70, 92, 170)
autoBtn.Text = "자동감지: ON"
autoBtn.TextSize = 11
autoBtn.Font = Enum.Font.GothamSemibold
autoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBtn.BorderSizePixel = 0
autoBtn.Parent = loadPanel

local autoCorner = Instance.new("UICorner")
autoCorner.CornerRadius = UDim.new(0, 8)
autoCorner.Parent = autoBtn

local bestLabel = Instance.new("TextLabel")
bestLabel.BackgroundTransparency = 1
bestLabel.Size = UDim2.new(1, -20, 0, 22)
bestLabel.Position = UDim2.fromOffset(10, 110)
bestLabel.Font = Enum.Font.GothamSemibold
bestLabel.Text = "추천 후보: -"
bestLabel.TextSize = 12
bestLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
bestLabel.TextXAlignment = Enum.TextXAlignment.Left
bestLabel.Parent = loadPanel

local loadResults = Instance.new("ScrollingFrame")
loadResults.Name = "LoadResults"
loadResults.Size = UDim2.new(1, -20, 1, -142)
loadResults.Position = UDim2.fromOffset(10, 136)
loadResults.BackgroundTransparency = 1
loadResults.ScrollBarThickness = 4
loadResults.ScrollBarImageColor3 = Color3.fromRGB(110, 130, 220)
loadResults.BorderSizePixel = 0
loadResults.Parent = loadPanel

local loadLayout = Instance.new("UIListLayout")
loadLayout.Padding = UDim.new(0, 6)
loadLayout.SortOrder = Enum.SortOrder.LayoutOrder
loadLayout.Parent = loadResults

local loadPad = Instance.new("UIPadding")
loadPad.PaddingTop = UDim.new(0, 2)
loadPad.PaddingBottom = UDim.new(0, 4)
loadPad.Parent = loadResults

local function updateCanvas(frame: ScrollingFrame, layout: UIListLayout)
	task.defer(function()
		frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end)
end

local function makeResultCard(parent: Instance, text: string, rank: number?, isBest: boolean?)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -2, 0, 28)
	card.BackgroundColor3 = isBest and Color3.fromRGB(58, 78, 134) or Color3.fromRGB(34, 34, 42)
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = card

	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = isBest and Color3.fromRGB(115, 145, 255) or Color3.fromRGB(74, 74, 88)
	s.Transparency = 0.35
	s.Parent = card

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -12, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.Font = isBest and Enum.Font.GothamSemibold or Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(245, 245, 250)
	label.TextXAlignment = Enum.TextXAlignment.Left
	if rank then
		label.Text = string.format("%d. %s", rank, text)
	else
		label.Text = text
	end
	label.Parent = card

	return card
end

local function renderCandidateList(parent: ScrollingFrame, sourceWord: string, candidates: {string}, infoLabel: TextLabel, bestLabelTarget: TextLabel)
	clearList(parent)

	if sourceWord == "" then
		infoLabel.Text = "검색 준비"
		bestLabelTarget.Text = "추천 후보: -"
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 24)
		empty.BackgroundTransparency = 1
		empty.Text = "단어를 입력하거나 현재 단어를 감지하세요."
		empty.TextColor3 = Color3.fromRGB(170, 170, 180)
		empty.TextSize = 12
		empty.Font = Enum.Font.Gotham
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = parent
		updateCanvas(parent, parent:FindFirstChildOfClass("UIListLayout") :: UIListLayout)
		return
	end

	local lastChar = getLastGrapheme(normalizeForIndex(sourceWord))
	if lastChar == "" then
		infoLabel.Text = "분석 불가"
		bestLabelTarget.Text = "추천 후보: -"
		return
	end

	if #candidates == 0 then
		infoLabel.Text = string.format("'%s' → '%s' 후보 없음", sourceWord, lastChar)
		bestLabelTarget.Text = "추천 후보: -"
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 24)
		empty.BackgroundTransparency = 1
		empty.Text = "후보가 없습니다."
		empty.TextColor3 = Color3.fromRGB(170, 170, 180)
		empty.TextSize = 12
		empty.Font = Enum.Font.Gotham
		empty.TextXAlignment = Enum.TextXAlignment.Left
		empty.Parent = parent
		updateCanvas(parent, parent:FindFirstChildOfClass("UIListLayout") :: UIListLayout)
		return
	end

	infoLabel.Text = string.format("'%s' → 끝글자 '%s' 기준 추천", sourceWord, lastChar)
	bestLabelTarget.Text = "추천 후보: " .. table.concat(candidates, ", ")

	for i, word in ipairs(candidates) do
		local key = normalizeForIndex(word)
		local score = candidateScore(key)
		makeResultCard(parent, string.format("%s  ·  점수 %d", word, score), i, i == 1)
	end

	updateCanvas(parent, parent:FindFirstChildOfClass("UIListLayout") :: UIListLayout)
end

local function updateSearchView()
	local query = trim(searchBox.Text)
	local candidates = getSearchMatches(query)
	renderCandidateList(searchResults, query, candidates, searchInfo, bestLabel)
end

local function updateLoadView()
	local word = state.currentWord
	local candidates = getCandidatesFromWord(word)

	if word == "" then
		detectedLabel.Text = "현재 단어: 감지 대기"
	else
		detectedLabel.Text = "현재 단어: " .. word
	end

	if state.detectedSource == "" then
		sourceLabel.Text = "출처: -"
	else
		sourceLabel.Text = "출처: " .. state.detectedSource
	end

	if state.dictionaryLoading then
		loadHeader.Text = "불러오기 상태"
		bestLabel.Text = "추천 후보: 불러오는 중..."
	elseif state.dictionaryLoaded then
		loadHeader.Text = string.format("불러오기 상태  |  단어 %d개", state.totalWords)
	else
		loadHeader.Text = "불러오기 상태"
	end

	renderCandidateList(loadResults, word, candidates, detectedLabel, bestLabel)
end

local function setTab(tabName: "search" | "load")
	state.activeTab = tabName
	searchPage.Visible = (tabName == "search")
	loadPage.Visible = (tabName == "load")

	local function setBtnActive(btn: TextButton, active: boolean)
		if active then
			btn.BackgroundColor3 = Color3.fromRGB(70, 92, 170)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
			btn.TextColor3 = Color3.fromRGB(220, 220, 230)
		end
	end

	setBtnActive(searchTabBtn, tabName == "search")
	setBtnActive(loadTabBtn, tabName == "load")

	if tabName == "search" then
		updateSearchView()
	else
		updateLoadView()
	end
end

searchTabBtn.MouseButton1Click:Connect(function()
	setTab("search")
end)

loadTabBtn.MouseButton1Click:Connect(function()
	setTab("load")
end)

searchBtn.MouseButton1Click:Connect(function()
	setTab("search")
	updateSearchView()
end)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	if state.activeTab == "search" then
		updateSearchView()
	end
end)

refreshBtn.MouseButton1Click:Connect(function()
	loadDictionary()
	updateLoadView()
end)

autoBtn.MouseButton1Click:Connect(function()
	state.autoDetect = not state.autoDetect
	autoBtn.Text = state.autoDetect and "자동감지: ON" or "자동감지: OFF"
	autoBtn.BackgroundColor3 = state.autoDetect and Color3.fromRGB(70, 92, 170) or Color3.fromRGB(104, 82, 82)
end)

closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- 드래그
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

-- 최초 로드
loadDictionary()
setTab("load")

-- 0.1초마다 자동 감지
task.spawn(function()
	while screenGui.Parent do
		if state.autoDetect then
			local word, source = detectCurrentWord()
			if word ~= "" and word ~= state.currentWord then
				state.currentWord = word
				state.detectedSource = source
				if state.activeTab == "load" then
					updateLoadView()
				end
			end
		end
		task.wait(SCAN_INTERVAL)
	end
end)

-- 수동 새로고침용 안전 루프
task.spawn(function()
	while screenGui.Parent do
		if state.activeTab == "search" then
			-- 검색 탭은 입력 반응만 처리
		end
		task.wait(0.5)
	end
end)

-- 로딩 실패 메시지 처리
task.defer(function()
	if not state.dictionaryLoaded and state.dictionaryError ~= "" then
		detectedLabel.Text = "현재 단어: 감지 대기"
		sourceLabel.Text = "출처: word.lua 로드 실패"
		bestLabel.Text = "추천 후보: 로드 실패"
		clearList(loadResults)

		local err = Instance.new("TextLabel")
		err.Size = UDim2.new(1, -4, 0, 40)
		err.BackgroundTransparency = 1
		err.Text = "word.lua 로드 실패: " .. state.dictionaryError
		err.TextWrapped = true
		err.TextColor3 = Color3.fromRGB(255, 140, 140)
		err.TextSize = 12
		err.Font = Enum.Font.Gotham
		err.TextXAlignment = Enum.TextXAlignment.Left
		err.Parent = loadResults
	end
end)
```
