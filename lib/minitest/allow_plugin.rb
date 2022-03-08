module Minitest
  def self.plugin_allow_options opts, _options # :nodoc:
    @allow = @allow_save = false

    opts.on "-a", "--allow=path", String, "Allow listed tests to fail." do |f|
      require "yaml"
      @allow = YAML.load_file(f)
        .map { |s| s.start_with?("/") ? Regexp.new(s[1..-2]) : s }
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
    VERSION = "1.1.0"

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
      allow_results = self.allow_results

      # 1. split allow into strings and regexps
      allowed_REs, allowed_names = allow.partition { |a| Regexp === a }

      allowed_names = allowed_names.map { |x| [x, x] }.to_h

      # 2. remove items from allow_results whose full_name matches the strings
      # 3. remove items from allow_results whose message matches the regexps
      hit = {}
      allow_results.each do |results|
        results.delete_if { |r|
          x = (allowed_names[r.full_name] ||
               allowed_REs.find { |re| r.failure.message =~ re })

          hit[x] = true if x
        }
      end

      # 4. remove string and regexps that matched any of the above from allow
      self.allow -= hit.keys

      extra_bad = allow_results.flatten.map(&:full_name)
      unless extra_bad.empty? then
        io.puts
        io.puts "Bad tests that are NOT allowed:"
        io.puts
        io.puts extra_bad.to_yaml
      end
    end

    def report_extra_allow
      unless allow.empty? then
        io.puts
        io.puts "Excluded tests that now pass:"
        io.puts
        allow.each do |name|
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
