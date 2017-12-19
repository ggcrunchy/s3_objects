--- Fetch a number constant.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Modules --
local number = require("s3_objects.grammars.number")

--
--
--

return require("s3_objects.state_templates.constant").Make("number", 0, function(dialog)
	dialog:AddString{ value_name = "constant_value", before = "Value:", set_editable_text = number.set_editable_text }
	dialog:AddCheckbox{ value_name = "defer_evaluation", text = "Defer evaluation?" }

	local cvalue, defer_cb = dialog:Find("constant_value"), dialog:Find("defer_evaluation")

	cvalue:UseRawText(defer_cb:IsChecked())

	dialog:addEventListener("update_object", function(event)
		if event.object == defer_cb then
			cvalue:UseRawText(defer_cb:IsChecked())
		end
	end)
end, number.fix_constant, number.resolve_text)