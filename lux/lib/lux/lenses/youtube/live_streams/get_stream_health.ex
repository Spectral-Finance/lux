defmodule Lux.Lenses.YouTube.LiveStreams.GetStreamHealth do
  @moduledoc """
  Reads YouTube live stream health details.
  """

  alias Lux.Integrations.YouTube.LiveWorkflow

  def view do
    Lux.Lens.new(
      name: "Get YouTube Live Stream Health",
      module_name: inspect(__MODULE__),
      description: "Gets live stream health and configuration issues",
      schema: %{
        type: :object,
        properties: %{
          stream_id: %{type: :string},
          access_token: %{type: :string}
        },
        required: ["stream_id", "access_token"]
      }
    )
  end

  def focus(input, _opts \\ %{}) do
    LiveWorkflow.stream_health(input[:stream_id] || input["stream_id"], input)
  end
end
