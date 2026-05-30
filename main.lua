repeat task.wait() until game:IsLoaded()
if shared.tumbahub then shared.tumbahub:Uninject() end

local tumbahub
local old_loadstring = loadstring
local loadstring = function(...)
	local res, err = old_loadstring(...)
	if err and tumbahub then
		tumbahub:CreateNotification('TumbaHub', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local inputService = cloneref(game:GetService('UserInputService'))
local httpService = cloneref(game:GetService('HttpService'))
local playersService = cloneref(game:GetService('Players'))
local tweenService = cloneref(game:GetService('TweenService'))

-- ========================================================
-- PREMIUM SCRIPT LOADER GUI
-- ========================================================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'TumbaHubLoader'
ScreenGui.Parent = gethui and gethui() or cloneref(game:GetService('CoreGui'))

local MainFrame = Instance.new('Frame')
MainFrame.Name = 'MainFrame'
MainFrame.Size = UDim2.new(0, 360, 0, 40)
MainFrame.Position = UDim2.new(0.5, -180, 0, 15)
MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
MainFrame.BackgroundTransparency = 0.25
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new('UICorner')
UICorner.CornerRadius = UDim.new(0, 6)
UICorner.Parent = MainFrame

local UIStroke = Instance.new('UIStroke')
UIStroke.Color = Color3.fromRGB(60, 60, 65)
UIStroke.Thickness = 1
UIStroke.Parent = MainFrame

local Status = Instance.new('TextLabel')
Status.Size = UDim2.new(1, -60, 1, -4)
Status.Position = UDim2.new(0, 12, 0, 0)
Status.BackgroundTransparency = 1
Status.TextColor3 = Color3.fromRGB(240, 240, 240)
Status.Font = Enum.Font.GothamBold
Status.TextSize = 13
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Text = 'TumbaHub V6 | Connecting...'
Status.Parent = MainFrame

local Percentage = Instance.new('TextLabel')
Percentage.Size = UDim2.new(0, 40, 1, -4)
Percentage.Position = UDim2.new(1, -48, 0, 0)
Percentage.BackgroundTransparency = 1
Percentage.TextColor3 = Color3.fromRGB(240, 240, 240)
Percentage.Font = Enum.Font.GothamBold
Percentage.TextSize = 13
Percentage.TextXAlignment = Enum.TextXAlignment.Right
Percentage.Text = '0%'
Percentage.Parent = MainFrame

local BarContainer = Instance.new('Frame')
BarContainer.Size = UDim2.new(1, -20, 0, 2)
BarContainer.Position = UDim2.new(0, 10, 1, -4)
BarContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
BarContainer.BorderSizePixel = 0
BarContainer.Parent = MainFrame

local ProgressBar = Instance.new('Frame')
ProgressBar.Size = UDim2.new(0, 0, 1, 0)
ProgressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ProgressBar.BorderSizePixel = 0
ProgressBar.Parent = BarContainer

local function updateProgress(percent, statusText)
	Status.Text = 'TumbaHub V6 | ' .. statusText
	Percentage.Text = tostring(math.round(percent)) .. '%'
	tweenService:Create(ProgressBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(percent / 100, 0, 1, 0)
	}):Play()
	task.wait(0.2)
end

local function fadeOutLoader()
	updateProgress(100, 'Loaded successfully!')
	task.wait(0.3)
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tweenService:Create(MainFrame, tweenInfo, {Position = UDim2.new(0.5, -180, 0, -50), BackgroundTransparency = 1}):Play()
	tweenService:Create(Status, tweenInfo, {TextTransparency = 1}):Play()
	tweenService:Create(Percentage, tweenInfo, {TextTransparency = 1}):Play()
	tweenService:Create(BarContainer, tweenInfo, {BackgroundTransparency = 1}):Play()
	tweenService:Create(ProgressBar, tweenInfo, {BackgroundTransparency = 1}):Play()
	tweenService:Create(UIStroke, tweenInfo, {Transparency = 1}):Play()
	task.wait(0.4)
	ScreenGui:Destroy()
