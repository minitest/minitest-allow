# -*- ruby -*-

require "rubygems"
require "hoe"

Hoe.plugin :isolate
Hoe.plugin :seattlerb
Hoe.plugin :rdoc

Hoe.spec "minitest-allow" do
  developer "Ryan Davis", "ryand-ruby@zenspider.com"

  license "MIT"

  dependency "minitest", "~> 5.0"
end

task "test:filtered" do
  ruby "-Ilib -w test/minitest/test_allow_plugin.rb --allow=allow.yml"
end

task "test:unfiltered" do
  ruby "-Ilib -w test/minitest/test_allow_plugin.rb"
end

# vim: syntax=ruby
