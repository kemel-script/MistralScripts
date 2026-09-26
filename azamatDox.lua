-- LocalScript for Delta Executor (Android / PC)
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local StatsService = game:GetService("Stats")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- =========================================================================
-- 1. THEME CONFIGURATION (Matte Dark & Amber - Modern & Sleek)
-- =========================================================================
local Theme = {
	Accent = Color3.fromRGB(235, 115, 30),           -- Matte Amber Orange
	AccentDark = Color3.fromRGB(180, 85, 20),         -- Deep Amber
	Background = Color3.fromRGB(16, 16, 20),         -- Matte Slate
	BackgroundTransparency = 0.12,
	CardBackground = Color3.fromRGB(24, 24, 30),     -- Titanium Card
	CardTransparency = 0.35,
	BorderColor = Color3.fromRGB(48, 48, 58),        -- Subtle Clean Border
	BorderActive = Color3.fromRGB(210, 105, 30),     -- Active Border
	TextActive = Color3.fromRGB(245, 245, 250),
	TextInactive = Color3.fromRGB(150, 150, 165),
	
	-- ESP Role Colors
	MurdererColor = Color3.fromRGB(235, 55, 55),
	SheriffColor = Color3.fromRGB(55, 130, 240),
	HeroColor = Color3.fromRGB(240, 135, 25),
	InnocentColor = Color3.fromRGB(50, 205, 110),
	CoinColor = Color3.fromRGB(245, 195, 45)
}

local TWEEN_MAIN = TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_FAST = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function IsPlayerAlive(targetPlayer)
	if not targetPlayer or not targetPlayer.Character then return false end
	local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
	local hrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and hum.Health > 0 and hrp ~= nil
end

-- Tactile Press Effect for Mobile & PC
local function AddPressEffect(guiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = guiObject
	end

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.96 }):Play()
		end
	end)

	local function resetScale(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end

	guiObject.InputEnded:Connect(resetScale)
end

-- =========================================================================
-- 2. SAFE SCREEN GUI (Delta Executor Protected Parent)
-- =========================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MistralScripts_MM2"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetParent = playerGui
if gethui then
	targetParent = gethui()
elseif syn and syn.protect_gui then
	pcall(function()
		syn.protect_gui(screenGui)
		targetParent = game:GetService("CoreGui")
	end)
end
screenGui.Parent = targetParent

local tracerFolder = Instance.new("Folder")
tracerFolder.Name = "TracersContainer"
tracerFolder.Parent = screenGui

-- =========================================================================
-- 3. NOTIFICATION SYSTEM
-- =========================================================================
local notifContainer = Instance.new("Frame")
notifContainer.Name = "NotificationContainer"
notifContainer.Size = UDim2.new(0, 260, 0.6, 0)
notifContainer.Position = UDim2.new(1, -20, 0, 40)
notifContainer.AnchorPoint = Vector2.new(1, 0)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 8)
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifLayout.Parent = notifContainer

local function ShowNotification(titleText, descText, roleColor)
	local card = Instance.new("Frame")
	card.Name = "NotificationCard"
	card.Size = UDim2.new(1, 0, 0, 50)
	card.Position = UDim2.new(1, 100, 0, 0)
	card.BackgroundColor3 = Theme.Background
	card.BackgroundTransparency = 0.1
	card.ClipsDescendants = true
	card.Parent = notifContainer

	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = roleColor or Theme.BorderActive
	stroke.Thickness = 1.2
	stroke.Transparency = 0.3
	stroke.Parent = card

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 4, 1, 0)
	bar.BackgroundColor3 = roleColor or Theme.Accent
	bar.BorderSizePixel = 0
	bar.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 18)
	title.Position = UDim2.new(0, 14, 0, 8)
	title.BackgroundTransparency = 1
	title.AutoLocalize = false
	title.Text = titleText
	title.TextColor3 = roleColor or Theme.Accent
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 16)
	desc.Position = UDim2.new(0, 14, 0, 26)
	desc.BackgroundTransparency = 1
	desc.AutoLocalize = false
	desc.Text = descText
	desc.TextColor3 = Theme.TextActive
	desc.Font = Enum.Font.GothamMedium
	desc.TextSize = 12
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = card

	TweenService:Create(card, TWEEN_MAIN, { Position = UDim2.new(0, 0, 0, 0) }):Play()

	task.delay(4, function()
		if card and card.Parent then
			local slideOut = TweenService:Create(card, TWEEN_MAIN, { Position = UDim2.new(1, 100, 0, 0), BackgroundTransparency = 1 })
			slideOut:Play()
			slideOut.Completed:Connect(function() card:Destroy() end)
		end
	end)
end

-- =========================================================================
-- 4. FLOATING BUTTON ("M") - REFINED MATTE DESIGN
-- =========================================================================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(0.92, -15, 0.42, 0)
toggleBtn.BackgroundColor3 = Theme.CardBackground
toggleBtn.BackgroundTransparency = 0.1
toggleBtn.AutoLocalize = false
toggleBtn.Text = "M"
toggleBtn.TextColor3 = Theme.Accent
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 19
toggleBtn.AutoButtonColor = false
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner") toggleCorner.CornerRadius = UDim.new(0, 12) toggleCorner.Parent = toggleBtn
local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Theme.BorderColor
toggleStroke.Thickness = 1.3
toggleStroke.Parent = toggleBtn

AddPressEffect(toggleBtn)

local activeDragInput = nil
local dragStartPos = nil
local frameStartPos = nil
local dragMoved = false

toggleBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if activeDragInput ~= nil then return end

		activeDragInput = input
		dragMoved = false
		dragStartPos = input.Position
		frameStartPos = toggleBtn.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == activeDragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStartPos
		if delta.Magnitude > 6 then
			dragMoved = true
		end
		toggleBtn.Position = UDim2.new(
			frameStartPos.X.Scale,
			frameStartPos.X.Offset + delta.X,
			frameStartPos.Y.Scale,
			frameStartPos.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input == activeDragInput then
		activeDragInput = nil
	end
end)

-- =========================================================================
-- 5. PROXIMITY ALERT BANNER
-- =========================================================================
local warningBanner = Instance.new("Frame")
warningBanner.Name = "MurdererWarning"
warningBanner.Size = UDim2.new(0, 240, 0, 36)
warningBanner.Position = UDim2.new(0.5, 0, 0.08, 0)
warningBanner.AnchorPoint = Vector2.new(0.5, 0)
warningBanner.BackgroundColor3 = Theme.MurdererColor
warningBanner.BackgroundTransparency = 0.2
warningBanner.Visible = false
warningBanner.Parent = screenGui

local wbCorner = Instance.new("UICorner") wbCorner.CornerRadius = UDim.new(0, 8) wbCorner.Parent = warningBanner
local wbStroke = Instance.new("UIStroke") wbStroke.Color = Color3.fromRGB(255, 120, 120) wbStroke.Thickness = 1.2 wbStroke.Parent = warningBanner

local warningText = Instance.new("TextLabel")
warningText.Size = UDim2.new(1, 0, 1, 0)
warningText.BackgroundTransparency = 1
warningText.AutoLocalize = false
warningText.Text = "⚠️ MURDERER NEARBY: 0m ⚠️"
warningText.TextColor3 = Color3.fromRGB(255, 255, 255)
warningText.Font = Enum.Font.GothamBold
warningText.TextSize = 13
warningText.Parent = warningBanner

-- =========================================================================
-- 6. MAIN WINDOW
-- =========================================================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.55, 0, 0.78, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Theme.Background
mainFrame.BackgroundTransparency = Theme.BackgroundTransparency
mainFrame.ClipsDescendants = true
mainFrame.Visible = false
mainFrame.Parent = screenGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(460, 290)
sizeConstraint.MaxSize = Vector2.new(780, 480)
sizeConstraint.Parent = mainFrame

local mainCorner = Instance.new("UICorner") mainCorner.CornerRadius = UDim.new(0, 14) mainCorner.Parent = mainFrame
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Theme.BorderColor
mainStroke.Thickness = 1.2
mainStroke.Parent = mainFrame

-- =========================================================================
-- 7. TOP BAR
-- =========================================================================
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 54)
topBar.BackgroundTransparency = 1
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(0, 180, 0, 20)
titleLabel.Position = UDim2.new(0, 18, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.AutoLocalize = false
titleLabel.Text = "MistralScripts"
titleLabel.TextColor3 = Theme.Accent
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local authorLabel = Instance.new("TextLabel")
authorLabel.Name = "Author"
authorLabel.Size = UDim2.new(0, 180, 0, 16)
authorLabel.Position = UDim2.new(0, 18, 0, 30)
authorLabel.BackgroundTransparency = 1
authorLabel.AutoLocalize = false
authorLabel.Text = "By kemel"
authorLabel.TextColor3 = Theme.TextInactive
authorLabel.Font = Enum.Font.Gotham
authorLabel.TextSize = 12
authorLabel.TextXAlignment = Enum.TextXAlignment.Left
authorLabel.Parent = topBar

local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "Version"
versionLabel.Size = UDim2.new(0, 70, 0, 20)
versionLabel.Position = UDim2.new(1, -110, 0, 17)
versionLabel.BackgroundTransparency = 1
versionLabel.AutoLocalize = false
versionLabel.Text = "v1.8.1"
versionLabel.TextColor3 = Theme.TextInactive
versionLabel.Font = Enum.Font.GothamMedium
versionLabel.TextSize = 12
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 13)
closeBtn.BackgroundTransparency = 1
closeBtn.AutoLocalize = false
closeBtn.Text = "✕"
closeBtn.TextColor3 = Theme.TextInactive
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = topBar
AddPressEffect(closeBtn)

-- =========================================================================
-- 8. SIDEBAR
-- =========================================================================
local sidebar = Instance.new("ScrollingFrame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 140, 1, -64)
sidebar.Position = UDim2.new(0, 8, 0, 54)
sidebar.BackgroundTransparency = 1
sidebar.BorderSizePixel = 0
sidebar.ScrollBarThickness = 2
sidebar.ScrollBarImageColor3 = Theme.BorderColor
sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.Parent = mainFrame

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 4)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Parent = sidebar

local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingLeft = UDim.new(0, 4)
sidebarPadding.PaddingRight = UDim.new(0, 4)
sidebarPadding.Parent = sidebar

-- =========================================================================
-- 9. CONTENT CONTAINER
-- =========================================================================
local contentWrapper = Instance.new("Frame")
contentWrapper.Name = "ContentWrapper"
contentWrapper.Size = UDim2.new(1, -162, 1, -66)
contentWrapper.Position = UDim2.new(0, 152, 0, 54)
contentWrapper.BackgroundColor3 = Theme.CardBackground
contentWrapper.BackgroundTransparency = Theme.CardTransparency
contentWrapper.Parent = mainFrame

local wrapperCorner = Instance.new("UICorner") wrapperCorner.CornerRadius = UDim.new(0, 12) wrapperCorner.Parent = contentWrapper
local wrapperStroke = Instance.new("UIStroke")
wrapperStroke.Color = Theme.BorderColor
wrapperStroke.Thickness = 1
wrapperStroke.Parent = contentWrapper

local contentArea = Instance.new("Frame")
contentArea.Name = "PagesArea"
contentArea.Size = UDim2.new(1, 0, 1, 0)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.Parent = contentWrapper