end

updateProgress(10, 'Initializing auth token...')

if shared.maintumba then
	shared.maintumba = nil
	task.spawn(function()
		local body = httpService:JSONEncode({
			nonce = httpService:GenerateGUID(false),
			args = {
				invite = {code = 'Jd4R5nzpHt'},
				code = 'Jd4R5nzpHt'
			},
			cmd = 'INVITE_BROWSER'
		})

		for i = 1, 2 do
			task.spawn(function()
				request({
					Method = 'POST',
					Url = 'http://127.0.0.1:6463/rpc?v=1',
					Headers = {
						['Content-Type'] = 'application/json',
						Origin = 'https://discord.com'
					},
					Body = body
				})
			end)
		end
	end)
	playersService:Kick('Your script is outdated, Get new one at discord.gg/tumbascript')
	return
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/TumbaV6/'..readfile('tumbascript/profiles/commit.txt')..'/'..select(1, path:gsub('tumbascript/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after tumbahub updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	tumbahub.Init = nil
	tumbahub:Load()
	fadeOutLoader()

	task.spawn(function()
		repeat
			tumbahub:Save()
			task.wait(10)
		until not tumbahub.Loaded
	end)

	local teleportedServers
	tumbahub:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.TumbaHubIndependent) and tumbahub.AutoTeleport.Enabled then
			teleportedServers = true
			local data = shared.tumbadata or {Key = nil}
			local teleportScript = [[
				if shared.TumbaHubDeveloper then
					shared.tumbadata = {Key = '???'}
					print('yo', shared.tumbadata.Key)
					loadstring(readfile('tumbascript/init.lua'), 'init')()
				else
					loadstring(game:HttpGet('https://api.tumbascript.dev/script?key=???'), 'init')()
				end
			]]
			teleportScript = teleportScript:gsub('???', tostring(data.Key or 'none'))
			if shared.TumbaHubDeveloper then
				teleportScript = 'shared.TumbaHubDeveloper = true\n'..teleportScript
			end
			if shared.TumbaHubCustomProfile then
				teleportScript = 'shared.TumbaHubCustomProfile = "'..shared.TumbaHubCustomProfile..'"\n'..teleportScript
			end
			tumbahub:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not tumbahub.Categories then return end

	-- ── Auto-open TumbaHub Discord server on every launch ──
	task.spawn(function()
		local INVITE_CODE = 'Jd4R5nzpHt'

		-- Method 1: Discord Desktop RPC (opens the app directly)
		local ok = pcall(function()
			local body = httpService:JSONEncode({
				nonce = httpService:GenerateGUID(false),
				args = {
					invite = {code = INVITE_CODE},
					code = INVITE_CODE
				},
				cmd = 'INVITE_BROWSER'
			})
			-- Try both common Discord RPC ports
			for _, port in {6463, 6464, 6465, 6466} do
				task.spawn(function()
					pcall(function()
						request({
							Method = 'POST',
							Url = 'http://127.0.0.1:' .. port .. '/rpc?v=1',
							Headers = {
								['Content-Type'] = 'application/json',
								Origin = 'https://discord.com'
							},
							Body = body
						})
					end)
				end)
			end
		end)

		-- Method 2: setclipboard fallback — copies invite link to clipboard
		-- so user can paste it into Discord even if RPC didn't work
		if setclipboard then
			pcall(function()
				setclipboard('discord.gg/' .. INVITE_CODE)
			end)
		end
	end)
	if tumbahub.Categories.Main.Options['GUI bind indicator'].Enabled then
		if getgenv().tumbarole == 'HWID mismatch' then
			tumbahub:CreateNotification('TumbaHub', 'HWID mismatch, Please go to our server And press reset hwid on script panel', 60, 'alert')
			task.wait(0.5)
		else
			tumbahub:CreateNotification('TumbaHub', 'Authenticated as '.. (getgenv().tumbaname or 'Guest').. ' with ('.. (getgenv().tumbarole or 'Free').. ')', 4, 'info')
			task.wait(4)
		end
		tumbahub:CreateNotification('Finished Loading', not inputService.KeyboardEnabled and tumbahub.TumbaHubButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(tumbahub.Keybind, ' + '):upper()..' to open GUI', 5)
	end
