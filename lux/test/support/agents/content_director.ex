defmodule Test.Support.Agents.ContentDirector do
  @moduledoc """
  Content Director agent implementation for testing.
  Handles content review and approval.
  """
  use Lux.Agent

  def handle_signal(%{schema_id: Lux.Schemas.TaskSignal} = signal, _context) do
    case signal.payload.task do
      "review" ->
        # Simulate content review
        Process.sleep(500)
        {:ok, %{status: :completed, message: "Content reviewed successfully"}}

      "approve" ->
        # Simulate content approval
        Process.sleep(300)
        {:ok, %{status: :completed, approved: true, message: "Content approved"}}

      _ ->
        {:error, :unknown_task}
    end
  end

  def handle_signal(_, _), do: {:error, :unknown_signal}
end
