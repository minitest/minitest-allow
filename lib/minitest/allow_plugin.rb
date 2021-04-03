module Minitest
  def self.plugin_allow_options opts, _options # :nodoc:
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
    end

    self.reporter.allow      = @allow      if @allow
    self.reporter.allow_save = @allow_save if @allow_save
  end

  class Result # TODO: push up
    def full_name
      "%s#%s" % [klass, name]
    end
  end

  module Allow
    VERSION = "1.0.0"

    attr_accessor :allow, :allow_save

    def allow_results
      self.reporters
        .grep(Minitest::StatisticsReporter)
        .map(&:results)
    end

    def write_allow
      data = allow_results
        .flat_map { |rs| rs.map(&:full_name) }
        .uniq
        .sort

      File.write allow_save, data.to_yaml
    end

    def filter_allow
      allow_results.each do |results|
        results.delete_if { |r| allow.delete r.full_name }
      end
    end

    def report_extra_allow
      unless allow.empty? then
        io.puts
        io.puts "Excluded tests that now pass:"
        io.puts
        allow.each do |name|
          io.puts "  #{name}"
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
