local parse_trac = require("parse_trac") -- adjust to your module path
local is_valid = parse_trac.is_valid_huuid

describe("parse_trac.is_valid_huiid", function()
	it("accepts a well-formed HUID with alnum tail", function()
		assert.is_true(is_valid("12345678-123456-AB12-cd"))
	end)

	it("rejects minimal 16-char HUID (both dashes only, no tail)", function()
		assert.is_false(is_valid("12345678-123456-"))
	end)

	it("allows the tail to contain dashes", function()
		assert.is_true(is_valid("12345678-123456-a-b-c-9"))
	end)

	it("accepts good HUIDs", function()
		assert.is_true(is_valid("20260905-161731"))
		assert.is_true(is_valid("20260801-161636"))
		assert.is_true(is_valid("20260902-155916"))
	end)

	it("rejects malformed input", function()
		assert.is_false(is_valid(""))
		assert.is_false(is_valid("1234567A-123456-x"))
		assert.is_false(is_valid("123456780123456-x"))
		assert.is_false(is_valid("12345678-12345A-x"))
		assert.is_false(is_valid("12345678-123456Xx"))
		assert.is_false(is_valid("12345678-123456-A_B"))
		assert.is_false(is_valid("12345678-123456-A B"))
		assert.is_false(is_valid("1234567"))
		assert.is_false(is_valid("12345678"))
		assert.is_false(is_valid("12345678-"))
	end)
end)
