require "minitest/autorun"
require "minitest/allow_plugin"

module TestMinitest; end

class TestMinitest::TestAllow < Minitest::Test
  def test_sanity
    flunk "write tests or I will kneecap you"
  end
end