-- =========================================================================
-- 10. CATEGORIES SETUP & SLIDE TRANSITIONS
-- =========================================================================
local categories = {
	{ Name = "Home", Icon = "rbxassetid://6031075938" },
	{ Name = "Movement", Icon = "rbxassetid://6034440078" },
	{ Name = "Combat", Icon = "rbxassetid://6031265976" },
	{ Name = "Visuals", Icon = "rbxassetid://6031225882" },
	{ Name = "Auto Farm", Icon = "rbxassetid://6031280882" },
	{ Name = "Teleports", Icon = "rbxassetid://6035193042" },
	{ Name = "Troll", Icon = "rbxassetid://6034767608" },
	{ Name = "Misc", Icon = "rbxassetid://6034509993" },
	{ Name = "Settings", Icon = "rbxassetid://6031280886" }
}

local categoryButtons = {}
local categoryPages = {}
local currentlyActivePage = nil

for index, catData in ipairs(categories) do
	local btn = Instance.new("TextButton")
	btn.Name = catData.Name .. "Btn"
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = Theme.Accent
	btn.BackgroundTransparency = 1
	btn.AutoLocalize = false
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = sidebar

	local btnCorner = Instance.new("UICorner") btnCorner.CornerRadius = UDim.new(0, 8) btnCorner.Parent = btn

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.Position = UDim2.new(0, 8, 0.5, -8)
	icon.BackgroundTransparency = 1
	icon.Image = catData.Icon
	icon.ImageColor3 = Theme.TextInactive
	icon.Parent = btn

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -34, 1, 0)
	label.Position = UDim2.new(0, 32, 0, 0)
	label.BackgroundTransparency = 1
	label.AutoLocalize = false
	label.Text = catData.Name
	label.TextColor3 = Theme.TextInactive
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = btn

	AddPressEffect(btn)

	local page = Instance.new("ScrollingFrame")
	page.Name = catData.Name .. "Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.Position = UDim2.new(0, 0, 0, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.BorderColor
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = contentArea

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.Padding = UDim.new(0, 8)
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Parent = page

	local pagePadding = Instance.new("UIPadding")
	pagePadding.PaddingTop = UDim.new(0, 10)
	pagePadding.PaddingBottom = UDim.new(0, 10)
	pagePadding.PaddingLeft = UDim.new(0, 10)
	pagePadding.PaddingRight = UDim.new(0, 10)
	pagePadding.Parent = page

	categoryButtons[btn] = { Page = page, Icon = icon, Label = label }
	categoryPages[index] = { Button = btn, Page = page, Icon = icon, Label = label }

	btn.MouseButton1Click:Connect(function()
		if currentlyActivePage == page then return end
		currentlyActivePage = page

		for b, items in pairs(categoryButtons) do
			if b == btn then
				TweenService:Create(b, TWEEN_FAST, { BackgroundTransparency = 0.8, BackgroundColor3 = Theme.Accent }):Play()
				TweenService:Create(items.Icon, TWEEN_FAST, { ImageColor3 = Theme.TextActive }):Play()
				TweenService:Create(items.Label, TWEEN_FAST, { TextColor3 = Theme.TextActive }):Play()

				items.Page.Position = UDim2.new(0, 0, 0, 8)
				items.Page.Visible = true
				TweenService:Create(items.Page, TWEEN_MAIN, { Position = UDim2.new(0, 0, 0, 0) }):Play()
			else
				TweenService:Create(b, TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
				TweenService:Create(items.Icon, TWEEN_FAST, { ImageColor3 = Theme.TextInactive }):Play()
				TweenService:Create(items.Label, TWEEN_FAST, { TextColor3 = Theme.TextInactive }):Play()
				items.Page.Visible = false
			end
		end
	end)
end

-- =========================================================================
-- 11. REUSABLE UI BUILDER HELPERS (With Accordion/Collapsible Folders)
-- =========================================================================
local activeGlobalSlider = nil
local activeSliderTouch = nil

-- Collapsible Section / Accordion Generator
local function CreateCollapsibleFolder(parent, folderName, iconAsset)
	local folderCard = Instance.new("Frame")
	folderCard.Name = folderName .. "Folder"
	folderCard.Size = UDim2.new(1, 0, 0, 44)
	folderCard.BackgroundColor3 = Theme.CardBackground
	folderCard.BackgroundTransparency = 0.5
	folderCard.ClipsDescendants = true
	folderCard.Parent = parent

	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 10) fc.Parent = folderCard
	local fStroke = Instance.new("UIStroke")
	fStroke.Color = Theme.BorderColor
	fStroke.Thickness = 1.1
	fStroke.Parent = folderCard

	local headerBtn = Instance.new("TextButton")
	headerBtn.Name = "HeaderButton"
	headerBtn.Size = UDim2.new(1, 0, 0, 44)
	headerBtn.BackgroundTransparency = 1
	headerBtn.AutoLocalize = false
	headerBtn.Text = ""
	headerBtn.Parent = folderCard
	AddPressEffect(headerBtn)

	local iconImg = Instance.new("ImageLabel")
	iconImg.Size = UDim2.new(0, 18, 0, 18)
	iconImg.Position = UDim2.new(0, 12, 0.5, -9)
	iconImg.BackgroundTransparency = 1
	iconImg.Image = iconAsset or "rbxassetid://6034767608"
	iconImg.ImageColor3 = Theme.Accent
	iconImg.Parent = headerBtn

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.7, 0, 1, 0)
	title.Position = UDim2.new(0, 36, 0, 0)
	title.BackgroundTransparency = 1
	title.AutoLocalize = false
	title.Text = folderName
	title.TextColor3 = Theme.TextActive
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = headerBtn

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(0, 30, 0, 30)
	arrow.Position = UDim2.new(1, -38, 0.5, -15)
	arrow.BackgroundTransparency = 1
	arrow.AutoLocalize = false
	arrow.Text = "▶"
	arrow.TextColor3 = Theme.TextInactive
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 12
	arrow.Parent = headerBtn

	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, -16, 0, 0)
	contentContainer.Position = UDim2.new(0, 8, 0, 46)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = folderCard

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 6)
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Parent = contentContainer

	local isExpanded = false

	headerBtn.MouseButton1Click:Connect(function()
		isExpanded = not isExpanded
		local targetArrowRot = isExpanded and 90 or 0
		local targetCardHeight = isExpanded and (contentLayout.AbsoluteContentSize.Y + 54) or 44

		TweenService:Create(arrow, TWEEN_FAST, { Rotation = targetArrowRot }):Play()
		TweenService:Create(folderCard, TWEEN_MAIN, { Size = UDim2.new(1, 0, 0, targetCardHeight) }):Play()
	end)

	-- Update height dynamically when children inside change
	contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if isExpanded then
			local newHeight = contentLayout.AbsoluteContentSize.Y + 54
			folderCard.Size = UDim2.new(1, 0, 0, newHeight)
		end
	end)

	return contentContainer
end

local function CreateToggleSwitch(parent, name, desc, defaultState, callback)
	local card = Instance.new("Frame")
	card.Name = name .. "Card"
	card.Size = UDim2.new(1, 0, 0, 48)
	card.BackgroundColor3 = Theme.CardBackground
	card.BackgroundTransparency = 0.5
	card.Parent = parent

	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.7, 0, 0, 18)
	title.Position = UDim2.new(0, 12, 0, 6)
	title.BackgroundTransparency = 1
	title.AutoLocalize = false
	title.Text = name
	title.TextColor3 = Theme.TextActive
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local description = Instance.new("TextLabel")
	description.Size = UDim2.new(0.7, 0, 0, 16)
	description.Position = UDim2.new(0, 12, 0, 24)
	description.BackgroundTransparency = 1
	description.AutoLocalize = false
	description.Text = desc
	description.TextColor3 = Theme.TextInactive
	description.Font = Enum.Font.Gotham
	description.TextSize = 10
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.Parent = card

	local tBtn = Instance.new("TextButton")
	tBtn.Size = UDim2.new(0, 40, 0, 22)
	tBtn.Position = UDim2.new(1, -52, 0.5, -11)
	tBtn.BackgroundColor3 = defaultState and Theme.Accent or Color3.fromRGB(42, 42, 50)
	tBtn.Text = ""
	tBtn.AutoButtonColor = false
	tBtn.Parent = card

	local tCorner = Instance.new("UICorner") tCorner.CornerRadius = UDim.new(1, 0) tCorner.Parent = tBtn

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 16, 0, 16)
	dot.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
	dot.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
	dot.BorderSizePixel = 0
	dot.Parent = tBtn

	local dotCorner = Instance.new("UICorner") dotCorner.CornerRadius = UDim.new(1, 0) dotCorner.Parent = dot
	AddPressEffect(tBtn)

	local state = defaultState

	tBtn.MouseButton1Click:Connect(function()
		state = not state
		local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
		local targetColor = state and Theme.Accent or Color3.fromRGB(42, 42, 50)

		TweenService:Create(dot, TWEEN_FAST, { Position = targetPos }):Play()
		TweenService:Create(tBtn, TWEEN_FAST, { BackgroundColor3 = targetColor }):Play()

		callback(state)
	end)

	local control = {}
	function control:Set(newState)
		state = newState
		local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
		local targetColor = state and Theme.Accent or Color3.fromRGB(42, 42, 50)
		dot.Position = targetPos
		tBtn.BackgroundColor3 = targetColor
		callback(state)
	end
	return control
end

