require "spec"
require "../src/kramdown_asciidoc"

# Guard against parser loops: the conversion runs in a child process (this
# same spec binary, re-executed in "convert" mode) that is killed after a
# delay. A fiber with `select … timeout` would not do: a CPU-bound loop never
# yields, so the timeout could never fire in a single-threaded program.
module ConversionGuard
  CHILD_ENV = "KRAMDOWN_ASCIIDOC_SPEC_CONVERT"

  # Converts *markdown* in a child process; fails the example if the
  # conversion does not end within *timeout*.
  def self.convert(markdown : String, timeout : Time::Span = 5.seconds) : String
    process = Process.new(Process.executable_path.not_nil!,
      env: {CHILD_ENV => "1"},
      input: Process::Redirect::Pipe,
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Inherit)
    process.input.print(markdown)
    process.input.close

    done = Channel(String).new
    spawn { done.send(process.output.gets_to_end) }
    select
    when output = done.receive
      status = process.wait
      fail "conversion failed (#{status})" unless status.success?
      output
    when timeout(timeout)
      process.terminate(graceful: false)
      process.wait
      fail "conversion did not end within #{timeout} (infinite loop?)"
    end
  end
end

if ENV[ConversionGuard::CHILD_ENV]?
  STDOUT.print(KramdownAsciidoc.convert(STDIN.gets_to_end))
  STDOUT.flush
  # Leave without the at_exit hooks, which would run the whole spec suite.
  LibC._exit(0)
end
