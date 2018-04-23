# htmldom.lua
A simple html DOM parser implemented via pure Lua

## Usage


	local dom = require "htmldom"
	local root = dom:parse("<body>hello</body>")
	

## Selectors

Supported selectors are a subset of [jQuery's selectors](https://api.jquery.com/category/selectors/)


- `"element"` elements with the given tagname
- `"#id"` elements with the given id attribute value
- `".class"` elements with the given classname in the class attribute
	
## Example

	lua ./test.lua ./test.html