local function addSliderCard(parent, name, minVal, maxVal, defaultVal, callback)
	local card = Instance.new("Frame")
	card.Name = name .. "SliderCard"
	card.Size = UDim2.new(1, 0, 0, 60)
	card.BackgroundColor3 = Theme.CardBackground
	card.BackgroundTransparency = 0.5
	card.ClipsDescendants = false
	card.Parent = parent

	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.65, 0, 0, 20)
	title.Position = UDim2.new(0, 14, 0, 8)
	title.BackgroundTransparency = 1
	title.AutoLocalize = false
	title.Text = name
	title.TextColor3 = Theme.TextActive
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local valBadge = Instance.new("Frame")
	valBadge.Name = "ValueBadge"
	valBadge.Size = UDim2.new(0, 50, 0, 20)
	valBadge.Position = UDim2.new(1, -64, 0, 8)
	valBadge.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	valBadge.BackgroundTransparency = 0.3
	valBadge.Parent = card

	local vbCorner = Instance.new("UICorner") vbCorner.CornerRadius = UDim.new(0, 6) vbCorner.Parent = valBadge
	local vbStroke = Instance.new("UIStroke")
	vbStroke.Color = Theme.BorderColor
	vbStroke.Thickness = 1.1
	vbStroke.Parent = valBadge

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, 0, 1, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.AutoLocalize = false
	valLabel.Text = tostring(defaultVal)
	valLabel.TextColor3 = Theme.Accent
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 12
	valLabel.TextXAlignment = Enum.TextXAlignment.Center
	valLabel.Parent = valBadge

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, -28, 0, 6)
	bar.Position = UDim2.new(0, 14, 0, 42)
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	bar.Parent = card
	local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(1, 0) bc.Parent = bar

	local initScale = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(initScale, 0, 1, 0)
	fill.BackgroundColor3 = Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(1, -8, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	knob.BorderSizePixel = 0
	knob.ZIndex = 5
	knob.Parent = fill

	local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob
	local ks = Instance.new("UIStroke")
	ks.Color = Theme.BorderColor
	ks.Thickness = 1.4
	ks.Parent = knob

	local bubble = Instance.new("Frame")
	bubble.Name = "FloatingBubble"
	bubble.Size = UDim2.new(0, 36, 0, 22)
	bubble.Position = UDim2.new(0.5, -18, 0, -28)
	bubble.BackgroundColor3 = Theme.Background
	bubble.BackgroundTransparency = 0.1
	bubble.Visible = false
	bubble.ZIndex = 10
	bubble.Parent = knob

	local bCorner = Instance.new("UICorner") bCorner.CornerRadius = UDim.new(0, 6) bCorner.Parent = bubble
	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Theme.BorderColor
	bStroke.Thickness = 1
	bStroke.Parent = bubble

	local bubbleText = Instance.new("TextLabel")
	bubbleText.Size = UDim2.new(1, 0, 1, 0)
	bubbleText.BackgroundTransparency = 1
	bubbleText.AutoLocalize = false
	bubbleText.Text = tostring(defaultVal)
	bubbleText.TextColor3 = Theme.TextActive
	bubbleText.Font = Enum.Font.GothamBold
	bubbleText.TextSize = 11
	bubbleText.ZIndex = 11
	bubbleText.Parent = bubble

	local currentValue = defaultVal

	local function updateSlide(input)
		local barPos = bar.AbsolutePosition.X
		local barSize = bar.AbsoluteSize.X
		local moveX = math.clamp(input.Position.X - barPos, 0, barSize)
		local pct = moveX / barSize
		local value = math.floor(minVal + (maxVal - minVal) * pct)

		if value ~= currentValue then
			currentValue = value
			fill.Size = UDim2.new(pct, 0, 1, 0)
			valLabel.Text = tostring(value)
			bubbleText.Text = tostring(value)
			if callback then callback(value) end
		end
	end

	local function startSlide(input)
		if activeGlobalSlider ~= nil and activeGlobalSlider ~= card then return end
		if activeSliderTouch ~= nil and activeSliderTouch ~= input then return end

		activeGlobalSlider = card
		activeSliderTouch = input

		local parentScroll = parent
		while parentScroll and not parentScroll:IsA("ScrollingFrame") do
			parentScroll = parentScroll.Parent
		end
		if parentScroll then parentScroll.ScrollingEnabled = false end

		bubble.Visible = true
		updateSlide(input)
	end

	local function endSlide(input)
		if activeSliderTouch == input and activeGlobalSlider == card then
			activeSliderTouch = nil
			activeGlobalSlider = nil

			local parentScroll = parent
			while parentScroll and not parentScroll:IsA("ScrollingFrame") do
				parentScroll = parentScroll.Parent
			end
			if parentScroll then parentScroll.ScrollingEnabled = true end

			bubble.Visible = false
		end
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startSlide(input)
		end
	end)

	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local deltaY = input.Position.Y - bar.AbsolutePosition.Y
			if math.abs(deltaY) <= 20 then
				startSlide(input)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if activeGlobalSlider == card and activeSliderTouch == input then
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				updateSlide(input)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			endSlide(input)
		end
	end)

	local control = {}
	function control:Set(newVal)
		local clamped = math.clamp(newVal, minVal, maxVal)
		currentValue = clamped
		local pct = (clamped - minVal) / (maxVal - minVal)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		valLabel.Text = tostring(clamped)
		bubbleText.Text = tostring(clamped)
		if callback then callback(clamped) end
	end
	function control:Get()
		return currentValue
	end
	return control
end

local function CreateActionButton(parent, name, desc, btnText, callback)
	local card = Instance.new("Frame")
	card.Name = name .. "BtnCard"
	card.Size = UDim2.new(1, 0, 0, 48)
	card.BackgroundColor3 = Theme.CardBackground
	card.BackgroundTransparency = 0.5
	card.Parent = parent

	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.65, 0, 0, 18)
	title.Position = UDim2.new(0, 12, 0, 6)
	title.BackgroundTransparency = 1
	title.AutoLocalize = false
	title.Text = name
	title.TextColor3 = Theme.TextActive
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local description = Instance.new("TextLabel")
	description.Size = UDim2.new(0.65, 0, 0, 16)
	description.Position = UDim2.new(0, 12, 0, 24)
	description.BackgroundTransparency = 1
	description.AutoLocalize = false
	description.Text = desc
	description.TextColor3 = Theme.TextInactive
	description.Font = Enum.Font.Gotham
	description.TextSize = 10
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.Parent = card

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 84, 0, 26)
	btn.Position = UDim2.new(1, -94, 0.5, -13)
	btn.BackgroundColor3 = Theme.Accent
	btn.AutoLocalize = false
	btn.Text = btnText
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Parent = card

	local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 8) bc.Parent = btn
	AddPressEffect(btn)

	btn.MouseButton1Click:Connect(function()
		task.spawn(callback)
	end)
end

-- =========================================================================
-- 12. POPULATE "HOME" (PAGE 1)
-- =========================================================================
local homePage = categoryPages[1].Page

local profileCard = Instance.new("Frame")
profileCard.Size = UDim2.new(1, 0, 0, 56)
profileCard.BackgroundColor3 = Theme.CardBackground
profileCard.BackgroundTransparency = 0.5
profileCard.Parent = homePage
local pCorner = Instance.new("UICorner") pCorner.CornerRadius = UDim.new(0, 10) pCorner.Parent = profileCard

local avatarImg = Instance.new("ImageLabel")
avatarImg.Size = UDim2.new(0, 40, 0, 40)
avatarImg.Position = UDim2.new(0, 8, 0.5, -20)
avatarImg.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
avatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
avatarImg.Parent = profileCard
local avc = Instance.new("UICorner") avc.CornerRadius = UDim.new(1, 0) avc.Parent = avatarImg

local welcomeText = Instance.new("TextLabel")
welcomeText.Size = UDim2.new(0.6, 0, 0, 18)
welcomeText.Position = UDim2.new(0, 56, 0, 10)
welcomeText.BackgroundTransparency = 1
welcomeText.AutoLocalize = false
welcomeText.Text = "Welcome, " .. player.DisplayName
welcomeText.TextColor3 = Theme.TextActive
welcomeText.Font = Enum.Font.GothamBold
welcomeText.TextSize = 13
welcomeText.TextXAlignment = Enum.TextXAlignment.Left
welcomeText.Parent = profileCard

local userRank = Instance.new("TextLabel")
userRank.Size = UDim2.new(0.6, 0, 0, 16)
userRank.Position = UDim2.new(0, 56, 0, 28)
userRank.BackgroundTransparency = 1
userRank.AutoLocalize = false
userRank.Text = "@" .. player.Name .. " • Free User"
userRank.TextColor3 = Theme.TextInactive
userRank.Font = Enum.Font.Gotham
userRank.TextSize = 11
userRank.TextXAlignment = Enum.TextXAlignment.Left
userRank.Parent = profileCard

local statsContainer = Instance.new("Frame")
statsContainer.Size = UDim2.new(1, 0, 0, 46)
statsContainer.BackgroundTransparency = 1
statsContainer.Parent = homePage

local statsLayout = Instance.new("UIGridLayout")
statsLayout.CellSize = UDim2.new(0.485, 0, 1, 0)
statsLayout.CellPadding = UDim2.new(0.03, 0, 0, 0)
statsLayout.Parent = statsContainer

local fpsCard = Instance.new("Frame")
fpsCard.BackgroundColor3 = Theme.CardBackground
fpsCard.BackgroundTransparency = 0.5
fpsCard.Parent = statsContainer
local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = fpsCard

local fpsTitle = Instance.new("TextLabel")
fpsTitle.Size = UDim2.new(1, -10, 0, 14)
fpsTitle.Position = UDim2.new(0, 8, 0, 6)
fpsTitle.BackgroundTransparency = 1
fpsTitle.AutoLocalize = false
fpsTitle.Text = "FPS"
fpsTitle.TextColor3 = Theme.TextInactive
fpsTitle.Font = Enum.Font.GothamMedium
fpsTitle.TextSize = 10
fpsTitle.TextXAlignment = Enum.TextXAlignment.Left
fpsTitle.Parent = fpsCard

local fpsValue = Instance.new("TextLabel")
fpsValue.Size = UDim2.new(1, -10, 0, 18)
fpsValue.Position = UDim2.new(0, 8, 0, 20)
fpsValue.BackgroundTransparency = 1
fpsValue.AutoLocalize = false
fpsValue.Text = "60"
fpsValue.TextColor3 = Color3.fromRGB(80, 220, 125)
fpsValue.Font = Enum.Font.GothamBold
fpsValue.TextSize = 14
fpsValue.TextXAlignment = Enum.TextXAlignment.Left
fpsValue.Parent = fpsCard

local pingCard = Instance.new("Frame")
pingCard.BackgroundColor3 = Theme.CardBackground
pingCard.BackgroundTransparency = 0.5
pingCard.Parent = statsContainer
local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 8) pc.Parent = pingCard

local pingTitle = Instance.new("TextLabel")
pingTitle.Size = UDim2.new(1, -10, 0, 14)
pingTitle.Position = UDim2.new(0, 8, 0, 6)
pingTitle.BackgroundTransparency = 1
pingTitle.AutoLocalize = false
pingTitle.Text = "Ping"
pingTitle.TextColor3 = Theme.TextInactive
pingTitle.Font = Enum.Font.GothamMedium
pingTitle.TextSize = 10
pingTitle.TextXAlignment = Enum.TextXAlignment.Left
pingTitle.Parent = pingCard

local pingValue = Instance.new("TextLabel")
pingValue.Size = UDim2.new(1, -10, 0, 18)
pingValue.Position = UDim2.new(0, 8, 0, 20)
pingValue.BackgroundTransparency = 1
pingValue.AutoLocalize = false
pingValue.Text = "..."
pingValue.TextColor3 = Color3.fromRGB(80, 220, 125)
pingValue.Font = Enum.Font.GothamBold
pingValue.TextSize = 14
pingValue.TextXAlignment = Enum.TextXAlignment.Left
pingValue.Parent = pingCard

local tgCard = Instance.new("Frame")
tgCard.Size = UDim2.new(1, 0, 0, 48)
tgCard.BackgroundColor3 = Theme.CardBackground
tgCard.BackgroundTransparency = 0.5
tgCard.Parent = homePage
local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 10) tc.Parent = tgCard

local tgTitle = Instance.new("TextLabel")
tgTitle.Size = UDim2.new(0.65, 0, 0, 16)
tgTitle.Position = UDim2.new(0, 12, 0, 7)
tgTitle.BackgroundTransparency = 1
tgTitle.AutoLocalize = false
tgTitle.Text = "Join Telegram Channel"
tgTitle.TextColor3 = Theme.TextActive
tgTitle.Font = Enum.Font.GothamBold
tgTitle.TextSize = 12
tgTitle.TextXAlignment = Enum.TextXAlignment.Left
tgTitle.Parent = tgCard

