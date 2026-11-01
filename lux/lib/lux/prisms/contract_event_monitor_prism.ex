defmodule Lux.Prisms.ContractEventMonitorPrism do
  @moduledoc """
  Lux Prism enabling autonomous AI agents to manage smart contract event monitoring (#75).

  Provides tools to:
  - Subscribe to smart contract events across EVM networks
  - List and inspect active subscriptions
  - Query captured and decoded event logs
  - Replay historical event streams
  - Pause and resume event alerts
  """

  use Lux.Prism,
    name: "Contract Event Monitor Prism",
    description: "Monitors, filters, and queries multi-chain EVM smart contract events with webhooks and replay",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "subscribe",
            "unsubscribe",
            "list_subscriptions",
            "query_events",
            "replay_events",
            "pause",
            "resume",
            "metrics"
          ],
          description: "Action to perform on the event monitoring system"
        },
        chain: %{
          type: :string,
          description: "Target chain name (e.g., ethereum, polygon, arbitrum, optimism, base, bsc)"
        },
        chain_id: %{
          type: :integer,
          description: "EVM chain ID"
        },
        contract_address: %{
          type: :string,
          description: "Target smart contract address"
        },
        event_name: %{
          type: :string,
          description: "Event name (e.g., Transfer, Approval, Swap, Deposit)"
        },
        event_signature: %{
          type: :string,
          description: "Full ABI signature (e.g., Transfer(address,address,uint256))"
        },
        subscription_id: %{
          type: :string,
          description: "Subscription ID for pause, resume, unsubscribe, or scoped queries"
        },
        webhook_url: %{
          type: :string,
          description: "Webhook URL for real-time notification dispatch"
        },
        filter_pattern: %{
          type: :object,
          description: "Filter pattern with min_value, max_value, whitelist, blacklist"
        },
        from_block: %{
          type: :integer,
          description: "Starting block number for query"
        },
        to_block: %{
          type: :integer,
          description: "Ending block number for query"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of events to return",
          default: 50
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        success: %{type: :boolean},
        data: %{type: :object}
      },
      required: ["action", "success", "data"]
    }

  alias Lux.Web3.EventMonitor

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action")

    case execute_action(action, input) do
      {:ok, data} ->
        {:ok,
         %{
           action: action,
           success: true,
           data: normalize_output(data)
         }}

      {:error, reason} ->
        {:error, "EventMonitor action '#{action}' failed: #{inspect(reason)}"}
    end
  rescue
    e ->
      {:error, "ContractEventMonitorPrism error: #{Exception.message(e)}"}
  end

  defp execute_action("subscribe", input) do
    chain_str = Map.get(input, :chain) || Map.get(input, "chain") || "ethereum"
    chain = try_atom(chain_str)

    attrs = %{
      name: Map.get(input, :name) || Map.get(input, "name") || "Agent Sub - #{Map.get(input, :contract_address)}",
      chain: chain,
      chain_id: Map.get(input, :chain_id) || Map.get(input, "chain_id") || 1,
      contract_address: Map.get(input, :contract_address) || Map.get(input, "contract_address"),
      event_name: Map.get(input, :event_name) || Map.get(input, "event_name"),
      event_signature: Map.get(input, :event_signature) || Map.get(input, "event_signature"),
      webhook_url: Map.get(input, :webhook_url) || Map.get(input, "webhook_url"),
      filter_pattern: Map.get(input, :filter_pattern) || Map.get(input, "filter_pattern") || %{}
    }

    EventMonitor.subscribe(attrs)
  end

  defp execute_action("unsubscribe", input) do
    sub_id = Map.get(input, :subscription_id) || Map.get(input, "subscription_id")
    case EventMonitor.unsubscribe(sub_id) do
      :ok -> {:ok, %{unsubscribed: sub_id}}
      error -> error
    end
  end

  defp execute_action("list_subscriptions", input) do
    chain_str = Map.get(input, :chain) || Map.get(input, "chain")
    chain = if chain_str, do: try_atom(chain_str), else: nil

    filters =
      %{}
      |> maybe_put(:chain, chain)
      |> maybe_put(:contract_address, Map.get(input, :contract_address) || Map.get(input, "contract_address"))

    subs = EventMonitor.list_subscriptions(filters)
    {:ok, %{count: length(subs), subscriptions: subs}}
  end

  defp execute_action("pause", input) do
    sub_id = Map.get(input, :subscription_id) || Map.get(input, "subscription_id")
    EventMonitor.pause(sub_id)
  end

  defp execute_action("resume", input) do
    sub_id = Map.get(input, :subscription_id) || Map.get(input, "subscription_id")
    EventMonitor.resume(sub_id)
  end

  defp execute_action("query_events", input) do
    chain_str = Map.get(input, :chain) || Map.get(input, "chain")
    chain = if chain_str, do: try_atom(chain_str), else: nil
    sub_id = Map.get(input, :subscription_id) || Map.get(input, "subscription_id")
    contract = Map.get(input, :contract_address) || Map.get(input, "contract_address")
    from_b = Map.get(input, :from_block) || Map.get(input, "from_block")
    to_b = Map.get(input, :to_block) || Map.get(input, "to_block")
    limit = Map.get(input, :limit) || Map.get(input, "limit") || 50

    filters =
      %{}
      |> maybe_put(:chain, chain)
      |> maybe_put(:subscription_id, sub_id)
      |> maybe_put(:contract_address, contract)
      |> maybe_put(:from_block, from_b)
      |> maybe_put(:to_block, to_b)

    {events, total} = EventMonitor.query_events(filters, %{limit: limit})
    {:ok, %{total: total, count: length(events), events: events}}
  end

  defp execute_action("replay_events", input) do
    sub_id = Map.get(input, :subscription_id) || Map.get(input, "subscription_id")
    from_b = Map.get(input, :from_block) || Map.get(input, "from_block")
    to_b = Map.get(input, :to_block) || Map.get(input, "to_block")

    filters =
      %{}
      |> maybe_put(:subscription_id, sub_id)
      |> maybe_put(:from_block, from_b)
      |> maybe_put(:to_block, to_b)

    case EventMonitor.replay(filters, fn _event -> :ok end) do
      {:ok, count} -> {:ok, %{replayed_count: count}}
      error -> error
    end
  end

  defp execute_action("metrics", _input) do
    {:ok, EventMonitor.metrics()}
  end

  defp execute_action(other, _input) do
    {:error, "Unknown action: #{other}"}
  end

  defp normalize_output(%struct{} = s) when is_struct(s) do
    Map.from_struct(s)
  end

  defp normalize_output(map) when is_map(map) do
    Enum.into(map, %{}, fn {k, v} -> {k, normalize_output(v)} end)
  end

  defp normalize_output(list) when is_list(list) do
    Enum.map(list, &normalize_output/1)
  end

  defp normalize_output(other), do: other

  defp try_atom(str) when is_binary(str) do
    String.to_atom(str)
  rescue
    _ -> :ethereum
  end
  defp try_atom(atom) when is_atom(atom), do: atom

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
