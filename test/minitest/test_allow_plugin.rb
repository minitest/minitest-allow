require "minitest/autorun"
require "minitest/manual_plugins" unless Minitest::VERSION > "6" # so 5.27 and 6.0 can coexist

Minitest.load :allow

module TestMinitest; end

class TestMinitest::TestAllow < Minitest::Test
  def test_good
    assert true
  end

  def test_skipped
    skip "nah"
  end

  def test_was_bad_now_skip
    skip "nah" if ENV["OLD_BAD"]
    flunk "nah"
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
