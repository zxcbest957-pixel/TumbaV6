--!nocheck
shared.tumbadata = ... or {}
shared.tumbadata.Key = script_key
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

local downloader = Instance.new('TextLabel')
downloader.Size = UDim2.new(1, 0, 0, 40)
downloader.BackgroundTransparency = 1
downloader.TextStrokeTransparency = 0
downloader.TextSize = 20
downloader.TextColor3 = Color3.new(1, 1, 1)
downloader.Font = Enum.Font.Arial
downloader.Text = ''
downloader.Parent = Instance.new('ScreenGui', gethui and gethui() or game:GetService('CoreGui'))

local function addWatermark(content)
	return '--This watermark is used to delete the file if its cached, remove it to make the file persist after tumbahub updates.\n' .. content
end

local function downloadFile(path, func)
	if not isfile(path) then
		downloader.Text = 'Downloading '.. path
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/TumbaV6/'..readfile('tumbascript/profiles/commit.txt')..'/'..select(1, path:gsub('tumbascript/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = addWatermark(res)
		end
		writefile(path, res)
		downloader.Text = ''
	end
	return (func or readfile)(path)
end

local function fetchParallel(path)
	-- Download a file without blocking, returns thread
	return task.spawn(function()
		pcall(downloadFile, path)
	end)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('init') then continue end
		if file:find('profile') then continue end
		if isfile(file) then
			delfile(file)
		elseif isfolder(file) then
			wipeFolder(file)
		end
	end
end

-- ── Create folders ─────────────────────────────────────────────
for _, folder in {'tumbascript', 'tumbascript/games', 'tumbascript/profiles', 'tumbascript/assets', 'tumbascript/libraries', 'tumbascript/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

-- ── Smart update check ─────────────────────────────────────────
-- Only hits GitHub if cache is older than UPDATE_INTERVAL seconds.
-- Otherwise loads entirely from disk = INSTANT.
local UPDATE_INTERVAL = 1800 -- 30 minutes (change to 0 to always check)

local lastCheckFile  = 'tumbascript/profiles/lastcheck.txt'
local lastCheck      = isfile(lastCheckFile) and tonumber(readfile(lastCheckFile)) or 0
local allFilesExist  = isfile('tumbascript/main.lua')
local needsCheck     = (os.time() - lastCheck) >= UPDATE_INTERVAL or not allFilesExist

if not shared.TumbaHubDeveloper and needsCheck then
	downloader.Text = 'TumbaHub: checking updates...'

	-- GitHub API: returns tiny JSON with commit SHA (~200 bytes, vs 500KB HTML page)
	local commit = 'main'
	local apiThread = task.spawn(function()
		local suc, res = pcall(function()
			return game:HttpGet('https://api.github.com/repos/zxcbest957-pixel/TumbaV6/git/refs/heads/main', true)
		end)
		if suc and res then
			local sha = res:match('"sha":"([a-f0-9]+)"')
			if sha and #sha == 40 then commit = sha end
		end
	end)

	-- Wait max 2 seconds for API response
	local t0 = tick()
	repeat task.wait(0.04) until commit ~= 'main' or tick() - t0 > 2

	-- Wipe cache only if commit changed
	local cached = isfile('tumbascript/profiles/commit.txt') and readfile('tumbascript/profiles/commit.txt') or ''
	if commit ~= cached then
		if cached ~= '' then shared.updated = cached end
		downloader.Text = 'TumbaHub: new version, updating...'
		wipeFolder('tumbascript')
		wipeFolder('tumbascript/games')
		wipeFolder('tumbascript/guis')
		wipeFolder('tumbascript/libraries')
	end

	writefile('tumbascript/profiles/commit.txt', commit)
	writefile(lastCheckFile, tostring(os.time()))
	downloader.Text = ''

elseif not shared.TumbaHubDeveloper then
	-- Cache is fresh — skip GitHub entirely, load from disk instantly
	-- (make sure commit file exists)
	if not isfile('tumbascript/profiles/commit.txt') then
		writefile('tumbascript/profiles/commit.txt', 'main')
	end
end

-- ── Pre-fetch known files in PARALLEL (only downloads missing ones) ───
local gui = 'new'
if isfile('tumbascript/profiles/gui.txt') then
	local g = readfile('tumbascript/profiles/gui.txt'):gsub('%s', '')
	if g == 'rise' or g == 'old' or g == 'new' then gui = g end
end

local threads = {
	fetchParallel('tumbascript/main.lua'),
	fetchParallel('tumbascript/guis/' .. gui .. '.lua'),
	fetchParallel('tumbascript/games/universal.lua'),
	fetchParallel('tumbascript/profiles/supported.json'),
}

-- Wait for all parallel downloads to finish
local deadline = tick() + 10
repeat
	task.wait(0.02)
	local done = true
	for _, t in threads do
		if coroutine.status(t) ~= 'dead' then done = false; break end
	end
	if done then break end
until tick() > deadline

downloader.Text = ''
return loadstring(downloadFile('tumbascript/main.lua'), 'main')()