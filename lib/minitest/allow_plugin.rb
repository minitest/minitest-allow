module Minitest
  def self.plugin_allow_options opts, _options # :nodoc:
    @allow = @allow_save = false
    @run_only = []

    opts.on "-c", "--check=path", String, "Run only the tests listed in the allowed file. Overwrites the current file." do |f|
      require "psych"

      @run_only = if Psych.respond_to? :safe_load_file
                    Psych.safe_load_file f, permitted_classes: [Regexp]
                  else
                    Psych.load_file f
                  end || []
      @allow_save = f
    end

    opts.on "-a", "--allow=path", String, "Allow listed tests to fail." do |f|
      # don't ask why I'm using this specifically:
      require "psych"

      @allow = if Psych.respond_to? :safe_load_file then
                 Psych.safe_load_file f, permitted_classes: [Regexp]
               else
                 Psych.load_file f
               end || []
    end

    opts.on "-A", "--save-allow=path", String, "Save failing tests." do |f|
      require "psych"
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
    Minitest::Allow.run_only = @run_only
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
    VERSION = "1.2.3"

    attr_accessor :allow, :allow_save, :allow_seen

    class << self
      attr_accessor :run_only
    end

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

      File.write allow_save, Psych.dump(data, line_width:-1)
    end

    # Test runs call record, we put everything ran in allow_seen.
    # This means allow_seen has everything RAN, regardless of pass/fail
    # We use this intersected with the allowed file to determine what to report
    # on... if it wasn't seen, we don't say add/remove at all.
    #
    # `allow` is all the stuff from the allow file. Test names and
    # regexps that excuse failures.
    #
    # `allow_results` is an array of arrays of results: [[result, ...], ...]
    #
    # When the run is done, we want to tell the user what tests to
    # remove or add from the allowed list:
    #
    # * If a test passed that is in the allowed list, it should be removed.
    # * If a test failed that is NOT in the allowed list, it should be added.
    # * If a test failed that is matched by a regexp, it's NAME should be removed
    #   if it is listed.

    def filter_allow
      # 1. split allow into strings and regexps
      allowed_REs, allowed_names = allow.partition { |a| Regexp === a }

      allowed_names = allowed_names.map { |x| [x, x] }.to_h

      # 2. remove items from allow_results whose full_name matches the strings
      # 3. remove items from allow_results whose message matches the regexps
      # 4. remove items from allow_results whose full_name matches the regexps?

      hit = {}
      allow_results = self.allow_results
      allow_results.each do |results|
        results.delete_if { |r|
          name = r.full_name

          by_name = allowed_names[name]
          by_regx = allowed_REs.find { |re| r.failure.message =~ re || name =~ re }

          # this will add the name as bad unless hit by regexp as well
          # if hit by regex, then we want to report it as "good" so
          # the name gets removed from the allow list:

          # the same goes for when the test is listed as bad but is now skipped:

          hit[name] = true if by_name && !by_regx && !r.skipped?

          by_name || by_regx
        }
      end

      # 5. remove string and regexps that matched any of the above from allow
      self.allow -= hit.keys

      errored, failed = allow_results
        .flatten
        .reject(&:skipped?)
        .partition { |t| Minitest::UnexpectedError === t.failure }

      failed = failed.map(&:full_name)
      errors = Hash.new { |h,k| h[k] = [] }

      errored.each do |t|
        msg = t.failure.message.lines.first.chomp.gsub(/0x\h+/, "0xHHHH")

        errors[Regexp.new(Regexp.escape(msg))] << t.full_name
      end

      extra_bad = failed.uniq
      extra_bad << errors.transform_values(&:uniq) unless errors.empty?

      # 6. report new failures including regular expressions for errors

      unless extra_bad.empty? then
        io.puts
        io.puts "Bad tests that are NOT allowed:"
        Psych.dump extra_bad, io, line_width:-1
        io.puts
      end
    end

    def report_extra_allow
      good = allow & allow_seen

      unless good.empty? then
        io.puts
        io.puts "Excluded tests that now pass:"
        Psych.dump good, io, line_width:-1
        io.puts
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

Minitest.singleton_class.prepend(Module.new do
  def __run reporter, options = {}
    options[:filter] = Regexp.union(Minitest::Allow.run_only) unless Minitest::Allow.run_only.empty?
    super
  end
end)
