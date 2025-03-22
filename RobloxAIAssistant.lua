--[[
    Roblox AI Assistant Plugin
    
    An AI-powered agent that integrates with local LLMs and external APIs
    to enhance game development and provide error management within Roblox Studio.
]]

-- Plugin metadata and initialization
local PluginName = "AI Development Assistant"
local ToolbarName = "AI Tools"
local ButtonName = "AI Assistant"
local ButtonIcon = "rbxassetid://8628705040" -- Replace with appropriate icon ID

local PluginManager = plugin or script:FindFirstAncestorWhichIsA("Plugin")
local ToolbarSettings = {
    Name = ToolbarName
}
local ButtonSettings = {
    Name = ButtonName,
    ToolTip = "Open AI Development Assistant",
    Icon = ButtonIcon
}

-- Create toolbar and button
local toolbar = PluginManager:CreateToolbar(ToolbarSettings.Name)
local button = toolbar:CreateButton(
    ButtonSettings.Name,
    ButtonSettings.ToolTip,
    ButtonSettings.Icon
)

-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local StudioService = game:GetService("StudioService")

-- Plugin widget settings
local DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Right,  -- Initial dock state
    true,   -- Widget is initially enabled
    false,  -- Don't override previous enabled state
    450,    -- Default width
    450,    -- Default height
    300,    -- Minimum width
    200     -- Minimum height
)

-- Create plugin GUI
local widgetGui = PluginManager:CreateDockWidgetPluginGui(
    "AIAssistantWidget",
    DockWidgetPluginGuiInfo
)
widgetGui.Title = PluginName
widgetGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Configuration storage
local pluginSettings = {
    localLLMEndpoint = "",
    openManusKey = "",
    cursorKey = "",
    windsurfKey = "",
    setupComplete = false
}

-- Constants
local CONFIG_KEY = "AIAssistantPluginConfig"
local ERROR_LOG = {}
local MAX_ERROR_LOGS = 100
local isRunning = false
local currentTask = nil

-- UI Colors and styling
local COLORS = {
    background = Color3.fromRGB(30, 30, 30),
    foreground = Color3.fromRGB(45, 45, 45),
    accent = Color3.fromRGB(0, 122, 204),
    text = Color3.fromRGB(240, 240, 240),
    textDim = Color3.fromRGB(180, 180, 180),
    success = Color3.fromRGB(87, 200, 130),
    error = Color3.fromRGB(240, 100, 100),
    warning = Color3.fromRGB(255, 200, 87)
}

-- Load saved configuration
local function loadSettings()
    local success, result = pcall(function()
        local savedSettings = PluginManager:GetSetting(CONFIG_KEY)
        if savedSettings then
            return HttpService:JSONDecode(savedSettings)
        end
        return nil
    end)
    
    if success and result then
        for key, value in pairs(result) do
            pluginSettings[key] = value
        end
    end
end

-- Save configuration
local function saveSettings()
    pcall(function()
        local settingsJSON = HttpService:JSONEncode(pluginSettings)
        PluginManager:SetSetting(CONFIG_KEY, settingsJSON)
    end)
end

-- Initial load of settings
loadSettings()

