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

Rake.application["test"].clear # hack? is there a better way?

task :test => "test:filtered"

namespace "test" do
  Minitest::TestTask.create "filtered" do |t|
    t.extra_args << "--allow=allow.yml"
  end

  Minitest::TestTask.create "unfiltered"
end

# vim: syntax=ruby
