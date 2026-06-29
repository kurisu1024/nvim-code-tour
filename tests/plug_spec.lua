local plug = require("codetour.plug")

local function global_map(lhs)
  return vim.fn.maparg(lhs, "n")
end

describe("<Plug> mappings", function()
  before_each(function()
    plug.register()
  end)

  it("exposes <Plug>(codetour-*) normal-mode mappings", function()
    for _, name in ipairs({ "next", "prev", "stop", "resume", "list", "follow" }) do
      local lhs = "<Plug>(codetour-" .. name .. ")"
      assert.is_true(global_map(lhs) ~= "", "expected a mapping for " .. lhs)
    end
  end)

  it("sets NO global keymaps on the default tour keys", function()
    -- The configured tour keys are buffer-local during a tour, never global.
    -- (Some keys like ]t/[t are Neovim's own built-in defaults — those are not
    -- ours; we assert only that codetour itself bound nothing to a real key.)
    local function is_codetour_map(lhs)
      local d = vim.fn.maparg(lhs, "n", false, true)
      if not d or vim.tbl_isempty(d) then
        return false
      end
      local desc = d.desc or ""
      local rhs = d.rhs or ""
      return desc:find("codetour", 1, true) ~= nil or rhs:find("codetour", 1, true) ~= nil
    end
    for _, lhs in ipairs({ "]t", "[t", "q", "<CR>", "g?" }) do
      assert.is_false(is_codetour_map(lhs), lhs .. " must not be globally mapped by codetour")
    end
  end)

  it("registers a mapping for every declared entry point", function()
    local count = 0
    for _ in pairs(plug.mappings) do
      count = count + 1
    end
    assert.is_true(count >= 6)
  end)

  it("is idempotent: registering twice does not error", function()
    assert.has_no.errors(function()
      plug.register()
      plug.register()
    end)
  end)
end)