-- Create UI Elements
local function createUI()
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3 = COLORS.background
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = widgetGui
    
    -- Create UI Layout
    local uiPadding = Instance.new("UIPadding")
    uiPadding.PaddingLeft = UDim.new(0, 10)
    uiPadding.PaddingRight = UDim.new(0, 10)
    uiPadding.PaddingTop = UDim.new(0, 10)
    uiPadding.PaddingBottom = UDim.new(0, 10)
    uiPadding.Parent = mainFrame
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundTransparency = 1
    header.Name = "Header"
    header.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 16
    title.TextColor3 = COLORS.text
    title.Text = "AI Development Assistant"
    title.Parent = header
    
    -- Settings button
    local settingsButton = Instance.new("TextButton")
    settingsButton.Size = UDim2.new(0, 80, 0, 30)
    settingsButton.Position = UDim2.new(1, -80, 0, 5)
    settingsButton.BackgroundColor3 = COLORS.foreground
    settingsButton.TextColor3 = COLORS.text
    settingsButton.Text = "Settings"
    settingsButton.Font = Enum.Font.Gotham
    settingsButton.TextSize = 14
    settingsButton.BorderSizePixel = 0
    settingsButton.Parent = header
    
    -- Add rounded corners to settings button
    local cornerSettings = Instance.new("UICorner")
    cornerSettings.CornerRadius = UDim.new(0, 4)
    cornerSettings.Parent = settingsButton
    
    -- Main content frame (tabbed interface)
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, -50)
    contentFrame.Position = UDim2.new(0, 0, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Name = "ContentFrame"
    contentFrame.Parent = mainFrame
    
    -- Tab buttons
    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 0, 30)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Name = "TabFrame"
    tabFrame.Parent = contentFrame
    
    local tabConsole = Instance.new("TextButton")
    tabConsole.Size = UDim2.new(0.33, -2, 1, 0)
    tabConsole.Position = UDim2.new(0, 0, 0, 0)
    tabConsole.BackgroundColor3 = COLORS.accent
    tabConsole.TextColor3 = COLORS.text
    tabConsole.Text = "Console"
    tabConsole.Font = Enum.Font.Gotham
    tabConsole.TextSize = 14
    tabConsole.BorderSizePixel = 0
    tabConsole.Name = "TabConsole"
    tabConsole.Parent = tabFrame
    
    local cornerTabConsole = Instance.new("UICorner")
    cornerTabConsole.CornerRadius = UDim.new(0, 4)
    cornerTabConsole.Parent = tabConsole
    
    local tabErrors = Instance.new("TextButton")
    tabErrors.Size = UDim2.new(0.33, -2, 1, 0)
    tabErrors.Position = UDim2.new(0.33, 1, 0, 0)
    tabErrors.BackgroundColor3 = COLORS.foreground
    tabErrors.TextColor3 = COLORS.textDim
    tabErrors.Text = "Errors"
    tabErrors.Font = Enum.Font.Gotham
    tabErrors.TextSize = 14
    tabErrors.BorderSizePixel = 0
    tabErrors.Name = "TabErrors"
    tabErrors.Parent = tabFrame
    
    local cornerTabErrors = Instance.new("UICorner")
    cornerTabErrors.CornerRadius = UDim.new(0, 4)
    cornerTabErrors.Parent = tabErrors
    
    local tabHelp = Instance.new("TextButton")
    tabHelp.Size = UDim2.new(0.33, -2, 1, 0)
    tabHelp.Position = UDim2.new(0.66, 2, 0, 0)
    tabHelp.BackgroundColor3 = COLORS.foreground
    tabHelp.TextColor3 = COLORS.textDim
    tabHelp.Text = "Help"
    tabHelp.Font = Enum.Font.Gotham
    tabHelp.TextSize = 14
    tabHelp.BorderSizePixel = 0
    tabHelp.Name = "TabHelp"
    tabHelp.Parent = tabFrame
    
    local cornerTabHelp = Instance.new("UICorner")
    cornerTabHelp.CornerRadius = UDim.new(0, 4)
    cornerTabHelp.Parent = tabHelp
    
    -- Tab content containers
    local tabContent = Instance.new("Frame")
    tabContent.Size = UDim2.new(1, 0, 1, -40)
    tabContent.Position = UDim2.new(0, 0, 0, 40)
    tabContent.BackgroundTransparency = 1
    tabContent.Name = "TabContent"
    tabContent.Parent = contentFrame
    
    -- Console tab
    local consoleTab = Instance.new("Frame")
    consoleTab.Size = UDim2.new(1, 0, 1, 0)
    consoleTab.BackgroundTransparency = 1
    consoleTab.Visible = true
    consoleTab.Name = "ConsoleTab"
    consoleTab.Parent = tabContent
    
    -- Console output
    local consoleFrame = Instance.new("Frame")
    consoleFrame.Size = UDim2.new(1, 0, 1, -50)
    consoleFrame.BackgroundColor3 = COLORS.foreground
    consoleFrame.BorderSizePixel = 0
    consoleFrame.Name = "ConsoleFrame"
    consoleFrame.Parent = consoleTab
    
    local cornerConsole = Instance.new("UICorner")
    cornerConsole.CornerRadius = UDim.new(0, 4)
    cornerConsole.Parent = consoleFrame
    
    local consoleScrollingFrame = Instance.new("ScrollingFrame")
    consoleScrollingFrame.Size = UDim2.new(1, -10, 1, -10)
    consoleScrollingFrame.Position = UDim2.new(0, 5, 0, 5)
    consoleScrollingFrame.BackgroundTransparency = 1
    consoleScrollingFrame.BorderSizePixel = 0
    consoleScrollingFrame.ScrollBarThickness = 6
    consoleScrollingFrame.ScrollBarImageColor3 = COLORS.accent
    consoleScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    consoleScrollingFrame.Name = "ConsoleOutput"
    consoleScrollingFrame.Parent = consoleFrame
    
    local consoleLayout = Instance.new("UIListLayout")
    consoleLayout.Padding = UDim.new(0, 4)
    consoleLayout.SortOrder = Enum.SortOrder.LayoutOrder
    consoleLayout.Parent = consoleScrollingFrame
    
    -- Input area
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(1, 0, 0, 40)
    inputFrame.Position = UDim2.new(0, 0, 1, -40)
    inputFrame.BackgroundColor3 = COLORS.foreground
    inputFrame.BorderSizePixel = 0
    inputFrame.Name = "InputFrame"
    inputFrame.Parent = consoleTab
    
    local cornerInput = Instance.new("UICorner")
    cornerInput.CornerRadius = UDim.new(0, 4)
    cornerInput.Parent = inputFrame
    
    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -90, 1, -10)
    inputBox.Position = UDim2.new(0, 5, 0, 5)
    inputBox.BackgroundColor3 = COLORS.background
    inputBox.TextColor3 = COLORS.text
    inputBox.PlaceholderText = "Ask AI for help..."
    inputBox.PlaceholderColor3 = COLORS.textDim
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 14
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false
    inputBox.BorderSizePixel = 0
    inputBox.Name = "InputBox"
    inputBox.Parent = inputFrame
    
    local cornerInputBox = Instance.new("UICorner")
    cornerInputBox.CornerRadius = UDim.new(0, 4)
    cornerInputBox.Parent = inputBox
    
    -- Input padding
    local inputPadding = Instance.new("UIPadding")
    inputPadding.PaddingLeft = UDim.new(0, 10)
    inputPadding.PaddingRight = UDim.new(0, 10)
    inputPadding.Parent = inputBox
    
    local sendButton = Instance.new("TextButton")
    sendButton.Size = UDim2.new(0, 70, 1, -10)
    sendButton.Position = UDim2.new(1, -75, 0, 5)
    sendButton.BackgroundColor3 = COLORS.accent
    sendButton.TextColor3 = COLORS.text
    sendButton.Text = "Send"
    sendButton.Font = Enum.Font.GothamBold
    sendButton.TextSize = 14
    sendButton.BorderSizePixel = 0
    sendButton.Name = "SendButton"
    sendButton.Parent = inputFrame
    
    local cornerSendButton = Instance.new("UICorner")
    cornerSendButton.CornerRadius = UDim.new(0, 4)
    cornerSendButton.Parent = sendButton
    
    -- Errors tab
    local errorsTab = Instance.new("Frame")
    errorsTab.Size = UDim2.new(1, 0, 1, 0)
    errorsTab.BackgroundTransparency = 1
    errorsTab.Visible = false
    errorsTab.Name = "ErrorsTab"
    errorsTab.Parent = tabContent
    
    local errorScrollingFrame = Instance.new("ScrollingFrame")
    errorScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
    errorScrollingFrame.BackgroundColor3 = COLORS.foreground
    errorScrollingFrame.BorderSizePixel = 0
    errorScrollingFrame.ScrollBarThickness = 6
    errorScrollingFrame.ScrollBarImageColor3 = COLORS.accent
    errorScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    errorScrollingFrame.Name = "ErrorList"
    errorScrollingFrame.Parent = errorsTab
    
    local cornerErrorFrame = Instance.new("UICorner")
    cornerErrorFrame.CornerRadius = UDim.new(0, 4)
    cornerErrorFrame.Parent = errorScrollingFrame
    
    local errorLayout = Instance.new("UIListLayout")
    errorLayout.Padding = UDim.new(0, 4)
    errorLayout.SortOrder = Enum.SortOrder.LayoutOrder
    errorLayout.Parent = errorScrollingFrame
    
    local errorPadding = Instance.new("UIPadding")
    errorPadding.PaddingTop = UDim.new(0, 5)
    errorPadding.PaddingBottom = UDim.new(0, 5)
    errorPadding.PaddingLeft = UDim.new(0, 5)
    errorPadding.PaddingRight = UDim.new(0, 5)
    errorPadding.Parent = errorScrollingFrame
    
    -- Help tab
    local helpTab = Instance.new("Frame")
    helpTab.Size = UDim2.new(1, 0, 1, 0)
    helpTab.BackgroundTransparency = 1
    helpTab.Visible = false
    helpTab.Name = "HelpTab"
    helpTab.Parent = tabContent
    
    local helpScrollingFrame = Instance.new("ScrollingFrame")
    helpScrollingFrame.Size = UDim2.new(1, 0, 1, 0)
    helpScrollingFrame.BackgroundColor3 = COLORS.foreground
    helpScrollingFrame.BorderSizePixel = 0
    helpScrollingFrame.ScrollBarThickness = 6
    helpScrollingFrame.ScrollBarImageColor3 = COLORS.accent
    helpScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    helpScrollingFrame.Name = "HelpContent"
    helpScrollingFrame.Parent = helpTab
    
    local cornerHelpFrame = Instance.new("UICorner")
    cornerHelpFrame.CornerRadius = UDim.new(0, 4)
    cornerHelpFrame.Parent = helpScrollingFrame
    
    local helpPadding = Instance.new("UIPadding")
    helpPadding.PaddingTop = UDim.new(0, 10)
    helpPadding.PaddingBottom = UDim.new(0, 10)
    helpPadding.PaddingLeft = UDim.new(0, 10)
    helpPadding.PaddingRight = UDim.new(0, 10)
    helpPadding.Parent = helpScrollingFrame
    
    local helpLayout = Instance.new("UIListLayout")
    helpLayout.Padding = UDim.new(0, 10)
    helpLayout.SortOrder = Enum.SortOrder.LayoutOrder
    helpLayout.Parent = helpScrollingFrame
    
    -- Help content
    local helpTitle = Instance.new("TextLabel")
    helpTitle.Size = UDim2.new(1, 0, 0, 30)
    helpTitle.BackgroundTransparency = 1
    helpTitle.TextColor3 = COLORS.text
    helpTitle.Font = Enum.Font.GothamBold
    helpTitle.TextSize = 18
    helpTitle.TextXAlignment = Enum.TextXAlignment.Left
    helpTitle.Text = "AI Development Assistant Help"
    helpTitle.LayoutOrder = 1
    helpTitle.Parent = helpScrollingFrame
    
    local helpDescription = Instance.new("TextLabel")
    helpDescription.Size = UDim2.new(1, 0, 0, 60)
    helpDescription.BackgroundTransparency = 1
    helpDescription.TextColor3 = COLORS.textDim
    helpDescription.Font = Enum.Font.Gotham
    helpDescription.TextSize = 14
    helpDescription.TextXAlignment = Enum.TextXAlignment.Left
    helpDescription.TextYAlignment = Enum.TextYAlignment.Top
    helpDescription.TextWrapped = true
    helpDescription.Text = "This plugin uses AI to assist with game development tasks. It can help write code, fix errors, and provide development advice."
    helpDescription.LayoutOrder = 2
    helpDescription.Parent = helpScrollingFrame
    
    local helpSubtitle1 = Instance.new("TextLabel")
    helpSubtitle1.Size = UDim2.new(1, 0, 0, 25)
    helpSubtitle1.BackgroundTransparency = 1
    helpSubtitle1.TextColor3 = COLORS.text
    helpSubtitle1.Font = Enum.Font.GothamSemibold
    helpSubtitle1.TextSize = 16
    helpSubtitle1.TextXAlignment = Enum.TextXAlignment.Left
    helpSubtitle1.Text = "Setup"
    helpSubtitle1.LayoutOrder = 3
    helpSubtitle1.Parent = helpScrollingFrame
    
    local helpSetup = Instance.new("TextLabel")
    helpSetup.Size = UDim2.new(1, 0, 0, 80)
    helpSetup.BackgroundTransparency = 1
    helpSetup.TextColor3 = COLORS.textDim
    helpSetup.Font = Enum.Font.Gotham
    helpSetup.TextSize = 14
    helpSetup.TextXAlignment = Enum.TextXAlignment.Left
    helpSetup.TextYAlignment = Enum.TextYAlignment.Top
    helpSetup.TextWrapped = true
    helpSetup.Text = "1. Click the 'Settings' button to configure API endpoints\n2. Enter your local LLM endpoint (e.g., Ollama)\n3. Add any API keys for external services\n4. Save your settings"
    helpSetup.LayoutOrder = 4
    helpSetup.Parent = helpScrollingFrame
    
    local helpSubtitle2 = Instance.new("TextLabel")
    helpSubtitle2.Size = UDim2.new(1, 0, 0, 25)
    helpSubtitle2.BackgroundTransparency = 1
    helpSubtitle2.TextColor3 = COLORS.text
    helpSubtitle2.Font = Enum.Font.GothamSemibold
    helpSubtitle2.TextSize = 16
    helpSubtitle2.TextXAlignment = Enum.TextXAlignment.Left
    helpSubtitle2.Text = "Using the AI"
    helpSubtitle2.LayoutOrder = 5
    helpSubtitle2.Parent = helpScrollingFrame
    
    local helpUsage = Instance.new("TextLabel")
    helpUsage.Size = UDim2.new(1, 0, 0, 120)
    helpUsage.BackgroundTransparency = 1
    helpUsage.TextColor3 = COLORS.textDim
    helpUsage.Font = Enum.Font.Gotham
    helpUsage.TextSize = 14
    helpUsage.TextXAlignment = Enum.TextXAlignment.Left
    helpUsage.TextYAlignment = Enum.TextYAlignment.Top
    helpUsage.TextWrapped = true
    helpUsage.Text = "- Type your request in the console input box\n- Ask for help with code, error fixes, or game mechanics\n- The AI can write scripts directly into your game\n- View and manage errors in the Errors tab\n- The AI will automatically detect and suggest fixes for runtime errors"
    helpUsage.LayoutOrder = 6
    helpUsage.Parent = helpScrollingFrame
    
    local helpDocButton = Instance.new("TextButton")
    helpDocButton.Size = UDim2.new(1, 0, 0, 40)
    helpDocButton.BackgroundColor3 = COLORS.accent
    helpDocButton.TextColor3 = COLORS.text
    helpDocButton.Text = "View Full Documentation Online"
    helpDocButton.Font = Enum.Font.GothamBold
    helpDocButton.TextSize = 14
    helpDocButton.BorderSizePixel = 0
    helpDocButton.LayoutOrder = 7
    helpDocButton.Parent = helpScrollingFrame
    
    local cornerHelpButton = Instance.new("UICorner")
    cornerHelpButton.CornerRadius = UDim.new(0, 4)
    cornerHelpButton.Parent = helpDocButton
    
    -- Settings panel (hidden initially)
    local settingsPanel = Instance.new("Frame")
    settingsPanel.Size = UDim2.new(1, 0, 1, 0)
    settingsPanel.BackgroundColor3 = COLORS.background
    settingsPanel.Visible = false
    settingsPanel.ZIndex = 10
    settingsPanel.Name = "SettingsPanel"
    settingsPanel.Parent = mainFrame
    
    local settingsTitle = Instance.new("TextLabel")
    settingsTitle.Size = UDim2.new(1, 0, 0, 30)
    settingsTitle.BackgroundTransparency = 1
    settingsTitle.TextColor3 = COLORS.text
    settingsTitle.Font = Enum.Font.GothamBold
    settingsTitle.TextSize = 18
    settingsTitle.Text = "Settings"
    settingsTitle.ZIndex = 10
    settingsTitle.Parent = settingsPanel
    
    local settingsContent = Instance.new("ScrollingFrame")
    settingsContent.Size = UDim2.new(1, 0, 1, -90)
    settingsContent.Position = UDim2.new(0, 0, 0, 40)
    settingsContent.BackgroundTransparency = 1
    settingsContent.BorderSizePixel = 0
    settingsContent.ScrollBarThickness = 6
    settingsContent.ScrollBarImageColor3 = COLORS.accent
    settingsContent.ZIndex = 10
    settingsContent.Name = "SettingsContent"
    settingsContent.Parent = settingsPanel
    
    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 15)
    settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    settingsLayout.Parent = settingsContent
    
    local settingsPadding = Instance.new("UIPadding")
    settingsPadding.PaddingTop = UDim.new(0, 5)
    settingsPadding.PaddingBottom = UDim.new(0, 5)
    settingsPadding.PaddingLeft = UDim.new(0, 5)
    settingsPadding.PaddingRight = UDim.new(0, 5)
    settingsPadding.Parent = settingsContent
    
    -- Settings fields
    local function createSettingField(name, description, configKey, layoutOrder)
        local setting = Instance.new("Frame")
        setting.Size = UDim2.new(1, 0, 0, 70)
        setting.BackgroundTransparency = 1
        setting.LayoutOrder = layoutOrder
        setting.Name = name
        setting.ZIndex = 10
        setting.Parent = settingsContent
        
        local settingLabel = Instance.new("TextLabel")
        settingLabel.Size = UDim2.new(1, 0, 0, 20)
        settingLabel.BackgroundTransparency = 1
        settingLabel.TextColor3 = COLORS.text
        settingLabel.Font = Enum.Font.GothamSemibold
        settingLabel.TextSize = 14
        settingLabel.TextXAlignment = Enum.TextXAlignment.Left
        settingLabel.Text = name
        settingLabel.ZIndex = 10
        settingLabel.Parent = setting
        
        local settingDescription = Instance.new("TextLabel")
        settingDescription.Size = UDim2.new(1, 0, 0, 20)
        settingDescription.Position = UDim2.new(0, 0, 0, 20)
        settingDescription.BackgroundTransparency = 1
        settingDescription.TextColor3 = COLORS.textDim
        settingDescription.Font = Enum.Font.Gotham
        settingDescription.TextSize = 12
        settingDescription.TextXAlignment = Enum.TextXAlignment.Left
        settingDescription.Text = description
        settingDescription.ZIndex = 10
        settingDescription.Parent = setting
        
        local settingInput = Instance.new("TextBox")
        settingInput.Size = UDim2.new(1, 0, 0, 30)
        settingInput.Position = UDim2.new(0, 0, 0, 40)
        settingInput.BackgroundColor3 = COLORS.foreground
        settingInput.TextColor3 = COLORS.text
        settingInput.PlaceholderText = "Enter " .. string.lower(name)
        settingInput.PlaceholderColor3 = COLORS.textDim
        settingInput.Font = Enum.Font.Gotham
        settingInput.TextSize = 14
        settingInput.TextXAlignment = Enum.TextXAlignment.Left
        settingInput.ClearTextOnFocus = false
        settingInput.BorderSizePixel = 0
        settingInput.Name = configKey
        settingInput.Text = pluginSettings[configKey] or ""
        settingInput.ZIndex = 10
        settingInput.Parent = setting
        
        local cornerSettingInput = Instance.new("UICorner")
        cornerSettingInput.CornerRadius = UDim.new(0, 4)
        cornerSettingInput.Parent = settingInput
        
        local inputPadding = Instance.new("UIPadding")
        inputPadding.PaddingLeft = UDim.new(0, 10)
        inputPadding.PaddingRight = UDim.new(0, 10)
        inputPadding.Parent = settingInput
        
        return settingInput
    end
    
    -- Create settings fields
    local llmEndpointInput = createSettingField(
        "Local LLM Endpoint", 
        "URL for your locally hosted LLM (e.g., Ollama)", 
        "localLLMEndpoint",
        1
    )
    
    local openManusInput = createSettingField(
        "OpenManus API Key", 
        "API key for OpenManus integration (optional)", 
        "openManusKey",
        2
    )
    
    local cursorInput = createSettingField(
        "Cursor API Key", 
        "API key for Cursor integration (optional)", 
        "cursorKey",
        3
    )
    
    local windsurfInput = createSettingField(
        "Windsurf API Key", 
        "API key for Windsurf integration (optional)", 
        "windsurfKey",
        4
    )
    
    -- Settings buttons
    local settingsButtonFrame = Instance.new("Frame")
    settingsButtonFrame.Size = UDim2.new(1, 0, 0, 40)
    settingsButtonFrame.Position = UDim2.new(0, 0, 1, -40)
    settingsButtonFrame.BackgroundTransparency = 1
    settingsButtonFrame.ZIndex = 10
    settingsButtonFrame.Parent = settingsPanel
    
    local saveButton = Instance.new("TextButton")
    saveButton.Size = UDim2.new(0.48, 0, 1, 0)
    saveButton.Position = UDim2.new(0, 0, 0, 0)
    saveButton.BackgroundColor3 = COLORS.accent
    saveButton.TextColor3 = COLORS.text
    saveButton.Text = "Save Settings"
    saveButton.Font = Enum.Font.GothamBold
    saveButton.TextSize = 14
    saveButton.BorderSizePixel = 0
    saveButton.ZIndex = 10
    saveButton.Parent = settingsButtonFrame
    
    local cornerSaveButton = Instance.new("UICorner")
    cornerSaveButton.CornerRadius = UDim.new(0, 4)
    cornerSaveButton.Parent = saveButton
    
    local cancelButton = Instance.new("TextButton")
    cancelButton.Size = UDim2.new(0.48, 0, 1, 0)
    cancelButton.Position = UDim2.new(0.52, 0, 0, 0)
    cancelButton.BackgroundColor3 = COLORS.foreground
    cancelButton.TextColor3 = COLORS.textDim
    cancelButton.Text = "Cancel"
    cancelButton.Font = Enum.Font.GothamBold
    cancelButton.TextSize = 14
    cancelButton.BorderSizePixel = 0
    cancelButton.ZIndex = 10
    cancelButton.Parent = settingsButtonFrame
    
    local cornerCancelButton = Instance.new("UICorner")
    cornerCancelButton.CornerRadius = UDim.new(0, 4)
    cornerCancelButton.Parent = cancelButton
    
    -- Setup Panel (shown on first use)
    local setupPanel = Instance.new("Frame")
    setupPanel.Size = UDim2.new(1, 0, 1, 0)
    setupPanel.BackgroundColor3 = COLORS.background
    setupPanel.Visible = not pluginSettings.setupComplete
    setupPanel.ZIndex = 20
    setupPanel.Name = "SetupPanel"
    setupPanel.Parent = mainFrame
    
    local setupTitle = Instance.new("TextLabel")
    setupTitle.Size = UDim2.new(1, 0, 0, 30)
    setupTitle.BackgroundTransparency = 1
    setupTitle.TextColor3 = COLORS.text
    setupTitle.Font = Enum.Font.GothamBold
    setupTitle.TextSize = 18
    setupTitle.Text = "Welcome to AI Development Assistant!"
    setupTitle.ZIndex = 20
    setupTitle.Parent = setupPanel
    
    local setupDescription = Instance.new("TextLabel")
    setupDescription.Size = UDim2.new(1, 0, 0, 60)
    setupDescription.Position = UDim2.new(0, 0, 0, 40)
    setupDescription.BackgroundTransparency = 1
    setupDescription.TextColor3 = COLORS.textDim
    setupDescription.Font = Enum.Font.Gotham
    setupDescription.TextSize = 14
    setupDescription.TextWrapped = true
    setupDescription.Text = "This plugin helps you develop games using AI assistance. To get started, you'll need to configure at least one AI service."
    setupDescription.ZIndex = 20
    setupDescription.Parent = setupPanel
    
    local setupButton = Instance.new("TextButton")
    setupButton.Size = UDim2.new(0.6, 0, 0, 40)
    setupButton.Position = UDim2.new(0.2, 0, 0, 120)
    setupButton.BackgroundColor3 = COLORS.accent
    setupButton.TextColor3 = COLORS.text
    setupButton.Text = "Configure AI Services"
    setupButton.Font = Enum.Font.GothamBold
    setupButton.TextSize = 14
    setupButton.BorderSizePixel = 0
    setupButton.ZIndex = 20
    setupButton.Parent = setupPanel
    
    local cornerSetupButton = Instance.new("UICorner")
    cornerSetupButton.CornerRadius = UDim.new(0, 4)
    cornerSetupButton.Parent = setupButton
    
    return {
        consoleOutput = consoleScrollingFrame,
        errorList = errorScrollingFrame,
        inputBox = inputBox,
        sendButton = sendButton,
        tabConsole = tabConsole,
        tabErrors = tabErrors,
        tabHelp = tabHelp,
        consoleTab = consoleTab,
        errorsTab = errorsTab,
        helpTab = helpTab,
        settingsButton = settingsButton,
        settingsPanel = settingsPanel,
        saveButton = saveButton,
        cancelButton = cancelButton,
        setupButton = setupButton,
        setupPanel = setupPanel,
        helpDocButton = helpDocButton,
        llmEndpointInput = llmEndpointInput,
        openManusInput = openManusInput,
        cursorInput = cursorInput,
        windsurfInput = windsurfInput
    }
