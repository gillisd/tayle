class Eventually
  include RSpec::Matchers::Composable

  def initialize(expected, within:)
    @expected = expected
    @within = within
  end

  def matches?(probe)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @within
    loop do
      @actual = probe.call
      return true if values_match?(@expected, @actual)
      return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def supports_block_expectations?
    true
  end

  def supports_value_expectations?
    false
  end

  def description
    "eventually #{description_of(@expected)}"
  end

  def failure_message
    "expected #{description_of(@actual)} to become #{description_of(@expected)} within #{@within}s"
  end
end
