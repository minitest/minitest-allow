require "minitest/autorun"
require "minitest/allow_plugin"

module TestMinitest; end

class TestMinitest::TestAllow < Minitest::Test
  def test_good
    assert true
  end

  def test_skipped
    skip "nah"
  end

  def test_unknown_bad
    flunk "bad!"
  end if ENV["NEW_BAD"]

  def test_sanity
    flunk "nah"
  end

  3.times do |n|
    name = "test_regexp_%02d" % [n]
    define_method name do
      raise "This is bad %02d" % [n]
    end
  end
end