end

-- Log entry creation
local function createLogEntry(container, text, type)
    local colors = {
        info = COLORS.text,
        success = COLORS.success,
        error = COLORS.error,
        warning = COLORS.warning,
        ai = COLORS.accent
    }
    
    local entry = Instance.new("TextLabel")
    entry.Size = UDim2.new(1, 0, 0, 0)
    entry.AutomaticSize = Enum.AutomaticSize.Y
    entry.BackgroundTransparency = 1
    entry.TextColor3 = colors[type] or COLORS.text
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.TextYAlignment = Enum.TextYAlignment.Top
    entry.TextWrapped = true
    entry.Font = Enum.Font.Code
    entry.TextSize = 14
    entry.Text = type == "ai" and "🤖 " .. text or text
    entry.Parent = container
    
    -- Adjust scrolling frame canvas size
    container.CanvasSize = UDim2.new(0, 0, 0, container.UIListLayout.AbsoluteContentSize.Y)
    
    -- Auto-scroll to bottom
    container.CanvasPosition = Vector2.new(0, container.CanvasSize.Y.Offset)
    
    return entry
end

-- Error entry creation
local function createErrorEntry(container, errorData)
    local errorFrame = Instance.new("Frame")
    errorFrame.Size = UDim2.new(1, 0, 0, 80)
    errorFrame.BackgroundColor3 = COLORS.background
    errorFrame.BorderSizePixel = 0
    errorFrame.Parent = container
    
    local cornerError = Instance.new("UICorner")
    cornerError.CornerRadius = UDim.new(0, 4)
    cornerError.Parent = errorFrame
    
    local errorTitle = Instance.new("TextLabel")
    errorTitle.Size = UDim2.new(1, -10, 0, 20)
    errorTitle.Position = UDim2.new(0, 10, 0, 5)
    errorTitle.BackgroundTransparency = 1
    errorTitle.TextColor3 = COLORS.error
    errorTitle.Font = Enum.Font.GothamBold
    errorTitle.TextSize = 14
    errorTitle.TextXAlignment = Enum.TextXAlignment.Left
    errorTitle.Text = errorData.message or "Error"
    errorTitle.Parent = errorFrame
    
    local errorLocation = Instance.new("TextLabel")
    errorLocation.Size = UDim2.new(1, -10, 0, 15)
    errorLocation.Position = UDim2.new(0, 10, 0, 25)
    errorLocation.BackgroundTransparency = 1
    errorLocation.TextColor3 = COLORS.textDim
    errorLocation.Font = Enum.Font.Gotham
    errorLocation.TextSize = 12
    errorLocation.TextXAlignment = Enum.TextXAlignment.Left
    errorLocation.Text = (errorData.script or "Unknown") .. " (Line " .. (errorData.line or "?") .. ")"
    errorLocation.Parent = errorFrame
    
    local errorTimestamp = Instance.new("TextLabel")
    errorTimestamp.Size = UDim2.new(1, -10, 0, 15)
    errorTimestamp.Position = UDim2.new(0, 10, 0, 40)
    errorTimestamp.BackgroundTransparency = 1
    errorTimestamp.TextColor3 = COLORS.textDim
    errorTimestamp.Font = Enum.Font.Gotham
    errorTimestamp.TextSize = 12
    errorTimestamp.TextXAlignment = Enum.TextXAlignment.Left
    errorTimestamp.Text = "Timestamp: " .. os.date("%H:%M:%S")
    errorTimestamp.Parent = errorFrame
    
    local fixButton = Instance.new("TextButton")
    fixButton.Size = UDim2.new(0, 80, 0, 25)
    fixButton.Position = UDim2.new(1, -90, 0, 10)
    fixButton.BackgroundColor3 = COLORS.accent
    fixButton.TextColor3 = COLORS.text
    fixButton.Text = "Fix It"
    fixButton.Font = Enum.Font.GothamBold
    fixButton.TextSize = 12
    fixButton.BorderSizePixel = 0
    fixButton.Name = "FixButton"
    fixButton.Parent = errorFrame
    
    local cornerFixButton = Instance.new("UICorner")
    cornerFixButton.CornerRadius = UDim.new(0, 4)
    cornerFixButton.Parent = fixButton
    
    -- Store error data
    errorFrame:SetAttribute("ErrorData", HttpService:JSONEncode(errorData))
    
    -- Adjust scrolling frame canvas size
    container.CanvasSize = UDim2.new(0, 0, 0, container.UIListLayout.AbsoluteContentSize.Y)
    
    return errorFrame