local tgDesc = Instance.new("TextLabel")
tgDesc.Size = UDim2.new(0.65, 0, 0, 14)
tgDesc.Position = UDim2.new(0, 12, 0, 24)
tgDesc.BackgroundTransparency = 1
tgDesc.AutoLocalize = false
tgDesc.Text = "t.me/MistralScripts • Updates"
tgDesc.TextColor3 = Theme.TextInactive
tgDesc.Font = Enum.Font.Gotham
tgDesc.TextSize = 10
tgDesc.TextXAlignment = Enum.TextXAlignment.Left
tgDesc.Parent = tgCard

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0, 80, 0, 26)
copyBtn.Position = UDim2.new(1, -90, 0.5, -13)
copyBtn.BackgroundColor3 = Theme.Accent
copyBtn.AutoLocalize = false
copyBtn.Text = "Copy Link"
copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 11
copyBtn.Parent = tgCard
local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0, 8) cbc.Parent = copyBtn
AddPressEffect(copyBtn)

copyBtn.MouseButton1Click:Connect(function()
	if setclipboard then
		setclipboard("https://t.me/MistralScripts")
	elseif toclipboard then
		toclipboard("https://t.me/MistralScripts")
	end
	copyBtn.Text = "Copied!"
	task.wait(1.5)
	copyBtn.Text = "Copy Link"
end)

-- =========================================================================
-- 13. MOVEMENT SYSTEM (PAGE 2)
-- =========================================================================
local movementPage = categoryPages[2].Page

local defaultWalkSpeed = 16
local defaultJumpPower = 50
local defaultGravity = 196.2

local currentWalkSpeed = defaultWalkSpeed
local currentJumpPower = defaultJumpPower
local flySpeed = 50

local isWalkSpeedEnabled = false
local isJumpPowerEnabled = false
local isInfJumpEnabled = false
local isNoclipEnabled = false
local isSpeedHackEnabled = false
local isAntiFlingEnabled = false
local isFlyEnabled = false
local isSpinBotEnabled = false
local isAntiVoidEnabled = false
local isBunnyHopEnabled = false
local isAutoJumpEnabled = false
local isLongJumpEnabled = false

local flyBodyVelocity = nil
local flyBodyGyro = nil
local lastSafePosition = nil

local walkSpeedSliderControl
local jumpPowerSliderControl
local gravitySliderControl
local speedBoostToggleControl

local function UpdateFlyState(state)
	isFlyEnabled = state
	if state then
		if not IsPlayerAlive(player) then return end
		local hrp = player.Character.HumanoidRootPart

		flyBodyVelocity = Instance.new("BodyVelocity")
		flyBodyVelocity.Name = "MM2_FlyVel"
		flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		flyBodyVelocity.Velocity = Vector3.zero
		flyBodyVelocity.Parent = hrp

		flyBodyGyro = Instance.new("BodyGyro")
		flyBodyGyro.Name = "MM2_FlyGyro"
		flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
		flyBodyGyro.CFrame = hrp.CFrame
		flyBodyGyro.Parent = hrp
	else
		if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
		if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
	end
end

