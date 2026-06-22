defmodule Lux.Lenses.MEVProtection do
  @moduledoc """
  Lens for querying MEV protection services and relay availability.
  """

  use Lux.Lens,
    name: "MEV Protection Status",
    description: "Queries MEV protection services and relay availability status",
    url: "https://protect.flashbots.net",
    method: :get,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        network: %{type: :string, enum: ["mainnet", "goerli", "sepolia"], default: "mainnet"},
        relay: %{type: :string, enum: ["flashbots", "eden", "avo"], default: "flashbots"}
      },
      required: []
    }

  @impl true
  def after_focus(response) do
    case response do
      %{"status" => "ok", "data" => data} ->
        {:ok, %{
          relay_status: "operational",
          mempool_size: Map.get(data, "mempool_size", 0),
          mev_activity: Map.get(data, "mev_activity", "normal"),
          recommended_action: get_recommended_action(Map.get(data, "mev_activity", "normal"))
        }}
      %{"status" => "error"} ->
        {:error, "MEV protection service returned error"}
      _ ->
        {:ok, %{relay_status: "unknown", mempool_size: 0, mev_activity: "unknown", recommended_action: "Monitor manually"}}
    end
  end

  defp get_recommended_action("high"), do: "MEV activity elevated. Consider private relay."
  defp get_recommended_action("normal"), do: "MEV activity normal. Standard submission safe."
  defp get_recommended_action("low"), do: "MEV activity low. No precautions needed."
  defp get_recommended_action(_), do: "Unable to determine MEV activity level."
end