end

-- API Interaction
local function callAI(prompt, context, ui)
    currentTask = {
        prompt = prompt,
        context = context
    }
    
    createLogEntry(ui.consoleOutput, "You: " .. prompt, "info")
    createLogEntry(ui.consoleOutput, "Processing request...", "info")
    
    -- Attempt to call local LLM first
    local success, response = pcall(function()
        -- Build the complete prompt
        local fullPrompt = [[
            You are an AI assistant integrated into Roblox Studio as a plugin.
            You're specialized in game development within the Roblox environment.
            
            Current context:
            - Platform: Roblox Studio
            - Mode: ]] .. (RunService:IsRunning() and "Runtime" or "Edit") .. [[
            
            Additional context: ]] .. (context or "None") .. [[
            
            When accessing any Roblox.com website, use roproxy.com instead.
            
            User request: ]] .. prompt
        
        -- Call the local LLM API
        if pluginSettings.localLLMEndpoint and pluginSettings.localLLMEndpoint ~= "" then
            local response = HttpService:RequestAsync({
                Url = pluginSettings.localLLMEndpoint,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode({
                    prompt = fullPrompt,
                    model = "codellama:latest", -- Default model for code
                    stream = false,
                    max_tokens = 2048
                })
            })
            
            if response.Success then
                local responseData = HttpService:JSONDecode(response.Body)
                return responseData.response or responseData.choices[0].text or "No response from AI"
            else
                error("Local LLM request failed: " .. response.StatusMessage)
            end
        else
            error("No local LLM endpoint configured")
        end
    end)
    
    -- If local LLM fails, try external APIs
    if not success then
        -- Try external APIs in order of preference
        local apiKeys = {
            { name = "OpenManus", key = pluginSettings.openManusKey },
            { name = "Cursor", key = pluginSettings.cursorKey },
            { name = "Windsurf", key = pluginSettings.windsurfKey }
        }
        
        for _, api in ipairs(apiKeys) do
            if api.key and api.key ~= "" then
                local success, response = pcall(function()
                    -- This is a stub for external API integration
                    -- In a real implementation, this would call the specific API
                    return "Response from " .. api.name .. " API"
                end)
                
                if success then
                    createLogEntry(ui.consoleOutput, response, "ai")
                    currentTask = nil
                    return response
                end
            end
        end
        
        -- All APIs failed
        createLogEntry(ui.consoleOutput, "Error: Unable to connect to any AI service. Please check your settings.", "error")
        currentTask = nil
        return nil
    else
        createLogEntry(ui.consoleOutput, response, "ai")
        currentTask = nil
        return response
    end
