defmodule Test.Support.Agents.TestCEO do
  @moduledoc """
  A simple CEO agent implementation for testing.
  """
  use Lux.Agent,
    name: "Test CEO",
    description: "A test CEO agent for testing company functionality",
    goal: "Lead test companies effectively"

  def handle_signal(signal, _context) do
    # Echo back the signal for testing
    {:ok, signal}
  end
end