UserInputService.JumpRequest:Connect(function()
	if isInfJumpEnabled and IsPlayerAlive(player) then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

local function SetupLongJump(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		hum.Jumping:Connect(function(isActive)
			if isActive and isLongJumpEnabled and char:FindFirstChild("HumanoidRootPart") then
				local hrp = char.HumanoidRootPart
				hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + (hrp.CFrame.LookVector * 45)
			end
		end)
	end
end

if player.Character then SetupLongJump(player.Character) end
player.CharacterAdded:Connect(SetupLongJump)

RunService.Stepped:Connect(function()
	if isNoclipEnabled and player.Character then
		for _, part in ipairs(player.Character:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end

	if isAntiFlingEnabled and IsPlayerAlive(player) then
		local hrp = player.Character.HumanoidRootPart
		if hrp.AssemblyAngularVelocity.Magnitude > 100 then
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
		if hrp.AssemblyLinearVelocity.Magnitude > 250 then
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not IsPlayerAlive(player) then return end
	local char = player.Character
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if isWalkSpeedEnabled and hum then
		hum.WalkSpeed = currentWalkSpeed
	end
	if isJumpPowerEnabled and hum then
		hum.UseJumpPower = true
		hum.JumpPower = currentJumpPower
	end

	if isSpeedHackEnabled and hum and hrp and hum.MoveDirection.Magnitude > 0 then
		hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (dt * 26))
	end

	if isSpinBotEnabled and hrp then
		hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(28), 0)
	end

	if (isBunnyHopEnabled or isAutoJumpEnabled) and hum then
		if hum.FloorMaterial ~= Enum.Material.Air then
			if isAutoJumpEnabled or (isBunnyHopEnabled and hum.MoveDirection.Magnitude > 0) then
				hum:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	end

	if isAntiVoidEnabled and hrp and hum then
		if hum.FloorMaterial ~= Enum.Material.Air then
			lastSafePosition = hrp.Position
		end
		if hrp.Position.Y < -45 and lastSafePosition then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(lastSafePosition + Vector3.new(0, 6, 0))
		end
	end

	if isFlyEnabled and flyBodyVelocity and flyBodyGyro and hrp and hum then
		flyBodyGyro.CFrame = camera.CFrame
		local moveDir = hum.MoveDirection
		if moveDir.Magnitude > 0 then
			local camLook = camera.CFrame.LookVector
			flyBodyVelocity.Velocity = (camLook * flySpeed)
		else
			flyBodyVelocity.Velocity = Vector3.zero
		end
	end
end)

player.CharacterAdded:Connect(function()
	if isFlyEnabled then
		task.wait(0.2)
		UpdateFlyState(true)
	end
end)

walkSpeedSliderControl = addSliderCard(movementPage, "WalkSpeed", 1, 200, 16, function(val)
	currentWalkSpeed = val
	isWalkSpeedEnabled = (val ~= defaultWalkSpeed)
	if IsPlayerAlive(player) then player.Character.Humanoid.WalkSpeed = val end
end)

jumpPowerSliderControl = addSliderCard(movementPage, "JumpPower", 1, 200, 50, function(val)
	currentJumpPower = val
	isJumpPowerEnabled = (val ~= defaultJumpPower)
	if IsPlayerAlive(player) then
		player.Character.Humanoid.UseJumpPower = true
		player.Character.Humanoid.JumpPower = val
	end
end)

CreateToggleSwitch(movementPage, "Fly Mode", "Fly in direction of camera (Mobile Thumbstick Support)", false, function(v)
	UpdateFlyState(v)
end)

addSliderCard(movementPage, "Fly Speed", 10, 200, 50, function(val)
	flySpeed = val
end)

CreateToggleSwitch(movementPage, "Noclip", "Walk freely through walls and doors", false, function(v)
	isNoclipEnabled = v
end)

CreateToggleSwitch(movementPage, "Infinite Jump", "Jump infinitely in mid-air", false, function(v)
	isInfJumpEnabled = v
end)

speedBoostToggleControl = CreateToggleSwitch(movementPage, "Speed Boost", "Quick sprint acceleration toggle (38 WalkSpeed)", false, function(v)
	if v then
		isWalkSpeedEnabled = true
		currentWalkSpeed = 38
		if IsPlayerAlive(player) then player.Character.Humanoid.WalkSpeed = 38 end
	else
		currentWalkSpeed = defaultWalkSpeed
		isWalkSpeedEnabled = false
		if IsPlayerAlive(player) then player.Character.Humanoid.WalkSpeed = defaultWalkSpeed end
	end
end)

CreateToggleSwitch(movementPage, "CFrame Speed Hack", "Direct coordinate shift bypassing in-game slow-downs", false, function(v)
	isSpeedHackEnabled = v
end)

CreateToggleSwitch(movementPage, "Bunny Hop (Bhop)", "Automatically hops on contact with floor", false, function(v)
	isBunnyHopEnabled = v
end)

CreateToggleSwitch(movementPage, "Auto Jump", "Continuously jumps without stop", false, function(v)
	isAutoJumpEnabled = v
end)

CreateToggleSwitch(movementPage, "Long Jump", "Increases forward launch velocity when jumping", false, function(v)
	isLongJumpEnabled = v
end)

CreateToggleSwitch(movementPage, "Anti-Fling", "Prevents getting flung or pushed by players", false, function(v)
	isAntiFlingEnabled = v
end)

CreateToggleSwitch(movementPage, "Anti-Void", "Teleports you back if falling beneath the map", false, function(v)
	isAntiVoidEnabled = v
end)

CreateToggleSwitch(movementPage, "Spin Bot", "Rapidly spins character to confuse murderer/sheriff", false, function(v)
	isSpinBotEnabled = v
end)

gravitySliderControl = addSliderCard(movementPage, "Gravity", 0, 196, 196, function(val)
	workspace.Gravity = val
end)

CreateActionButton(movementPage, "Restore Defaults", "Resets speed, jump, gravity & states to normal", "Reset", function()
	isWalkSpeedEnabled = false
	isJumpPowerEnabled = false
	isSpeedHackEnabled = false
	isInfJumpEnabled = false
	isNoclipEnabled = false
	isSpinBotEnabled = false
	isBunnyHopEnabled = false
	isAutoJumpEnabled = false
	isLongJumpEnabled = false
	UpdateFlyState(false)

	walkSpeedSliderControl:Set(16)
	jumpPowerSliderControl:Set(50)
	gravitySliderControl:Set(196)
	speedBoostToggleControl:Set(false)

	workspace.Gravity = defaultGravity
	if IsPlayerAlive(player) then
		local hum = player.Character.Humanoid
		hum.WalkSpeed = defaultWalkSpeed
		hum.JumpPower = defaultJumpPower
	end
	ShowNotification("Movement", "Default values restored!", Theme.Accent)
end)

-- =========================================================================
-- 14. VISUALS SYSTEM (PAGE 4)
-- =========================================================================
local visualsPage = categoryPages[4].Page

local cachedServerRoles = {}
local activeMurderer = nil
local activeSheriff = nil
local activeHero = nil

local isChamsEnabled = false
local isTagsEnabled = false
local isTracersEnabled = false

local chamsHighlights = {}
local playerTags = {}
local lineObjects = {}

local function FetchServerRoles()
	local rf = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
	if rf and rf:IsA("RemoteFunction") then
		local success, result = pcall(function() return rf:InvokeServer() end)
		if success and type(result) == "table" then
			for pName, data in pairs(result) do
				if type(data) == "table" and data.Role then
					cachedServerRoles[tostring(pName)] = data.Role
				end
			end
			return true
		end
	end
	return false
end

local function CheckTool(item)
	if not item or not item:IsA("Tool") then return nil end
	local n = item.Name:lower()
	if n:find("knife") or n == "knife" then return "Murderer"
	elseif n:find("gun") or n:find("revolver") or n == "gun" then return "Gun" end
	return nil
end

local function GetPlayerRole(targetPlayer)
	if not IsPlayerAlive(targetPlayer) then
		return "Innocent", Theme.InnocentColor
	end

	local pName = targetPlayer.Name
	local char = targetPlayer.Character
	local backpack = targetPlayer:FindFirstChild("Backpack")
	local hasKnife, hasGun = false, false

	if char then
		for _, item in ipairs(char:GetChildren()) do
			local t = CheckTool(item)
			if t == "Murderer" then hasKnife = true end
			if t == "Gun" then hasGun = true end
		end
	end

	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			local t = CheckTool(item)
			if t == "Murderer" then hasKnife = true end
			if t == "Gun" then hasGun = true end
		end
	end

	if hasKnife then return "Murderer", Theme.MurdererColor end
	if hasGun then
		if cachedServerRoles[pName] == "Hero" or (activeSheriff and activeSheriff ~= pName) then
			return "Hero", Theme.HeroColor
		else
			return "Sheriff", Theme.SheriffColor
		end
	end

	local role = cachedServerRoles[pName]
	if role == "Murderer" then return "Murderer", Theme.MurdererColor
	elseif role == "Sheriff" then return "Sheriff", Theme.SheriffColor
	elseif role == "Hero" then return "Hero", Theme.HeroColor end

	return "Innocent", Theme.InnocentColor
end

local function UpdateSinglePlayerESP(p)
	if p == player then return end
	local alive = IsPlayerAlive(p)
	local role, roleColor = GetPlayerRole(p)
	local char = p.Character

	local hl = chamsHighlights[p]
	if isChamsEnabled and alive and char then
		if not hl or hl.Parent ~= char then
			if hl then hl:Destroy() end
			hl = Instance.new("Highlight")
			hl.Name = "MM2_Highlight"
			hl.FillTransparency = 0.45
			hl.OutlineTransparency = 0.1
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = char
			chamsHighlights[p] = hl
		end
		hl.FillColor = roleColor
		hl.OutlineColor = roleColor
	else
		if hl then hl:Destroy() chamsHighlights[p] = nil end
	end

	local tag = playerTags[p]
	if isTagsEnabled and alive and char and char:FindFirstChild("Head") then
		local head = char.Head
		local myChar = player.Character
		local distance = (myChar and myChar:FindFirstChild("HumanoidRootPart")) and math.floor((head.Position - myChar.HumanoidRootPart.Position).Magnitude) or 0

		if not tag or tag.Parent ~= head then
			if tag then tag:Destroy() end
			tag = Instance.new("BillboardGui")
			tag.Name = "MM2_InfoTag"
			tag.Size = UDim2.new(0, 120, 0, 34)
			tag.StudsOffset = Vector3.new(0, 2.5, 0)
			tag.AlwaysOnTop = true
			tag.Parent = head

			local tl = Instance.new("TextLabel")
			tl.Name = "Label"
			tl.Size = UDim2.new(1, 0, 1, 0)
			tl.BackgroundTransparency = 1
			tl.Font = Enum.Font.GothamBold
			tl.TextSize = 11
			tl.TextStrokeTransparency = 0.2
			tl.Parent = tag
			playerTags[p] = tag
		end

		tag.Label.Text = string.format("[%s]\n%s (%dm)", role, p.DisplayName, distance)
		tag.Label.TextColor3 = roleColor
	else
		if tag then tag:Destroy() playerTags[p] = nil end
	end

	if alive then
		if role == "Murderer" and activeMurderer ~= p.Name then
			activeMurderer = p.Name
			ShowNotification("Role Revealed", "Murderer: " .. p.DisplayName, Theme.MurdererColor)
		elseif role == "Sheriff" and activeSheriff ~= p.Name then
			activeSheriff = p.Name
			ShowNotification("Role Revealed", "Sheriff: " .. p.DisplayName, Theme.SheriffColor)
		elseif role == "Hero" and activeHero ~= p.Name then
			activeHero = p.Name
			ShowNotification("Hero Arrived", "Hero: " .. p.DisplayName, Theme.HeroColor)
		end
	end
end

local function RefreshAllESP()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then UpdateSinglePlayerESP(p) end
	end
end

task.spawn(function()
	while true do
		task.wait(0.35)
		if FetchServerRoles() then RefreshAllESP() end
	end
end)

local function SetupPlayerHooks(p)
	if p == player then return end
	local function HookCharacter(char)
		UpdateSinglePlayerESP(p)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then task.wait() UpdateSinglePlayerESP(p) end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then task.wait() UpdateSinglePlayerESP(p) end
		end)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.Died:Connect(function() UpdateSinglePlayerESP(p) end)
		end
	end
	local function HookBackpack(bp)
		bp.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then task.wait() UpdateSinglePlayerESP(p) end
		end)
	end

	if p.Character then HookCharacter(p.Character) end
	p.CharacterAdded:Connect(HookCharacter)

	local currentBp = p:FindFirstChild("Backpack")
	if currentBp then HookBackpack(currentBp) end
	p.ChildAdded:Connect(function(child)
		if child.Name == "Backpack" then HookBackpack(child) end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do SetupPlayerHooks(p) end
Players.PlayerAdded:Connect(SetupPlayerHooks)

local function ResetRoundState()
	activeMurderer = nil
	activeSheriff = nil
	activeHero = nil
	table.clear(cachedServerRoles)
	task.spawn(function()
		for _ = 1, 8 do
			FetchServerRoles()
			RefreshAllESP()
			task.wait(0.25)
		end
	end)
end

player.CharacterAdded:Connect(ResetRoundState)
workspace.DescendantAdded:Connect(function(desc)
	if desc.Name == "CoinContainer" or desc.Name:lower():find("map") then
		ResetRoundState()
	end
end)

Players.PlayerRemoving:Connect(function(leaving)
	if chamsHighlights[leaving] then chamsHighlights[leaving]:Destroy() chamsHighlights[leaving] = nil end
	if playerTags[leaving] then playerTags[leaving]:Destroy() playerTags[leaving] = nil end
	if lineObjects[leaving] then lineObjects[leaving]:Destroy() lineObjects[leaving] = nil end
	if activeMurderer == leaving.Name then activeMurderer = nil end
	if activeSheriff == leaving.Name then activeSheriff = nil end
	if activeHero == leaving.Name then activeHero = nil end
	cachedServerRoles[leaving.Name] = nil
end)

-- Coin ESP Engine (BoxHandleAdornment)
local isCoinEspEnabled = false
local coinAdornments = {}

local function RemoveCoinAdornment(coinObj)
	local data = coinAdornments[coinObj]
	if data then
		if data.Box then data.Box:Destroy() end
		if data.Tag then data.Tag:Destroy() end
		coinAdornments[coinObj] = nil
	end
end

local function ClearAllCoinESP()
	for coinObj, _ in pairs(coinAdornments) do RemoveCoinAdornment(coinObj) end
	table.clear(coinAdornments)
end

local function GetCoinBasePart(coinObj)
	if coinObj:IsA("BasePart") then return coinObj
	elseif coinObj:IsA("Model") then return coinObj.PrimaryPart or coinObj:FindFirstChildWhichIsA("BasePart") end
	return coinObj:FindFirstChildWhichIsA("BasePart", true)
end

local function AddCoinESP(coinObj)
	if not isCoinEspEnabled or coinAdornments[coinObj] then return end
	local part = GetCoinBasePart(coinObj)
	if not part then return end

	local box = Instance.new("BoxHandleAdornment")
	box.Name = "MM2_CoinBox"
	box.Size = Vector3.new(1.8, 1.8, 1.8)
	box.Color3 = Theme.CoinColor
	box.Transparency = 0.35
	box.AlwaysOnTop = true
	box.ZIndex = 5
	box.Adornee = part
	box.Parent = part

	local bill = Instance.new("BillboardGui")
	bill.Name = "MM2_CoinTag"
	bill.Size = UDim2.new(0, 42, 0, 16)
	bill.AlwaysOnTop = true
	bill.StudsOffset = Vector3.new(0, 1.3, 0)
	bill.Adornee = part
	bill.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.AutoLocalize = false
	label.Text = "🪙"
	label.TextSize = 13
	label.Parent = bill

	coinAdornments[coinObj] = { Box = box, Tag = bill, Part = part }
	coinObj.AncestryChanged:Connect(function(_, parent)
		if not parent then RemoveCoinAdornment(coinObj) end
	end)
end

local function ScanForCoins()
	if not isCoinEspEnabled then return end
	local container = workspace:FindFirstChild("CoinContainer", true)
	if container then
		for _, child in ipairs(container:GetChildren()) do AddCoinESP(child) end
	end
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc.Name == "Coin_Server" or desc.Name == "CoinVisual" or (desc.Name == "Coin" and desc:IsA("BasePart")) then
			AddCoinESP(desc)
		end
	end
end

workspace.DescendantAdded:Connect(function(desc)
	if not isCoinEspEnabled then return end
	if desc.Name == "CoinContainer" then
		desc.ChildAdded:Connect(function(child)
			if isCoinEspEnabled then task.wait() AddCoinESP(child) end
		end)
		for _, child in ipairs(desc:GetChildren()) do AddCoinESP(child) end
	elseif desc.Name == "Coin_Server" or desc.Name == "CoinVisual" or (desc.Name == "Coin" and desc:IsA("BasePart")) then
		task.wait()
		AddCoinESP(desc)
	end
end)

local function ClearTracers()
	for _, line in pairs(lineObjects) do line:Destroy() end
	table.clear(lineObjects)
end

local function UpdateTracers()
	if not isTracersEnabled then ClearTracers() return end
	local screenBottom = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and IsPlayerAlive(p) then
			local hrp = p.Character.HumanoidRootPart
			local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)

			if onScreen then
				local line = lineObjects[p]
				if not line then
					line = Instance.new("Frame")
					line.AnchorPoint = Vector2.new(0.5, 0.5)
					line.BorderSizePixel = 0
					line.Parent = tracerFolder
					lineObjects[p] = line
				end

				local targetPos = Vector2.new(screenPos.X, screenPos.Y)
				local distance = (targetPos - screenBottom).Magnitude
				local angle = math.deg(math.atan2(targetPos.Y - screenBottom.Y, targetPos.X - screenBottom.X))

				local _, roleColor = GetPlayerRole(p)
				line.Size = UDim2.new(0, distance, 0, 1.5)
				line.Position = UDim2.new(0, (screenBottom.X + targetPos.X) / 2, 0, (screenBottom.Y + targetPos.Y) / 2)
				line.Rotation = angle
				line.BackgroundColor3 = roleColor
				line.Visible = true
			else
				if lineObjects[p] then lineObjects[p].Visible = false end
			end
		else
			if lineObjects[p] then lineObjects[p]:Destroy() lineObjects[p] = nil end
		end
	end
end

local isGunEspEnabled = false
local gunHighlight = nil
local gunBeamPart = nil

local function UpdateGunESP()
	if not isGunEspEnabled then
		if gunHighlight then gunHighlight:Destroy() gunHighlight = nil end
		if gunBeamPart then gunBeamPart:Destroy() gunBeamPart = nil end
		return
	end

	local droppedGun = workspace:FindFirstChild("GunDrop")
	if droppedGun then
		local gunCFrame = droppedGun:IsA("Model") and droppedGun:GetPivot() or (droppedGun:IsA("BasePart") and droppedGun.CFrame)

		if gunCFrame then
			if not gunHighlight or gunHighlight.Parent ~= droppedGun then
				if gunHighlight then gunHighlight:Destroy() end
				gunHighlight = Instance.new("Highlight")
				gunHighlight.Name = "GunHighlight"
				gunHighlight.FillColor = Theme.CoinColor
				gunHighlight.OutlineColor = Color3.fromRGB(240, 240, 245)
				gunHighlight.FillTransparency = 0.2
				gunHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				gunHighlight.Parent = droppedGun
			end

			if not gunBeamPart then
				gunBeamPart = Instance.new("Part")
				gunBeamPart.Name = "GunBeacon"
				gunBeamPart.Anchored = true
				gunBeamPart.CanCollide = false
				gunBeamPart.CastShadow = false
				gunBeamPart.Material = Enum.Material.SmoothPlastic
				gunBeamPart.Color = Theme.CoinColor
				gunBeamPart.Transparency = 0.4
				gunBeamPart.Size = Vector3.new(0.8, 1000, 0.8)
				gunBeamPart.Parent = workspace
			end
			gunBeamPart.CFrame = gunCFrame * CFrame.new(0, 500, 0)
		end
	else
		if gunHighlight then gunHighlight:Destroy() gunHighlight = nil end
		if gunBeamPart then gunBeamPart:Destroy() gunBeamPart = nil end
	end
