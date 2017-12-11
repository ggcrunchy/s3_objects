--- Common logic used to add values to, and remove them from, a random access container.

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
local bind = require("tektite_core.bind")
local expression = require("s3_utils.state.expression")
local state_vars = require("config.StateVariables")

-- Exports --
local M = {}

--
--
--

-- array, map
-- actions: append; pop; insert; remove
-- in props: insert_pos; remove_pos; at_index / key
-- out props: get; count; contains (troublesome for numbers...); empty; front; back; (hmm, array / set might need to be distinct)
-- events: on(add), on(remove), on(tried_to_remove_when_empty), on(bad_insert_pos), on(bad_remove_pos), on(bad_get_pos),
-- on(tried_to_add_when_full), on(get_when_empty), on(became_empty), on(became_full)
-- misc: max count / hard max, persist across reset