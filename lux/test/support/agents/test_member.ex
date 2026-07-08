defmodule Test.Support.Agents.TestMember do
  @moduledoc """
  A simple member agent implementation for testing.
  """
  use Lux.Agent,
    name: "Test Member",
    description: "A test member agent for testing company functionality",
    goal: "Execute test tasks effectively"

  def handle_signal(signal, _context) do
    # Echo back the signal for testing
    {:ok, signal}
  end
end
