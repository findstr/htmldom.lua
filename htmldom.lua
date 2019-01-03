local M = {}
local nexttoken
local tag = [["'</>=]]
local T = {
[tag:byte(1)] = function(str, start) -- "
	start = start + 1
	local e = str:find('"', start)
	return str:sub(start, e - 1), e + 1
end,
[tag:byte(2)] = function(str, start) -- '
	start = start + 1
	local e = str:find("'", start)
	return str:sub(start, e - 1), e + 1
end,
[tag:byte(3)] = function(str, start) -- <
	local n = str:byte(start + 1)
	local s = "!/-"
	if n == s:byte(1) then
		if str:byte(start + 2) == s:byte(3) then -- comment
			local _, e = str:find("-->", start + 4, true)
			return nexttoken(str, e + 1)
		else
			local e = str:find(">", start + 1)
			return nexttoken(str, e + 1)
		end
	elseif n == s:byte(2) then
		return "</", start + 2
	end
	return "<", start + 1
end,
[tag:byte(4)] = function(str, start) -- /
	if str:byte(start + 1) == tag:byte(5) then --/>
		return "/>", start + 2
	end
	return "/", start + 1
end,
[tag:byte(5)] = function(str, start) -- >
	return ">", start + 1
end,
[tag:byte(6)] = function(str, start) -- =
	return "=", start + 1
end,
}

local function plain(str, start)
	local e = str:find("[%s><=/]", start)
	assert(e > start, str:sub(start, start + 100))
	return str:sub(start, e - 1), e
end

function nexttoken(str, start)
	local start = str:find('[^%s]', start)
	if not start then
		return nil
	end
	local n = str:byte(start)
	local func = T[n]
	if not func then --plain
		func = plain
	end
	local s, start = func(str, start)
	return s, start
end

function nextattr(str, start)
	local start = str:find('[/>%a]', start)
	return nexttoken(str, start)
end


local node = {
	value = function(self, buffer)
		for _, v in pairs(self.child) do
			if type(v) == "string" then
				buffer[#buffer + 1] = v
			else
				v:value(buffer)
			end
		end
	end,
	text = function(self)
		local tbl = {}
		self:value(tbl)
		return table.concat(tbl)
	end,
	match = function(self, cond)
		local match = true
		local class = cond.class
		if class then
			match = false
			for _, v in pairs(self.class) do
				local ok = v:find(class, 1, true)
				if ok then
					match = true
					break
				end
			end
		end
		local id = cond.id
		if match and id and self.attr["id"] ~= id then
			match = false
		end
		local name = cond.name
		if match and name and self.name ~= name then
			match = false
		end
		return match
	end,
	select = function(self, method)
		local out = {}
		local childs = {}
		local cond = {
			name = nil,
			id = nil,
			class = nil,
		}
		local pattern = ".#"
		for k in string.gmatch(method, "([.#]-[^.#%s]+)") do
			local n = k:byte(1)
			if n == pattern:byte(1) then --.
				cond.class = k:sub(2)
			elseif n == pattern:byte(2) then --#
				cond.id = k:sub(2)
			else
				cond.name = k
			end
		end
		local type, pairs = type, pairs
		local nodes = {self}
		local n = #nodes
		::MATCH::
		local j = 0
		for i = 1, n do
			local node = nodes[i]
			for _, v in pairs(node.child) do
				if type(v) == "table" then
					if v:match(cond) then
						out[#out + 1] = v
					else
						j = j + 1
						childs[j] = v
					end
				end
			end
		end
		if #out == 0 and j > 0 then
			n = j
			nodes = childs
			childs = {}
			goto MATCH
		end
		return out
	end,
	selectn = function(self, method, level)
		local item = self
		for i = 1, level - 1 do
			item = item:select(method)[1]
		end
		return item:select(method)
	end
}

local nodemt = {__index = node}
local special = {
	["META"] = true,
	["LINK"] = true,
	["INPUT"] = true,
	["IMG"] = true,
	["BR"] = true,
	["HR"] = true,
}

local opentag = {}

local function parse(str, start)
	local debug = str:sub(start, start + 350)
	local s, start = nexttoken(str, start)
	if not s then
		return nil
	end
	assert(s == "<", s)
	local name, start = nexttoken(str, start)
	local attr = {}
	local class = {}
	local child = {}
	local obj = {
		name = name,
		attr = attr,
		class = class,
		child = child,
	}
	local openid = #opentag + 1
	opentag[openid] = name
	setmetatable(obj, nodemt)
	--attribute
	local tk
	while true do
		local k, v
		local back = start
		tk, start = nextattr(str, start)
		if tk == ">" or tk == "/>" then
			break
		end
		k = tk
		back = start
		tk, start = nexttoken(str, start)
		if tk == "=" then
			v, start = nexttoken(str, start)
			attr[k] = v
			if k == "class" then
				class[#class + 1] = v
			end
		else
			attr[k] = true
			start = back
		end
	end
	if special[string.upper(name)] then
		assert(tk == ">" or tk == "/>")
		opentag[openid] = nil
		return obj, start
	end
	if tk == "/>" then --close
		opentag[openid] = nil
		return obj, start
	end
	assert(tk == ">")
	while true do
		local back = start
		tk, start = nexttoken(str, start)
		if not tk then
			opentag[openid] = nil
			return obj
		end
		if tk == "</" then --close
			local tk1
			tk, start = nexttoken(str, start)
			if not tk then
				opentag[openid] = nil
				return obj
			end
			tk1, start = nexttoken(str, start)
			if not tk1 then
				opentag[openid] = nil
				return obj
			end
			assert(tk1 == ">", tk1)
			if tk == name then --good
				break
			end
			local opened = false
			for _, v in pairs(opentag) do
				if v == tk then
					opened = true
					break
				end
			end
			if opened then --has opened
				opentag[openid] = nil
				return obj, back
			end
			--skip it
		else
			if tk:byte(1) == tag:byte(3) then -- '<'
				local c
				c, start = parse(str, back)
				child[#child + 1] = c
				if not start then
					opentag[openid] = nil
					return obj
				end
				assert(c, str:sub(start, start + 100))
			else
				local e = str:find("<", back)
				local val = str:sub(back, e - 1)
				start = e
				child[#child + 1] = val
			end
		end
	end
	opentag[openid] = nil
	return obj, start
end

local function trip(txt)
	local buffer = {}
	local i = 1
	while i < #txt do
		local _
		local s = string.find(txt, "<script", i)
		if not s then
			buffer[#buffer + 1] = txt:sub(i, -1)
			break
		end
		buffer[#buffer + 1] = txt:sub(i, s - 1)
		_, i = string.find(txt, "</script[^>]*>", s + 1)
		i = i + 1
	end
	return table.concat(buffer)
end

local html_unescape = {
	['quot'] = '"',
	['amp'] = '&',
	['lt'] = '<',
	['gt'] = '>',
	['nbsp'] = ' ',
}

function htmlunescape(html)
	html = string.gsub(html, "&#(%d+);", function(s)
		return string.char(tonumber(s))
	end)
	html = string.gsub(html, "&(%a+);", html_unescape)
	return html
end



M.parse = function(str)
	str = trip(str)
	str = htmlunescape(str)
	return parse(str, 1)
end

return M
