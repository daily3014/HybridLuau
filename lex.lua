--[[
	Hybrid Lua/Luau Lexer
	daily3014
--]]


local Lexer = {}
Lexer.__index = Lexer

local alphabet = {
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
}

local numbers = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local hexadecimal = { "a", "b", "c", "d", "e", "f", "A", "B", "C", "D", "E", "F", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }

local luaTokens = {
	whitespace = {
		" ", "\t", "\n"
	},
	
	keywords = {
		"for", "while", "repeat",
		"if", "local", "end", 
		"else", "elseif", "and", "or", "then", "not", "in",
		"do", "function", 
		"break", "continue", "return", "until",
		"false", "true", "nil"
	},
		
	compound = {
		"+=", "-=", "*=", "/=", "%=", "^="	
	},
		
	operators = {
		"+", "-", "*", "/", "%", "^", 
		"#",
		"==", "=", "~=", "<=", ">=",
		"<", ">",
	},
	
	parentheses = {
		"(", ")", "{", "}", "[", "]"
	},
	
	symbols = {
		";", 
		":", 
		",", 
	},
	
	quotes = {
		"'",
		"\"",
	},
	
	interpolation = "`",
	comment = "--",
}

function Lexer.new(code: string)
	local codeLexer = {
		code = code :: string,
		stringLength = (#code) :: number,
		position = 0 :: number,
		currentCharacter = "" :: string,
		lastPeek = nil :: string | nil,
		tokens = {} :: {[number]: {name: string, content: string}}
	}
	
	return setmetatable(codeLexer, Lexer)
end

function Lexer.isLetterOrNumber(testCharacter: string): boolean

	return table.find(alphabet, testCharacter) or table.find(numbers, testCharacter)
end

function Lexer:peek(matchFor: string|{any}?, consume: boolean?, offset: number?, matchWord: boolean?, caseSensitive: boolean?): boolean | string
	local nextCharacters = ""
	local caseSensitive = if caseSensitive ~= nil then caseSensitive else true
	
	if type(matchFor) == "string" then
		for i = 0, #matchFor - 1 do
			local nextPosition = self.position + i
			nextCharacters ..= self.code:sub(nextPosition, nextPosition)
		end	
		
		local matched = if caseSensitive then 
			string.lower(nextCharacters) == string.lower(matchFor) else nextCharacters == matchFor
			
		if consume == true and matched then
			self:forward(#matchFor)
		end
		
		if matched then
			self.lastPeek = matchFor
		end
		
		return matched
	elseif type(matchFor) == "table" then
		local matches = {}
		
		for _, element in matchFor do
			if self:peek(element, false, offset, matchWord) then
				table.insert(matches, element)
			end
		end
		
		if #matches > 0 then
			table.sort(matches, function(a, b)
				return #a > #b
			end)
			
			if #matches[1] ~= 1 then
				self:forward(#matches[1])
			end
			
			self.lastPeek = matches[1]
			return true
		end
		
		return false
	end
	
	local nextPosition = self.position + if offset then offset else 1
	return self.code:sub(nextPosition, nextPosition)
end

function Lexer:nextWord(peek: boolean?): string
	local word = ""
	
	if peek == true then
		local current = self:read()
		
		local offset = 0
		
		while current and Lexer.isLetterOrNumber(current) do
			word ..= current
			
			offset += 1
			current = self:read(offset)
		end
		
		return word
	end

	while self:read() and Lexer.isLetterOrNumber(self:read()) do
		word ..= self:read()
		
		self:forward()
	end

	
	return word
end

function Lexer:nextString(quote: string, peek: boolean?): string
	local str = ""
	
	if peek == true then
		local current = self:read()
		local offset = 0

		while current and current ~= quote do
			str ..= current
			
			offset += 1
			task.wait()
		end
		
		return str
	end
	
	while self:read() and self:read() ~= quote do
		str ..= self:read()

		self:forward()
		task.wait()
	end
	
	return str
end

function Lexer:forward(offset: number?)
	self.position += if offset then offset else 1
	self.currentCharacter = self.code:sub(self.position, self.position)
end

function Lexer:backward(offset: number?)
	self.position -= if offset then offset else 1
	self.currentCharacter = self.code:sub(self.position, self.position)
end

function Lexer:read(offset: number?): boolean | string
	if offset then
		local offsetPosition = self.position + offset
		
		if offsetPosition > self.stringLength then
			return false
		end
		
		return self.code:sub(offsetPosition, offsetPosition)
	end
	
	if self.position > self.stringLength then
		return false
	end
	
	return self.currentCharacter
end

function Lexer:appendToken(name, content)
	table.insert(self.tokens, {
		name = name,
		content = content
	})
end

function Lexer:run()
	assert(self.position == 0)
	
	while true do
		self:forward()
		
		if not self:read() then
			break
		end
		
		local currentCharacter = self:read()
		
		if self:peek("--", true) then -- Single Line Comment
			local comment = ""

			while self:read() and self:read() ~= "\n" do
				comment ..= self:read()
				self:forward()
				task.wait()
			end
			
			self:appendToken("Comment", comment)
		
		elseif table.find(luaTokens.whitespace, currentCharacter) then -- Whitespaces (Tabs, Spaces)
			self:appendToken("Whitespace", currentCharacter)
			
		elseif table.find(luaTokens.parentheses, currentCharacter) then -- Parentheses (), {}, []
			self:appendToken("Parentheses", currentCharacter)
			
		elseif self:peek(luaTokens.compound, true) then -- Compound (+=, -=, *=)
			self:appendToken("Compound", self.lastPeek)

		elseif self:peek(luaTokens.symbols, true) then -- Symbols (; : ,)
			self:appendToken("Symbol", self.lastPeek)

		elseif self:peek(luaTokens.operators, true) then -- Operators (+, -, *)
			self:appendToken("Operator", self.lastPeek)
			
		elseif self:peek(luaTokens.keywords, true) then -- Keywords (local, function)
			self:appendToken("Keyword", self.lastPeek)
			
		elseif self:peek(luaTokens.quotes, true) then -- Strings ( "hello world" )
			self:forward()
			self:appendToken("String", {
				["quote"] = self.lastPeek, 
				["content"] = self:nextString(self.lastPeek)
			})
			
		elseif self:peek("...", true) then -- Vararg
			self:appendToken("TripleDot", "...")
			
		elseif self:peek("..", true) then -- Concat Dot (A .. B)
			self:appendToken("ConcatDot", "..")
			
		elseif self:peek(".", true) then -- Index Dot (A.B)
			self:appendToken("IndexDot", ".")
		end
		
		task.wait()
	end
	
	return self.tokens
end

return Lexer
