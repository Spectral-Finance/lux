defmodule Lux.Prisms.Web3.EventMonitorPrism do
  @moduledoc """
  Lux Prism exposing smart contract event subscriptions, historical syncing,
  real-time polling, event querying, replay, and monitoring dashboard metrics.
  """

  use Lux.Prism,
    name: "Smart Contract Event Monitor",
    description: "Manages contract event subscriptions, syncing, filtering, and replay",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "subscribe, poll, sync_historical, list_events, dashboard"
        },
        subscription_id: %{type: :string},
        chain: %{type: :string},
        contracts: %{type: :array, items: %{type: :string}},
        event_names: %{type: :array, items: %{type: :string}},
        from_block: %{type: :integer},
        to_block: %{type: :integer},
        webhook_url: %{type: :string}
      },
      required: ["action"]
    }

  alias Lux.Web3.EventMonitor

  @impl true
  def handler(params, _ctx) when is_map(params) do
    action = Map.get(params, "action") || Map.get(params, :action)
    dispatch(to_string(action), normalize_keys(params))
  end

  defp dispatch("subscribe", params) do
    chain = parse_chain(Map.get(params, :chain, :ethereum))
    EventMonitor.subscribe(Map.put(params, :chain, chain))
  end

  defp dispatch("poll", %{subscription_id: sub_id}) do
    EventMonitor.poll_subscription(sub_id)
  end

  defp dispatch(
         "sync_historical",
         %{subscription_id: sub_id, from_block: from_b, to_block: to_b}
       ) do
    EventMonitor.sync_historical(sub_id, from_b, to_b)
  end

  defp dispatch("list_events", params) do
    {:ok, EventMonitor.list_events(params)}
  end

  defp dispatch("dashboard", _params) do
    {:ok, EventMonitor.dashboard_snapshot()}
  end

  defp dispatch(other, _params), do: {:error, {:unsupported_action, other}}

  defp parse_chain(chain) when is_atom(chain), do: chain
  defp parse_chain("ethereum"), do: :ethereum
  defp parse_chain("polygon"), do: :polygon
  defp parse_chain("bsc"), do: :bsc
  defp parse_chain("arbitrum"), do: :arbitrum
  defp parse_chain("optimism"), do: :optimism
  defp parse_chain("base"), do: :base
  defp parse_chain("avalanche"), do: :avalanche
  defp parse_chain(_), do: :ethereum

  defp normalize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
