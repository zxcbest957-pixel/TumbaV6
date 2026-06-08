--!nocheck
pcall(function()
	local original_os_time = os.time
	local original_os_date = os.date
	local timeOffset = 0
	local source = "None"
	
	-- Try Workspace:GetServerTimeNow()
	local ws = game:GetService("Workspace") or workspace
	local success, result = pcall(function()
		return ws and ws.GetServerTimeNow and ws:GetServerTimeNow()
	end)
	if success and result and typeof(result) == "number" and result > 1000000000 then
		timeOffset = math.floor(result) - original_os_time()
		source = "Workspace"
	else
		-- Fallback to HttpGet from a public time API
		for _, urlInfo in ipairs({
			{url = "http://worldtimeapi.org/api/timezone/Etc/UTC", pattern = '"unixtime":%s*(%d+)', divisor = 1},
			{url = "https://worldtimeapi.org/api/timezone/Etc/UTC", pattern = '"unixtime":%s*(%d+)', divisor = 1},
			{url = "http://date.jsontest.com/", pattern = '"milliseconds_since_epoch":%s*(%d+)', divisor = 1000}
		}) do
			local httpSuccess, response = pcall(function()
				return game:HttpGet(urlInfo.url, true)
			end)
			if httpSuccess and response then
				local match = response:match(urlInfo.pattern)
				if match then
					local t = tonumber(match)
					if t then
						t = math.floor(t / urlInfo.divisor)
						if t > 1000000000 then
							timeOffset = t - original_os_time()
							source = "WebAPI (" .. urlInfo.url:match("://([^/]+)") .. ")"
							break
						end
					end
				end
			end
		end
	end
	
	-- Apply hooks if offset is calculated
	if source ~= "None" then
		print("[TumbaTimeSync] Synchronized clock using " .. source .. ". Offset: " .. timeOffset .. " seconds.")
		
		local function getSyncedTime()
			return original_os_time() + timeOffset
		end
		
		os.time = getSyncedTime
		os.date = function(format, time)
			return original_os_date(format, time or getSyncedTime())
		end
		
		local env = (getgenv and getgenv()) or _G
		
		-- Hook tick()
		local original_tick = tick
		env.tick = function()
			return original_tick() + timeOffset
		end
		
		-- Hook DateTime.now
		if DateTime then
			local original_datetime_now = DateTime.now
			local DateTime_mock = {}
			for k, v in DateTime do
				DateTime_mock[k] = v
			end
			DateTime_mock.now = function()
				return DateTime.fromUnixTimestamp(getSyncedTime())
			end
			env.DateTime = DateTime_mock
		end
	else
		warn("[TumbaTimeSync] Failed to synchronize clock from any source.")
	end
end)
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
			local commit = isfile('tumbascript/profiles/commit.txt') and readfile('tumbascript/profiles/commit.txt') or 'main'
			return game:HttpGet('https://raw.githubusercontent.com/zxcbest957-pixel/TumbaV6/'..commit..'/'..select(1, path:gsub('tumbascript/', '')), true)
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
local UPDATE_INTERVAL = 0 -- 30 minutes (change to 0 to always check)

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

-- ── Pre-fetch ALL known heavy files in PARALLEL ─────────────────────
local gui = 'new'
if isfile('tumbascript/profiles/gui.txt') then
	local g = readfile('tumbascript/profiles/gui.txt'):gsub('%s', '')
	if g == 'rise' or g == 'old' or g == 'new' then gui = g end
end

if not isfolder('tumbascript/games/bedwars') then
	makefolder('tumbascript/games/bedwars')
end

local threads = {
	fetchParallel('tumbascript/main.lua'),
	fetchParallel('tumbascript/guis/' .. gui .. '.lua'),
	fetchParallel('tumbascript/games/universal.lua'),
	fetchParallel('tumbascript/profiles/supported.json'),
	fetchParallel('tumbascript/games/bedwars/main.luau'),
	fetchParallel('tumbascript/games/bedwars/premium.luau'),
	fetchParallel('tumbascript/games/bedwars/engine.luau'),
}

-- Wait for downloads to finish (max 12 seconds)
local deadline = tick() + 12
repeat
	task.wait(0.02)
	local done = true
	for _, t in threads do
		if coroutine.status(t) ~= 'dead' then done = false; break end
	end
	if done then break end
until tick() > deadline

-- ── Background pre-compile the heaviest files ─────────────────────────
-- Stores compiled chunks in getgenv() so main.lua can reuse them
-- without calling loadstring again (saves 1-2 seconds of compilation).
local precompiled = {}
getgenv()._tumbaPrecompiled = precompiled

local compileThreads = {}
local function precompile(path, key)
	if not isfile(path) then return end
	local t = task.spawn(function()
		local src = readfile(path)
		if src and #src > 0 then
			local chunk = loadstring(src, key)
			if chunk then
				precompiled[key] = chunk
			end
		end
	end)
	table.insert(compileThreads, t)
end

precompile('tumbascript/guis/' .. gui .. '.lua',            'gui')
precompile('tumbascript/games/universal.lua',               'universal')
precompile('tumbascript/games/bedwars/main.luau',           'bedwars_main')
precompile('tumbascript/games/bedwars/premium.luau',        'bedwars_premium')

-- Give compilers a head start before main.lua execution begins
-- (main.lua still works even if not done; precompiled table just stays empty)
task.wait(0.05)

downloader.Text = ''
local mainSrc = downloadFile('tumbascript/main.lua')
local mainChunk, err = loadstring(mainSrc, 'main')
if not mainChunk then
	-- Cache is broken or outdated. Clear cache files and force update.
	downloader.Text = 'TumbaHub: repairing cache...'
	if isfile('tumbascript/main.lua') then delfile('tumbascript/main.lua') end
	if isfile('tumbascript/profiles/lastcheck.txt') then delfile('tumbascript/profiles/lastcheck.txt') end
	if isfile('tumbascript/profiles/commit.txt') then delfile('tumbascript/profiles/commit.txt') end
	task.wait(0.5)
	
	-- Re-download main.lua from GitHub
	mainSrc = downloadFile('tumbascript/main.lua')
	mainChunk, err = loadstring(mainSrc, 'main')
	downloader.Text = ''
end

if not mainChunk then
	error('TumbaHub: Failed to load main.lua - ' .. tostring(err or 'unknown error'))
end
return mainChunk()