end

-- Code Execution
local function executeCode(code, ui)
    createLogEntry(ui.consoleOutput, "Executing code...", "info")
    
    local success, result = pcall(function()
        -- Create a new ModuleScript to run the code
        local codeModule = Instance.new("ModuleScript")
        codeModule.Name = "AIGeneratedCode"
        codeModule.Source = code
        codeModule.Parent = game:GetService("ServerStorage")
        
        -- Load and execute the module
        local loadedModule = require(codeModule)
        
        -- Clean up
        codeModule:Destroy()
        
        return loadedModule
    end)
    
    if success then
        createLogEntry(ui.consoleOutput, "Code executed successfully!", "success")
        return result
    else
        createLogEntry(ui.consoleOutput, "Error executing code: " .. tostring(result), "error")
        return nil
    end
end

-- Script Creation/Modification
local function createOrUpdateScript(scriptType, name, code, parent)
    parent = parent or game:GetService("ServerScriptService")
    
    -- Check if script already exists
    local existingScript = parent:FindFirstChild(name)
    
    if existingScript and existingScript:IsA(scriptType) then
        -- Update existing script
        existingScript.Source = code
        return existingScript, false
    else
        -- Create new script
        local newScript
        if scriptType == "Script" then
            newScript = Instance.new("Script")
        elseif scriptType == "LocalScript" then
            newScript = Instance.new("LocalScript")
        elseif scriptType == "ModuleScript" then
            newScript = Instance.new("ModuleScript")
        else
            error("Invalid script type: " .. scriptType)
        end
        
        newScript.Name = name
        newScript.Source = code
        newScript.Parent = parent
        
        return newScript, true
    end
