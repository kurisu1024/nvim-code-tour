local mdrender = require("codetour.ui.mdrender")

-- A fake availability probe: only the named plugins "exist".
local function has_only(...)
  local set = {}
  for _, name in ipairs({ ... }) do
    set[name] = true
  end
  return function(name)
    return set[name] == true
  end
end

describe("ui.mdrender selection", function()
  it("auto-detects render-markdown.nvim first when present", function()
    local choice = mdrender.select("auto", has_only("render-markdown", "markview"))
    assert.equals("render-markdown", choice)
  end)

  it("auto-detects markview.nvim when render-markdown is absent", function()
    local choice = mdrender.select("auto", has_only("markview"))
    assert.equals("markview", choice)
  end)

  it("falls back to treesitter when no optional renderer is present", function()
    local choice = mdrender.select("auto", has_only())
    assert.equals("treesitter", choice)
  end)

  it("honors an explicit treesitter choice even when plugins exist", function()
    local choice = mdrender.select("treesitter", has_only("render-markdown"))
    assert.equals("treesitter", choice)
  end)

  it("honors an explicit provider name when that provider is present", function()
    local choice = mdrender.select("markview", has_only("render-markdown", "markview"))
    assert.equals("markview", choice)
  end)

  it("falls back to treesitter when an explicit provider is not installed", function()
    local choice = mdrender.select("markview", has_only())
    assert.equals("treesitter", choice)
  end)

  it("defaults a nil config to auto detection", function()
    local choice = mdrender.select(nil, has_only("render-markdown"))
    assert.equals("render-markdown", choice)
  end)

  it("never errors when applying a choice with the plugins absent", function()
    local buf = vim.api.nvim_create_buf(false, true)
    assert.has_no.errors(function()
      mdrender.apply(buf, "treesitter")
      mdrender.apply(buf, "render-markdown")
      mdrender.apply(buf, "markview")
    end)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it("resolves the active markdown_renderer config via the default probe", function()
    -- On the test runtime the optional plugins are absent, so auto -> treesitter.
    local config = require("codetour.config")
    config.setup({ markdown_renderer = "auto" })
    assert.equals("treesitter", mdrender.select(config.get().markdown_renderer))
    config.setup({})
  end)
end)
