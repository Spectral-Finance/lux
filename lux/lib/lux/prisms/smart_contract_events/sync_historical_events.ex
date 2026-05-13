defmodule Lux.Prisms.SmartContractEvents.SyncHistoricalEvents do
  @moduledoc """
  Backfills contract logs for a subscription.
  """

  use Lux.Prism,
    name: "Sync Historical Smart Contract Events",
    description: "Fetches or accepts historical logs and stores matching events for replay.",
    input_schema: %{
      type: :object,
      properties: %{
        subscription_id: %{type: :string},
        from_block: %{type: :integer},
        to_block: %{type: :integer},
        logs: %{type: :array, description: "Optional pre-fetched logs for offline/test sync"},
        notify: %{type: :boolean, description: "Notify webhooks for historical events"}
      },
      required: ["subscription_id", "from_block", "to_block"]
    }

  def handler(input, _context) do
    subscription_id = Map.get(input, :subscription_id) || Map.get(input, "subscription_id")

    opts =
      input
      |> Map.delete(:subscription_id)
      |> Map.delete("subscription_id")
      |> Enum.map(&normalize_option/1)

    Lux.EventMonitor.sync_history(subscription_id, opts)
  end

  defp normalize_option({"from_block", value}), do: {:from_block, value}
  defp normalize_option({"to_block", value}), do: {:to_block, value}
  defp normalize_option({"logs", value}), do: {:logs, value}
  defp normalize_option({"notify", value}), do: {:notify, value}
  defp normalize_option({"page", value}), do: {:page, value}
  defp normalize_option({"offset", value}), do: {:offset, value}
  defp normalize_option(option), do: option
end
