defmodule Lux.Prisms.Telegram.Analytics.CollectUpdateMetrics do
  @moduledoc """
  Collects Telegram update analytics from raw webhook or polling payloads.
  """

  use Lux.Prism,
    name: "Collect Telegram Update Metrics",
    description: "Normalizes Telegram updates and returns aggregate usage metrics",
    input_schema: %{
      type: :object,
      properties: %{
        updates: %{
          type: :array,
          description: "Raw Telegram update payloads or normalized metric events"
        }
      },
      required: ["updates"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_updates: %{type: :integer},
        unique_users: %{type: :integer},
        unique_chats: %{type: :integer},
        commands: %{type: :object},
        error_rate: %{type: :number},
        visualization: %{type: :object}
      },
      required: ["total_updates", "unique_users", "unique_chats", "error_rate"]
    }

  alias Lux.Telegram.Analytics

  def handler(%{updates: updates}, _ctx) when is_list(updates) do
    {:ok, Analytics.aggregate(updates)}
  end

  def handler(%{"updates" => updates}, ctx), do: handler(%{updates: updates}, ctx)
  def handler(_input, _ctx), do: {:error, "updates must be a list"}
end
