describe("Public API", function()
  it("returns the most recent version", function()
    local kong = require "kong.public"
    assert.equal("1.0.0", kong._api_version)
    assert.equal(100, kong._api_version_num)

  end)

  it("returns requested version", function()
    local kong = require "kong.public" "1.0.0"
    assert.equal("1.0.0", kong._API_VERSION)
    assert.equal(100, kong._API_VERSION_NUM)
  end)
end)