end

-- Error Handling
local function setupErrorHandling(ui)
    -- Track script errors
    local function onScriptError(message, trace, script)
        -- Parse error information
        local errorInfo = {
            message = message,
            trace = trace,
            script = script and script.Name or "Unknown Script",
            scriptPath = script and script:GetFullName() or "Unknown Path",
            line = trace:match("line (%d+)")
        }
        
        -- Add to error log
        table.insert(ERROR_LOG, errorInfo)
        if #ERROR_LOG > MAX_ERROR_LOGS then
            table.remove(ERROR_LOG, 1)
        end
        
        -- Create UI entry for error
        createErrorEntry(ui.errorList, errorInfo)
        
        return false -- Allow normal error handling to continue
    end
    
    ScriptContext = game:GetService("ScriptContext")
    ScriptContext.Error:Connect(onScriptError)
end

-- UI Event Handling
local function setupUIEvents(ui)
    -- Tab switching
    ui.tabConsole.MouseButton1Click:Connect(function()
        ui.consoleTab.Visible = true
        ui.errorsTab.Visible = false
        ui.helpTab.Visible = false
        
        ui.tabConsole.BackgroundColor3 = COLORS.accent
        ui.tabConsole.TextColor3 = COLORS.text
        ui.tabErrors.BackgroundColor3 = COLORS.foreground
        ui.tabErrors.TextColor3 = COLORS.textDim
        ui.tabHelp.BackgroundColor3 = COLORS.foreground
        ui.tabHelp.TextColor3 = COLORS.textDim
    end)
    
    ui.tabErrors.MouseButton1Click:Connect(function()
        ui.consoleTab.Visible = false
        ui.errorsTab.Visible = true
        ui.helpTab.Visible = false
        
        ui.tabConsole.BackgroundColor3 = COLORS.foreground
        ui.tabConsole.TextColor3 = COLORS.textDim
        ui.tabErrors.BackgroundColor3 = COLORS.accent
        ui.tabErrors.TextColor3 = COLORS.text
        ui.tabHelp.BackgroundColor3 = COLORS.foreground
        ui.tabHelp.TextColor3 = COLORS.textDim
    end)
    
    ui.tabHelp.MouseButton1Click:Connect(function()
        ui.consoleTab.Visible = false
        ui.errorsTab.Visible = false
        ui.helpTab.Visible = true
        
        ui.tabConsole.BackgroundColor3 = COLORS.foreground
        ui.tabConsole.TextColor3 = COLORS.textDim
        ui.tabErrors.BackgroundColor3 = COLORS.foreground
        ui.tabErrors.TextColor3 = COLORS.textDim
        ui.tabHelp.BackgroundColor3 = COLORS.accent
        ui.tabHelp.TextColor3 = COLORS.text
    end)
    
    -- Console input
    local function processInput()
        local input = ui.inputBox.Text
        if input and input ~= "" then
            -- Clear input field
            ui.inputBox.Text = ""
            
            -- Get selection context
            local selectionContext = ""
            local selectedObjects = Selection:Get()
            if #selectedObjects > 0 then
                selectionContext = "Selected objects: "
                for i, obj in ipairs(selectedObjects) do
                    selectionContext = selectionContext .. obj.Name .. " (" .. obj.ClassName .. ")"
                    if i < #selectedObjects then
                        selectionContext = selectionContext .. ", "
                    end
                end
            end
            
            -- Call AI with input
            callAI(input, selectionContext, ui)
        end
    end
    
    ui.sendButton.MouseButton1Click:Connect(processInput)
    ui.inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            processInput()
        end
    end)
    
    -- Settings panel
    ui.settingsButton.MouseButton1Click:Connect(function()
        ui.settingsPanel.Visible = true
    end)
    
    ui.cancelButton.MouseButton1Click:Connect(function()
        ui.settingsPanel.Visible = false
    end)
    
    ui.saveButton.MouseButton1Click:Connect(function()
        -- Update settings
        pluginSettings.localLLMEndpoint = ui.llmEndpointInput.Text
        pluginSettings.openManusKey = ui.openManusInput.Text
        pluginSettings.cursorKey = ui.cursorInput.Text
        pluginSettings.windsurfKey = ui.windsurfKey.Text
        pluginSettings.setupComplete = true
        
        -- Save settings
        saveSettings()
        
        -- Hide panels
        ui.settingsPanel.Visible = false
        ui.setupPanel.Visible = false
        
        createLogEntry(ui.consoleOutput, "Settings saved successfully!", "success")
    end)
    
    -- Setup panel
    ui.setupButton.MouseButton1Click:Connect(function()
        ui.setupPanel.Visible = false
        ui.settingsPanel.Visible = true
    end)
    
    -- Help documentation
    ui.helpDocButton.MouseButton1Click:Connect(function()
        -- In a real plugin, this would open a web URL
        createLogEntry(ui.consoleOutput, "Opening documentation website...", "info")
    end)
    
    -- Error fix buttons
    ui.errorList.ChildAdded:Connect(function(child)
        if child:FindFirstChild("FixButton") then
            child.FixButton.MouseButton1Click:Connect(function()
                local errorData = HttpService:JSONDecode(child:GetAttribute("ErrorData"))
                
                -- Switch to console tab
                ui.tabConsole.MouseButton1Click:Connect()
                
                -- Create prompt for AI to fix error
                local prompt = "Fix this error: " .. errorData.message .. 
                               " in script " .. errorData.script .. 
                               " at line " .. (errorData.line or "unknown")
                
                callAI(prompt, "Error context: " .. HttpService:JSONEncode(errorData), ui)
            end)
        end
    end)