end

local isWarningEnabled = false
local function UpdateProximityWarning()
	if not isWarningEnabled or not IsPlayerAlive(player) then
		warningBanner.Visible = false
		return
	end

	local myPos = player.Character.HumanoidRootPart.Position
	local murderFound = false

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and IsPlayerAlive(p) then
			local role = GetPlayerRole(p)
			if role == "Murderer" then
				local dist = math.floor((p.Character.HumanoidRootPart.Position - myPos).Magnitude)
				if dist <= 50 then
					warningBanner.Visible = true
					warningText.Text = string.format("⚠️ MURDERER NEARBY: %dm ⚠️", dist)
					murderFound = true
					break
				end
			end
		end
	end

	if not murderFound then warningBanner.Visible = false end
end

local isFullbrightEnabled = false
local defaultBrightness = Lighting.Brightness
local defaultClockTime = Lighting.ClockTime
local defaultFogEnd = Lighting.FogEnd
local defaultGlobalShadows = Lighting.GlobalShadows

local function SetFullbright(state)
	isFullbrightEnabled = state
	if state then
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
	else
		Lighting.Brightness = defaultBrightness
		Lighting.ClockTime = defaultClockTime
		Lighting.FogEnd = defaultFogEnd
		Lighting.GlobalShadows = defaultGlobalShadows
	end
end

local isFpsBoostEnabled = false
local storedMaterials = setmetatable({}, { __mode = "k" })

local function SetFpsBoost(state)
	isFpsBoostEnabled = state
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") then
			if state then
				if not storedMaterials[part] then storedMaterials[part] = part.Material end
				part.Material = Enum.Material.SmoothPlastic
			else
				if storedMaterials[part] then part.Material = storedMaterials[part] end
			end
		elseif part:IsA("ParticleEmitter") or part:IsA("Smoke") or part:IsA("Fire") then
			part.Enabled = not state
		end
	end
end

CreateToggleSwitch(visualsPage, "Player ESP (Chams)", "Highlights Murderer, Sheriff, Hero & Innocents", false, function(v)
	isChamsEnabled = v
	RefreshAllESP()
end)

CreateToggleSwitch(visualsPage, "Name & Info Tags", "Displays roles, names & distance", false, function(v)
	isTagsEnabled = v
	RefreshAllESP()
end)

CreateToggleSwitch(visualsPage, "Tracers", "Draws lines with role colors", false, function(v)
	isTracersEnabled = v
	if not v then ClearTracers() end
end)

CreateToggleSwitch(visualsPage, "Coin ESP", "Highlights all map coins through walls", false, function(v)
	isCoinEspEnabled = v
	if v then ScanForCoins() else ClearAllCoinESP() end
end)

CreateToggleSwitch(visualsPage, "Murderer Proximity Alert", "Warns when Murderer is within 50m", false, function(v)
	isWarningEnabled = v
	if not v then warningBanner.Visible = false end
end)

CreateToggleSwitch(visualsPage, "Dropped Gun ESP & Beam", "Highlight & beacon on dropped gun", false, function(v)
	isGunEspEnabled = v
	UpdateGunESP()
end)

CreateToggleSwitch(visualsPage, "Fullbright", "Removes shadows and dark fog completely", false, function(v)
	SetFullbright(v)
end)

CreateToggleSwitch(visualsPage, "FPS Boost (Low Detail)", "Disables particles and smooths textures", false, function(v)
	SetFpsBoost(v)
end)

addSliderCard(visualsPage, "Field Of View (FOV)", 70, 120, math.floor(camera.FieldOfView), function(val)
	camera.FieldOfView = val
end)

-- =========================================================================
-- 15. TROLL SYSTEM (PAGE 7) - WITH ACCORDION FOLDERS & WORKING EMOTES
-- =========================================================================
local trollPage = categoryPages[7].Page

local selectedPlayer = nil
local playerList = {}
local selectedPlayerIndex = 1

local isOrbitFlingEnabled = false
local isInvisFlingEnabled = false
local isBigHeadEnabled = false
local isFakeLagEnabled = false
local isAutoDanceEnabled = false
local isChatSpammerEnabled = false
local isVoidhideEnabled = false
local showVoidhideMarker = true

local voidhidePart = nil
local voidhideBeacon = nil
local voidhideReturnCFrame = nil
local activeAnimationTrack = nil
local isSpectating = false

local isCurrentlyFlinging = false
local targetCooldowns = {}

-- Safe Chat Messenger
local function SendChatMessage(msg)
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
			if channel then channel:SendAsync(msg) end
		else
			local sayEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			if sayEvent and sayEvent:FindFirstChild("SayMessageRequest") then
				sayEvent.SayMessageRequest:FireServer(msg, "All")
			end
		end
	end)
end

