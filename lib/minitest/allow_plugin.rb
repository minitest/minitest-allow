module Minitest
  def self.plugin_allow_options opts, _options # :nodoc:
    @allow = @allow_save = false

    opts.on "-a", "--allow=path", String, "Allow listed tests to fail." do |f|
      require "yaml"
      @allow = YAML.load File.read f
    end

    opts.on "-A", "--save-allow=path", String, "Save failing tests." do |f|
      require "yaml"
      @allow_save = f
    end
  end

  def self.plugin_allow_init options # :nodoc:
    if @allow || @allow_save then
      self.reporter.extend Allow
      self.reporter.allow      = @allow
      self.reporter.allow_save = @allow_save
      self.reporter.allow_seen = []
    end
  end

  class Result # TODO: push up
    def full_name
      "%s#%s" % [klass, name]
    end
  end

  class Minitest::Test # sigh... rails
    def full_name
      "%s#%s" % [self.class, name]
    end
  end

  module Allow
    VERSION = "1.0.0"

    attr_accessor :allow, :allow_save, :allow_seen

    def record result
      allow_seen << result.full_name
      super
    end

    def allow_results
      self.reporters
        .grep(Minitest::StatisticsReporter)
        .map(&:results)
    end

    def write_allow
      data = allow_results
        .flatten
        .map(&:full_name)
        .uniq
        .sort

      File.write allow_save, data.to_yaml
    end

    def filter_allow
      maybe_bad = allow_results.flatten.map(&:full_name).uniq
      to_remove = maybe_bad & allow
      extra_bad = maybe_bad - to_remove

      self.allow -= to_remove

      allow_results.each do |results|
        results.delete_if { |r| to_remove.include? r.full_name }
      end

      unless extra_bad.empty? then
        io.puts
        io.puts "Bad tests that are NOT allowed:"
        io.puts
        io.puts extra_bad.to_yaml
      end
    end

    def report_extra_allow
      good = allow & allow_seen

      unless good.empty? then
        io.puts
        io.puts "Excluded tests that now pass:"
        io.puts
        good.each do |name|
          io.puts "  :allow_good: %p" % [name]
        end
      end
    end

    def passed?
      write_allow        if allow_save
      filter_allow       if allow
      report_extra_allow if allow

      super # CompositeReporter#passed?
    end
  end
end