end

-- Plugin initialization
local function initializePlugin()
    -- Create UI
    local ui = createUI()
    
    -- Setup event handlers
    setupUIEvents(ui)
    setupErrorHandling(ui)
    
    -- Initial log entry
    createLogEntry(ui.consoleOutput, "AI Development Assistant initialized.", "info")
    createLogEntry(ui.consoleOutput, "Type your request or question in the input box below.", "info")
    
    -- Toggle plugin visibility when toolbar button is clicked
    button.Click:Connect(function()
        widgetGui.Enabled = not widgetGui.Enabled
    end)
    
    -- Connect to ErrorHandling service
    -- This would be more extensive in a full implementation
    game:GetService("LogService").MessageOut:Connect(function(message, messageType)
        if messageType == Enum.MessageType.Error then
            -- Simple error parsing
            local errorInfo = {
                message = message,
                timestamp = os.time()
            }
            
            -- Only add to error list if we're in edit mode or this is a runtime error
            if not RunService:IsRunning() or message:find("Runtime Error:") then
                table.insert(ERROR_LOG, errorInfo)
                if #ERROR_LOG > MAX_ERROR_LOGS then
                    table.remove(ERROR_LOG, 1)
                end
                
                createErrorEntry(ui.errorList, errorInfo)
            end
        end
    end)
    
    -- Handle plugin deactivation
    PluginManager.Deactivation:Connect(function()
        -- Clean up resources if needed
    end)
    
    return ui
end

-- Start the plugin
local ui = initializePlugin()