-- Robust Fling Engine
local function FlingTarget(targetPlayer, maxTime, flingType)
	if isCurrentlyFlinging then return end
	if not IsPlayerAlive(player) or not IsPlayerAlive(targetPlayer) then return end

	local lastFling = targetCooldowns[targetPlayer] or 0
	if tick() - lastFling < 2.5 then
		ShowNotification("Cooldown", "Wait before flinging " .. targetPlayer.DisplayName .. " again", Theme.Accent)
		return
	end
	targetCooldowns[targetPlayer] = tick()

	task.spawn(function()
		local myChar = player.Character
		local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

		local targetChar = targetPlayer.Character
		local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
		local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		local targetHead = targetChar and targetChar:FindFirstChild("Head")

		if not myHrp or not myHum or not targetHum or targetHum.Health <= 0 then return end

		local targetPart = targetHrp or targetHead or targetChar:FindFirstChildWhichIsA("BasePart")
		if not targetPart then return end

		isCurrentlyFlinging = true
		local oldPos = myHrp.CFrame
		local targetStartPos = targetPart.Position
		local oldFPDH = workspace.FallenPartsDestroyHeight
		local oldCamSubject = camera.CameraSubject

		pcall(function()
			workspace.FallenPartsDestroyHeight = 0/0
			camera.CameraSubject = targetHum or targetPart
		end)

		local bv = Instance.new("BodyVelocity")
		bv.Name = "MM2_StabilizerBV"
		bv.Velocity = Vector3.zero
		bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		bv.Parent = myHrp

		pcall(function()
			myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
			myHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			myHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		end)

		local noclipLoop
		noclipLoop = RunService.Stepped:Connect(function()
			if player.Character then
				for _, part in ipairs(player.Character:GetDescendants()) do
					if part:IsA("BasePart") and part ~= myHrp then
						part.CanCollide = false
					end
				end
			end
		end)

		local function FPos(basePart, offset, angle)
			pcall(function()
				local targetCF = CFrame.new(basePart.Position) * offset * angle
				myHrp.CFrame = targetCF
				myChar:SetPrimaryPartCFrame(targetCF)
				myHrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
				myHrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
				myHrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
				myHrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
			end)
		end

		local duration = maxTime or 1.6
		local startTime = tick()
		local angle = 0
		local flingRunning = true

		while flingRunning do
			RunService.Heartbeat:Wait()

			if not IsPlayerAlive(player) or not IsPlayerAlive(targetPlayer) then
				break
			end

			local elapsed = tick() - startTime
			if elapsed > duration then
				break
			end

			local curTargetPos = targetPart.Position
			local targetVel = targetPart.AssemblyLinearVelocity.Magnitude
			local targetMoved = (curTargetPos - targetStartPos).Magnitude

			if elapsed > 0.14 and (targetVel > 75 or targetMoved > 45 or curTargetPos.Y < -40) then
				break
			end

			if flingType == "Rocket" then
				pcall(function()
					myHrp.CFrame = targetPart.CFrame * CFrame.new(0, -1.8, 0)
					task.wait()
					myHrp.AssemblyLinearVelocity = Vector3.new(0, 999999, 0)
					myHrp.AssemblyAngularVelocity = Vector3.new(0, 999999, 0)
				end)
			else
				angle = angle + 100
				local moveDir = targetHum.MoveDirection
				local velMag = targetPart.AssemblyLinearVelocity.Magnitude

				if velMag < 50 then
					local lead = moveDir * (velMag / 1.25)
					FPos(targetPart, CFrame.new(0, 1.5, 0) + lead, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
					FPos(targetPart, CFrame.new(0, -1.5, 0) + lead, CFrame.Angles(math.rad(angle), 0, 0))
					task.wait()
				else
					FPos(targetPart, CFrame.new(0, 1.5, targetHum.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
					task.wait()
					FPos(targetPart, CFrame.new(0, -1.5, -targetHum.WalkSpeed), CFrame.Angles(0, 0, 0))
					task.wait()
				end

				if firetouchinterest then
					pcall(function()
						firetouchinterest(myHrp, targetPart, 0)
						firetouchinterest(myHrp, targetPart, 1)
					end)
				end
			end
		end

		if noclipLoop then noclipLoop:Disconnect() end
		if bv then bv:Destroy() end

		pcall(function()
			workspace.FallenPartsDestroyHeight = oldFPDH
			camera.CameraSubject = oldCamSubject or (IsPlayerAlive(player) and player.Character.Humanoid)
			myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
		end)

		if IsPlayerAlive(player) then
			for _ = 1, 10 do
				pcall(function()
					myHrp.AssemblyLinearVelocity = Vector3.zero
					myHrp.AssemblyAngularVelocity = Vector3.zero
					myHrp.Velocity = Vector3.zero
					myHrp.RotVelocity = Vector3.zero
					myHrp.CFrame = oldPos * CFrame.new(0, 0.5, 0)
					myChar:SetPrimaryPartCFrame(oldPos * CFrame.new(0, 0.5, 0))
				end)
				RunService.Heartbeat:Wait()
			end

			pcall(function()
				myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end

		isCurrentlyFlinging = false
	end)
end

-- Refresh Players for Selector
local function RefreshPlayerList()
	table.clear(playerList)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			table.insert(playerList, p)
		end
	end
	if #playerList > 0 then
		selectedPlayerIndex = math.clamp(selectedPlayerIndex, 1, #playerList)
		selectedPlayer = playerList[selectedPlayerIndex]
	else
		selectedPlayer = nil
	end
end

RefreshPlayerList()
Players.PlayerAdded:Connect(RefreshPlayerList)
Players.PlayerRemoving:Connect(function(leaving)
	RefreshPlayerList()
	if isSpectating and selectedPlayer == leaving then
		camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
		isSpectating = false
	end
end)

-- UI: Player Selector Card
local playerCard = Instance.new("Frame")
playerCard.Name = "PlayerSelectorCard"
playerCard.Size = UDim2.new(1, 0, 0, 70)
playerCard.BackgroundColor3 = Theme.CardBackground
playerCard.BackgroundTransparency = 0.5
playerCard.Parent = trollPage
local plc = Instance.new("UICorner") plc.CornerRadius = UDim.new(0, 10) plc.Parent = playerCard

local targetAvatar = Instance.new("ImageLabel")
targetAvatar.Size = UDim2.new(0, 48, 0, 48)
targetAvatar.Position = UDim2.new(0, 10, 0.5, -24)
targetAvatar.BackgroundColor3 = Color3.fromRGB(15, 14, 18)
targetAvatar.Parent = playerCard
local tac = Instance.new("UICorner") tac.CornerRadius = UDim.new(1, 0) tac.Parent = targetAvatar

local targetName = Instance.new("TextLabel")
targetName.Size = UDim2.new(0.42, 0, 0, 20)
targetName.Position = UDim2.new(0, 66, 0, 15)
targetName.BackgroundTransparency = 1
targetName.AutoLocalize = false
targetName.Text = selectedPlayer and selectedPlayer.DisplayName or "No Players"
targetName.TextColor3 = Theme.TextActive
targetName.Font = Enum.Font.GothamBold
targetName.TextSize = 13
targetName.TextXAlignment = Enum.TextXAlignment.Left
targetName.Parent = playerCard

local targetUser = Instance.new("TextLabel")
targetUser.Size = UDim2.new(0.42, 0, 0, 16)
targetUser.Position = UDim2.new(0, 66, 0, 36)
targetUser.BackgroundTransparency = 1
targetUser.AutoLocalize = false
targetUser.Text = selectedPlayer and ("@" .. selectedPlayer.Name) or ""
targetUser.TextColor3 = Theme.TextInactive
targetUser.Font = Enum.Font.Gotham
targetUser.TextSize = 11
targetUser.TextXAlignment = Enum.TextXAlignment.Left
targetUser.Parent = playerCard

local function UpdateSelectorUI()
	if selectedPlayer then
		targetName.Text = selectedPlayer.DisplayName
		targetUser.Text = "@" .. selectedPlayer.Name
		targetAvatar.Image = Players:GetUserThumbnailAsync(selectedPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	else
		targetName.Text = "No Players"
		targetUser.Text = "Waiting for players..."
		targetAvatar.Image = ""
	end
end

UpdateSelectorUI()

-- Prev Player Button [ < ]
local prevBtn = Instance.new("TextButton")
prevBtn.Size = UDim2.new(0, 28, 0, 28)
prevBtn.Position = UDim2.new(1, -114, 0.5, -14)
prevBtn.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
prevBtn.AutoLocalize = false
prevBtn.Text = "◀"
prevBtn.TextColor3 = Theme.TextActive
prevBtn.Font = Enum.Font.GothamBold
prevBtn.TextSize = 11
prevBtn.Parent = playerCard
local pbc = Instance.new("UICorner") pbc.CornerRadius = UDim.new(0, 8) pbc.Parent = prevBtn
AddPressEffect(prevBtn)

prevBtn.MouseButton1Click:Connect(function()
	if #playerList > 0 then
		selectedPlayerIndex = selectedPlayerIndex - 1
		if selectedPlayerIndex < 1 then selectedPlayerIndex = #playerList end
		selectedPlayer = playerList[selectedPlayerIndex]
		UpdateSelectorUI()
		if isSpectating and selectedPlayer and selectedPlayer.Character then
			camera.CameraSubject = selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
		end
	end
end)

-- Next Player Button [ > ]
local nextBtn = Instance.new("TextButton")
nextBtn.Size = UDim2.new(0, 28, 0, 28)
nextBtn.Position = UDim2.new(1, -82, 0.5, -14)
nextBtn.BackgroundColor3 = Color3.fromRGB(42, 42, 50)
nextBtn.AutoLocalize = false
nextBtn.Text = "▶"
nextBtn.TextColor3 = Theme.TextActive
nextBtn.Font = Enum.Font.GothamBold
nextBtn.TextSize = 11
nextBtn.Parent = playerCard
local nbc = Instance.new("UICorner") nbc.CornerRadius = UDim.new(0, 8) nbc.Parent = nextBtn
AddPressEffect(nextBtn)

nextBtn.MouseButton1Click:Connect(function()
	if #playerList > 0 then
		selectedPlayerIndex = selectedPlayerIndex + 1
		if selectedPlayerIndex > #playerList then selectedPlayerIndex = 1 end
		selectedPlayer = playerList[selectedPlayerIndex]
		UpdateSelectorUI()
		if isSpectating and selectedPlayer and selectedPlayer.Character then
			camera.CameraSubject = selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
		end
	end
end)

-- Spectate Button [ 👁 ]
local spectateBtn = Instance.new("TextButton")
spectateBtn.Size = UDim2.new(0, 36, 0, 28)
spectateBtn.Position = UDim2.new(1, -48, 0.5, -14)
spectateBtn.BackgroundColor3 = Theme.Accent
spectateBtn.AutoLocalize = false
spectateBtn.Text = "👁"
spectateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
spectateBtn.Font = Enum.Font.GothamBold
spectateBtn.TextSize = 13
spectateBtn.Parent = playerCard
local sbc = Instance.new("UICorner") sbc.CornerRadius = UDim.new(0, 8) sbc.Parent = spectateBtn
AddPressEffect(spectateBtn)

spectateBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer or not selectedPlayer.Character then return end
	isSpectating = not isSpectating
	if isSpectating then
		camera.CameraSubject = selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
		spectateBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
		ShowNotification("Spectate", "Watching " .. selectedPlayer.DisplayName, Theme.Accent)
	else
		if IsPlayerAlive(player) then
			camera.CameraSubject = player.Character.Humanoid
		end
		spectateBtn.BackgroundColor3 = Theme.Accent
	end
end)

-- =========================================================================
-- COLLAPSIBLE 1: FLING OPTIONS ACCORDION
-- =========================================================================
local flingContainer = CreateCollapsibleFolder(trollPage, "Fling Options", "rbxassetid://6034767608")

CreateActionButton(flingContainer, "Fling Selected", "Flings target and returns to your position", "Fling", function()
	if selectedPlayer then
		ShowNotification("Fling", "Flinging " .. selectedPlayer.DisplayName, Theme.Accent)
		FlingTarget(selectedPlayer, 1.5)
	end
end)

CreateActionButton(flingContainer, "Fling Murderer", "Instantly detects and flings murderer", "Fling", function()
	local found = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and GetPlayerRole(p) == "Murderer" then
			found = p
			break
		end
	end
	if found then
		ShowNotification("Fling", "Flinging Murderer: " .. found.DisplayName, Theme.MurdererColor)
		FlingTarget(found, 1.5)
	else
		ShowNotification("Fling", "Murderer not found yet!", Theme.Accent)
	end
end)

CreateActionButton(flingContainer, "Fling Sheriff", "Instantly detects and flings sheriff", "Fling", function()
	local found = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and GetPlayerRole(p) == "Sheriff" then
			found = p
			break
		end
	end
	if found then
		ShowNotification("Fling", "Flinging Sheriff: " .. found.DisplayName, Theme.SheriffColor)
		FlingTarget(found, 1.5)
	else
		ShowNotification("Fling", "Sheriff not found yet!", Theme.Accent)
	end
end)

CreateActionButton(flingContainer, "Fling All", "Cycles through and flings all living players", "Fling All", function()
	ShowNotification("Fling", "Flinging all players...", Theme.Accent)
	task.spawn(function()
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and IsPlayerAlive(p) then
				task.wait(math.random(80, 120) / 1000)
				FlingTarget(p, 0.9)
				while isCurrentlyFlinging do
					task.wait(0.05)
				end
			end
		end
	end)
end)

CreateActionButton(flingContainer, "Super Fling (Rocket)", "Launches player high into the stratosphere", "Rocket", function()
	if selectedPlayer then
		ShowNotification("Super Fling", "Launching " .. selectedPlayer.DisplayName .. " to space!", Theme.Accent)
		FlingTarget(selectedPlayer, 1.5, "Rocket")
	end
end)

CreateToggleSwitch(flingContainer, "Orbit Fling", "Rapidly circles around selected player with fling", false, function(v)
	isOrbitFlingEnabled = v
end)

CreateToggleSwitch(flingContainer, "Invisible Fling", "Turns invisible and applies max rotational fling", false, function(v)
	isInvisFlingEnabled = v
	if IsPlayerAlive(player) then
		for _, part in ipairs(player.Character:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.Transparency = v and 1 or 0
			end
		end
	end
end)

-- =========================================================================
-- COLLAPSIBLE 2: EMOTES & DANCES (R6/R15 Universal Engine)
-- =========================================================================
local emotesContainer = CreateCollapsibleFolder(trollPage, "Emotes & Dances", "rbxassetid://6034440078")

local function PlayEmoteAnimation(animId)
	if not IsPlayerAlive(player) then return end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	pcall(function()
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		if activeAnimationTrack then
			activeAnimationTrack:Stop()
			activeAnimationTrack = nil
		end

		local anim = Instance.new("Animation")
		anim.AnimationId = animId
		activeAnimationTrack = animator:LoadAnimation(anim)
		activeAnimationTrack.Priority = Enum.AnimationPriority.Action
		activeAnimationTrack:Play()
	end)
end

CreateToggleSwitch(emotesContainer, "Auto Dance", "Continuously performs default dances in loop", false, function(v)
	isAutoDanceEnabled = v
	if v then
		task.spawn(function()
			while isAutoDanceEnabled and IsPlayerAlive(player) do
				PlayEmoteAnimation("rbxassetid://507771019")
				task.wait(4.5)
			end
		end)
	else
		if activeAnimationTrack then
			activeAnimationTrack:Stop()
			activeAnimationTrack = nil
		end
	end
end)

-- Universal Working R6 / R15 Animation ID Presets
local verifiedEmotes = {
	{ Name = "Dance 1", Id = "rbxassetid://507771019" },
	{ Name = "Dance 2", Id = "rbxassetid://507776720" },
	{ Name = "Dance 3", Id = "rbxassetid://507777268" },
	{ Name = "Floss", Id = "rbxassetid://10714340543" },
	{ Name = "Dab", Id = "rbxassetid://2482384752" },
	{ Name = "Zombie", Id = "rbxassetid://3565463794" },
	{ Name = "Zen", Id = "rbxassetid://3137632622" },
	{ Name = "Ninja Wave", Id = "rbxassetid://128777973" }
}

for _, em in ipairs(verifiedEmotes) do
	CreateActionButton(emotesContainer, "Emote: " .. em.Name, "Plays " .. em.Name .. " animation", "Play", function()
		PlayEmoteAnimation(em.Id)
	end)
end

CreateActionButton(emotesContainer, "Emote: Headless", "Hides head and face mesh completely", "Apply", function()
	if IsPlayerAlive(player) and player.Character:FindFirstChild("Head") then
		local h = player.Character.Head
		h.Transparency = 1
		local f = h:FindFirstChildOfClass("Decal")
		if f then f.Transparency = 1 end
		ShowNotification("Headless", "Head mesh hidden visually!", Theme.Accent)
	end
end)

CreateActionButton(emotesContainer, "Stop Emotes", "Stops all active animations and poses", "Stop", function()
	if activeAnimationTrack then
		activeAnimationTrack:Stop()
		activeAnimationTrack = nil
	end
	if IsPlayerAlive(player) then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
				pcall(function() track:Stop() end)
			end
		end
	end
end)

-- =========================================================================
-- OTHER TROLL UTILITIES (Godmode removed)
-- =========================================================================
CreateToggleSwitch(trollPage, "Invisible / Voidhide", "Teleports to underground safe bunker while watching", false, function(v)
	isVoidhideEnabled = v
	if not IsPlayerAlive(player) then return end
	local hrp = player.Character.HumanoidRootPart

	if v then
		voidhideReturnCFrame = hrp.CFrame

		if not voidhidePart then
			voidhidePart = Instance.new("Part")
			voidhidePart.Name = "MM2_VoidHidePod"
			voidhidePart.Size = Vector3.new(12, 1, 12)
			voidhidePart.Position = Vector3.new(hrp.Position.X, -160, hrp.Position.Z)
			voidhidePart.Anchored = true
			voidhidePart.CanCollide = true
			voidhidePart.Transparency = 0.5
			voidhidePart.Color = Color3.fromRGB(15, 12, 20)
			voidhidePart.Parent = workspace
		end

		if showVoidhideMarker and not voidhideBeacon then
			voidhideBeacon = Instance.new("Part")
			voidhideBeacon.Name = "MM2_VoidMarker"
			voidhideBeacon.Size = Vector3.new(1, 2000, 1)
			voidhideBeacon.Position = Vector3.new(voidhideReturnCFrame.Position.X, 1000, voidhideReturnCFrame.Position.Z)
			voidhideBeacon.Anchored = true
			voidhideBeacon.CanCollide = false
			voidhideBeacon.Material = Enum.Material.SmoothPlastic
			voidhideBeacon.Color = Theme.Accent
			voidhideBeacon.Transparency = 0.5
			voidhideBeacon.Parent = workspace
		end

		hrp.CFrame = voidhidePart.CFrame + Vector3.new(0, 3, 0)
	else
		if voidhideReturnCFrame then
			hrp.CFrame = voidhideReturnCFrame
		end
		if voidhidePart then voidhidePart:Destroy() voidhidePart = nil end
		if voidhideBeacon then voidhideBeacon:Destroy() voidhideBeacon = nil end
	end
end)

CreateToggleSwitch(trollPage, "Show Voidhide Position", "Draws beacon above your pre-hide position", true, function(v)
	showVoidhideMarker = v
	if voidhideBeacon then voidhideBeacon.Transparency = v and 0.5 or 1 end
end)

local originalHeadSize = Vector3.new(2, 1, 1)
CreateToggleSwitch(trollPage, "Big Head", "Expands head size visually without breaking physics", false, function(v)
	isBigHeadEnabled = v
	if IsPlayerAlive(player) and player.Character:FindFirstChild("Head") then
		local h = player.Character.Head
		h.Massless = true
		h.Size = v and Vector3.new(6, 4, 4) or originalHeadSize
	end
end)

CreateToggleSwitch(trollPage, "Fake Die", "Ragdolls and plays death pose locally", false, function(v)
	if IsPlayerAlive(player) then
		player.Character.Humanoid.PlatformStand = v
	end
end)

CreateToggleSwitch(trollPage, "Fake Sleep", "Lays down on the floor flat", false, function(v)
	if IsPlayerAlive(player) then
		player.Character.Humanoid.PlatformStand = v
		if v then
			player.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.Angles(math.rad(90), 0, 0)
		end
	end
end)

CreateToggleSwitch(trollPage, "Fake Lag", "Simulates high network jitter / freezing in place", false, function(v)
	isFakeLagEnabled = v
end)

CreateActionButton(trollPage, "Bring Player", "Pushes the target towards you via physics", "Bring", function()
	if selectedPlayer and IsPlayerAlive(selectedPlayer) and IsPlayerAlive(player) then
		local myPos = player.Character.HumanoidRootPart.CFrame
		task.spawn(function()
			for _ = 1, 15 do
				if not IsPlayerAlive(selectedPlayer) or not IsPlayerAlive(player) then break end
				local sHrp = selectedPlayer.Character.HumanoidRootPart
				sHrp.CFrame = myPos * CFrame.new(0, 0, -3)
				task.wait(0.03)
			end
		end)
		ShowNotification("Bring", "Attempting to pull " .. selectedPlayer.DisplayName, Theme.Accent)
	end
end)

local isSitOnPlayer = false
CreateToggleSwitch(trollPage, "Sit On Player", "Glues you sitting on top of the selected player", false, function(v)
	isSitOnPlayer = v
	if not v and IsPlayerAlive(player) then
		player.Character.Humanoid.Sit = false
	end
end)

local isHeadSit = false
CreateToggleSwitch(trollPage, "Head Sit", "Sits directly on the selected player's head", false, function(v)
	isHeadSit = v
	if not v and IsPlayerAlive(player) then
		player.Character.Humanoid.Sit = false
	end
end)

CreateToggleSwitch(trollPage, "Fake Gun", "Emulates holding the sheriff revolver pose", false, function(v)
	if IsPlayerAlive(player) then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://130044530"
			local track = animator:LoadAnimation(anim)
			if v then track:Play() else track:Stop() end
		end
	end
end)

CreateToggleSwitch(trollPage, "Chat Spammer", "Sends troll messages into chat periodically", false, function(v)
	isChatSpammerEnabled = v
end)

-- =========================================================================
-- RUNTIME LOOPS FOR TROLL & UTILITIES
-- =========================================================================
local orbitAngle = 0
local lastChatSpam = 0
local spamMessages = {
	"MistralScripts on top! ⚡",
	"Who is the murderer? 👀",
	"Nice try! 🔪",
	"t.me/MistralScripts 🚀"
}
local spamIndex = 1

RunService.Heartbeat:Connect(function()
	if not IsPlayerAlive(player) then return end
	local hrp = player.Character.HumanoidRootPart
	local hum = player.Character.Humanoid

	if isInvisFlingEnabled and not isCurrentlyFlinging then
		pcall(function()
			hrp.AssemblyAngularVelocity = Vector3.new(99999, 99999, 99999)
			hrp.RotVelocity = Vector3.new(99999, 99999, 99999)
		end)
	end

	if isOrbitFlingEnabled and selectedPlayer and IsPlayerAlive(selectedPlayer) and not isCurrentlyFlinging then
		orbitAngle = orbitAngle + 0.18
		local targetHrp = selectedPlayer.Character.HumanoidRootPart
		local offset = Vector3.new(math.cos(orbitAngle) * 4, 0, math.sin(orbitAngle) * 4)
		pcall(function()
			hrp.AssemblyAngularVelocity = Vector3.new(0, 999999, 0)
			hrp.CFrame = CFrame.new(targetHrp.Position + offset, targetHrp.Position)
		end)
	end

	if isSitOnPlayer and selectedPlayer and IsPlayerAlive(selectedPlayer) then
		hum.Sit = true
		hrp.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 1.4, 0)
	elseif isHeadSit and selectedPlayer and IsPlayerAlive(selectedPlayer) and selectedPlayer.Character:FindFirstChild("Head") then
		hum.Sit = true
		hrp.CFrame = selectedPlayer.Character.Head.CFrame * CFrame.new(0, 1.2, 0)
	end

	if isChatSpammerEnabled and (tick() - lastChatSpam >= 2.5) then
		lastChatSpam = tick()
		SendChatMessage(spamMessages[spamIndex])
		spamIndex = spamIndex + 1
		if spamIndex > #spamMessages then spamIndex = 1 end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		if isFakeLagEnabled and IsPlayerAlive(player) then
			player.Character.HumanoidRootPart.Anchored = true
			task.wait(0.12)
			if IsPlayerAlive(player) then
				player.Character.HumanoidRootPart.Anchored = false
			end
		end
	end
end)

-- =========================================================================
-- 16. MAIN RUNTIME LOOPS
-- =========================================================================
local lastWarnUpdate = 0
local lastCoinClean = 0

RunService.RenderStepped:Connect(function()
	if isTracersEnabled then UpdateTracers() end
end)

RunService.Heartbeat:Connect(function()
	if isGunEspEnabled then UpdateGunESP() end

	if isWarningEnabled and (tick() - lastWarnUpdate >= 0.2) then
		lastWarnUpdate = tick()
		UpdateProximityWarning()
	end

	if isCoinEspEnabled and (tick() - lastCoinClean >= 2.5) then
		lastCoinClean = tick()
		for coinObj, data in pairs(coinAdornments) do
			if not coinObj or not coinObj.Parent or (data.Part and data.Part.Transparency >= 0.95) then
				RemoveCoinAdornment(coinObj)
			end
		end
		ScanForCoins()
	end
end)

local frameCount = 0
local lastFpsUpdate = tick()

RunService.RenderStepped:Connect(function()
	frameCount = frameCount + 1
	if tick() - lastFpsUpdate >= 1 then
		fpsValue.Text = tostring(frameCount)
		frameCount = 0
		lastFpsUpdate = tick()

		local netStats = StatsService:FindFirstChild("Network")
		local serverStats = netStats and netStats:FindFirstChild("ServerStatsItem")
		local pingStat = serverStats and serverStats:FindFirstChild("Data Ping")

		if pingStat then
			local pingNum = math.floor(pingStat:GetValue())
			pingValue.Text = tostring(pingNum) .. " ms"
			pingValue.TextColor3 = pingNum > 150 and Color3.fromRGB(240, 75, 75) or Color3.fromRGB(80, 220, 125)
		else
			pingValue.Text = "N/A"
		end
	end
end)

-- Initialize Default Active Page (Home)
local first = categoryPages[1]
currentlyActivePage = first.Page
first.Button.BackgroundTransparency = 0.8
first.Button.BackgroundColor3 = Theme.Accent
first.Icon.ImageColor3 = Theme.TextActive
first.Label.TextColor3 = Theme.TextActive
first.Page.Visible = true

-- =========================================================================
-- 17. CINEMATIC SLIDE & FADE TOGGLE
-- =========================================================================
local isMenuOpen = false
local normalSize = UDim2.new(0.55, 0, 0.78, 0)
local compactStartSize = UDim2.new(0.51, 0, 0.73, 0)

local function ToggleMenu()
	if dragMoved then return end
	isMenuOpen = not isMenuOpen

	if isMenuOpen then
		mainFrame.Size = compactStartSize
		mainFrame.BackgroundTransparency = 1
		mainFrame.Visible = true

		TweenService:Create(mainFrame, TWEEN_MAIN, {
			Size = normalSize,
			BackgroundTransparency = Theme.BackgroundTransparency
		}):Play()
	else
		local closeTween = TweenService:Create(mainFrame, TWEEN_MAIN, {
			Size = compactStartSize,
			BackgroundTransparency = 1
		})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			if not isMenuOpen then mainFrame.Visible = false end
		end)
	end
end

toggleBtn.MouseButton1Click:Connect(ToggleMenu)
closeBtn.MouseButton1Click:Connect(function()
	dragMoved = false
	ToggleMenu()
end)