end

if not isfile('tumbascript/profiles/gui.txt') then
	writefile('tumbascript/profiles/gui.txt', 'new')
end
local gui = readfile('tumbascript/profiles/gui.txt')
if gui ~= 'new' and gui ~= 'old' and gui ~= 'rise' then
	gui = 'new'
end

if not isfile('tumbascript/profiles/language.txt') then
	writefile('tumbascript/profiles/language.txt', 'English')
end
local langRaw = readfile('tumbascript/profiles/language.txt') or "English"
shared.TumbaLanguage = langRaw:gsub("\n", ""):gsub("\r", ""):gsub("^%s*(.-)%s*$", "%1")

if not isfolder('tumbascript/assets/'..gui) then
	makefolder('tumbascript/assets/'..gui)
end

updateProgress(35, 'Loading Core GUI components...')
do
	local _pre = getgenv()._tumbaPrecompiled
	local chunk = _pre and _pre['gui']
	if not chunk then
		chunk = loadstring(downloadFile('tumbascript/guis/'..gui..'.lua'), 'gui')
	end
	tumbahub = chunk()
end
shared.tumbahub = tumbahub
shared.vape = tumbahub
_G.tumbahub = tumbahub
getgenv().vape = tumbahub

getgenv().canDebug = not table.find({'Xeno', 'Solara'}, ({identifyexecutor()})[1]) and debug.getconstant and debug.getproto and true or false
if not shared.TumbaHubIndependent then
	updateProgress(65, 'Loading Universal Module definitions...')
	do
		local _pre = getgenv()._tumbaPrecompiled
		local chunk = _pre and _pre['universal']
		if not chunk then
			chunk = loadstring(downloadFile('tumbascript/games/universal.lua'), 'universal')
		end
		if chunk then chunk() end
	end

	local found = false
	local callback = shared.TumbaHubDeveloper and readfile or downloadFile
	
	updateProgress(90, 'Injecting BedWars specific game scripts...')
	for i, v in httpService:JSONDecode(callback('tumbascript/profiles/supported.json')) do
		if found then break; end
		if game.GameId == v.gameid then
			for i2, v2 in v do
				if typeof(v2) == 'table' and table.find(v2.Ids, game.PlaceId) then
					found = true
					tumbahub.Place = v2.Place
					if not isfolder('tumbascript/games/'.. i) then
						makefolder('tumbascript/games/'.. i)
					end
					
					do
						local _pre = getgenv()._tumbaPrecompiled
						local chunk1 = _pre and _pre['bedwars_main']
						local chunk2 = _pre and _pre['bedwars_premium']
						if not chunk1 then
							chunk1 = loadstring(callback('tumbascript/games/'.. i.. '/'.. i2.. '.luau'), tostring(game.PlaceId))
						end
						if not chunk2 then
							chunk2 = loadstring(callback('tumbascript/games/'.. i.. '/premium.luau'), 'paid '.. tostring(game.PlaceId))
						end
						if chunk1 then chunk1(...) end
						if chunk2 then chunk2(...) end
					end
					break
				end
			end
		end
	end

	if not found then
		local suc, res = pcall(function()
			return not shared.TumbaHubDeveloper and game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/TumbaV6/'..readfile('tumbascript/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true) or '404: Not Found'
		end)
		if suc and res ~= '404: Not Found' then
			loadstring(downloadFile('tumbascript/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
		end
	end
	
	finishLoading()
else
	tumbahub.Init = finishLoading
	return tumbahub
end