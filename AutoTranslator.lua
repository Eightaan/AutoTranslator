_G.AutoTranslator = _G.AutoTranslator or {}
AutoTranslator._Cache = {}

local function check(str)
	str = tostring(str or "")
	str = string.lower(str)
	str = string.gsub(str, "%s+", "")
	return str
end

local function url_encode(str)
	if not str then return "" end
	str = string.gsub(str, "\n", "\r\n")
	str = string.gsub(str, "([^%w %-%_%.%~])",
		function(c) return string.format("%%%02X", string.byte(c)) end)
	str = string.gsub(str, " ", "+")
	return str
end

local function is_repeated_chars(str)
	str = tostring(str or "")
	str = str:gsub("%s+", "")

	if #str < 6 then
		return false
	end

	local first = str:sub(1,1)
	return str:match("^" .. first .. "+$") ~= nil
end

function AutoTranslator:displayMessage(channel_id, name, msg, color, icon)
	local receivers = managers.chat._receivers[channel_id]
	if not receivers then return end
	call_on_next_update(function ()
		managers.chat:_receive_message(1, name, msg, Color('29A4F6'), false)
	end)
end

function AutoTranslator:lookupTranslation(channel_id, name, msg, color, icon)
	if not name or name == "" then return end
	if tostring(name):lower() == "system" then return end

	local Current = math.round(Application:time())
	local msg_key = tostring(Idstring(msg):key())
	local player = tostring(name)

	if not self._Cache[player] then
		self._Cache[player] = {}
	end

	local cache = self._Cache[player]

	if cache[msg_key] and type(cache[msg_key]) == "number" then
		if cache[msg_key] + 5 > Current then return end
		cache[msg_key] = nil
	end

	for id, timestamp in pairs(cache) do
		if type(timestamp) == "number" and timestamp + 5 < Current then
			cache[id] = nil
		end
	end

	cache[msg_key] = Current
	
	if is_repeated_chars(msg) then
		return
	end

	local _tl = "en"
	local url = "https://translate.googleapis.com/translate_a/single?client=gtx&ie=utf-8&sl=auto&tl=" .. _tl .. "&dt=t&text=" .. url_encode(msg)
	dohttpreq(url, function(data)
		if data and json then
			data = data:gsub(",,", ",")
			data = json.decode(data) or {}
			if data[1] and data[1][1] and data[1][1][1] and data[2] and data[2] ~= _tl then
				local translated = data[1][1][1]
				if not translated or translated == "" then return end
				
				local checked = check(msg)
				if check(translated) == checked then return end

				local translator = " " .. translated .. " "
				local detected_lang = data[2]:upper() or "??"
				self:displayMessage(channel_id, "Translator ["..detected_lang.."]", translator, color, icon)
			end
		end
	end)
end

Hooks:Add("ChatManagerOnReceiveMessage", "AutoTranslator_ChatManagerOnReceiveMessage", function(channel_id, name, message, color, icon)
	AutoTranslator:lookupTranslation(channel_id, name, message, color, icon)
end)