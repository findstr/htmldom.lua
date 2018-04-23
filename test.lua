local path = ...
local html = require "htmldom"
local f = io.open(path, "r")
local body = f:read("a")
f:close()

local function P(tbl, level)
	local tab = {}
	for i = 1, level do
		tab[i] = "    "
	end
	tab = table.concat(tab, "")
	local buff = {}
	buff[1] = string.format("<%s", tbl.name)
	for k, v in pairs(tbl.attr) do
		buff[#buff + 1] = string.format("%s=%s", k, v)
	end
	buff[#buff + 1] = ">"
	print(string.format("%s%s", tab, table.concat(buff, " ")))
	for k, v in pairs(tbl.child) do
		if type(v) == "table" then
			P(v, level + 1)
		else
			print(string.format("%s%s", tab, v))
		end
	end
	print(string.format("%s</%s>", tab, tbl.name))
end

local root = html.parse(body)
local item = root:select(".class_ul")
print("select '.class_ul'", #item)
local item = root:select("#id_test")
print("select '#id_test'", #item)
local item = root:select("li#id_test")
print("select 'li#id_test'", #item)

--P(root, 0)

