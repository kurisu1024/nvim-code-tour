local json = require("codetour.core.json")

describe("core.json.decode", function()
  it("decodes a valid tour object", function()
    local ok, value = json.decode('{"title":"T","steps":[]}')

    assert.is_true(ok)
    assert.equals("T", value.title)
  end)

  it("returns false and a message on malformed JSON", function()
    local ok, err = json.decode("{not json")

    assert.is_false(ok)
    assert.is_string(err)
  end)
end)
