defmodule Test.Support.Agents.Researcher do
  @moduledoc """
  Researcher agent implementation for testing.
  Handles topic research and analysis.
  """
  use Lux.Agent

  def handle_signal(%{schema_id: Lux.Schemas.TaskSignal} = signal, context) do
    case signal.payload.task do
      "research" ->
        # Simulate research process
        Process.sleep(800)

        {:ok,
         %{
           status: :completed,
           research_notes: "Sample research notes for #{context.topic}",
           key_points: ["Point 1", "Point 2", "Point 3"]
         }}

      "analyze" ->
        # Simulate analysis
        Process.sleep(500)

        {:ok,
         %{
           status: :completed,
           analysis: "Sample analysis for #{context.topic}",
           insights: ["Insight 1", "Insight 2"]
         }}

      _ ->
        {:error, :unknown_task}
    end
  end

  def handle_signal(_, _), do: {:error, :unknown_signal}
end
