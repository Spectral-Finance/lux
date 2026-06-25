defmodule Lux.Lenses.MultiChain.Monitor do
  @moduledoc """
  Real-time block and transaction monitoring across multiple EVM chains.

  This module provides continuous monitoring of new blocks and transactions
  across configured chains, with configurable polling intervals.
  """

  alias Lux.Lenses.MultiChain.Aggregator

  use Lux.Lens,
    name: "MultiChain.Monitor",
    description: "Real-time monitoring of blocks, transactions, and events across multiple EVM chains",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{type: :custom, auth_function: &Aggregator.add_api_key/1},
    schema: %{
      type: :object,
      properties: %{
        chains: %{type: :array, description: "List of chain IDs to monitor", items: %{type: :integer}, minItems: 1, maxItems: 10},
        monitor_type: %{type: :string, description: "Type of monitoring", enum: ["blocks", "transactions", "events"], default: "blocks"},
        interval_seconds: %{type: :integer, description: "Polling interval in seconds (default: 12)", default: 12},
        addresses: %{type: :array, description: "Addresses to monitor for transactions", items: %{type: :string}},
        contract_address: %{type: :string, description: "Contract address to monitor for events"},
        from_block: %{type: :integer, description: "Starting block for event monitoring"},
        to_block: %{type: :integer, description: "Ending block for event monitoring"},
        topic0: %{type: :string, description: "Event signature hash to filter logs"},
        max_polls: %{type: :integer, description: "Maximum polling cycles (default: 1)", default: 1}
      },
      required: ["chains", "monitor_type"]
    }

  @spec focus(map()) :: {:ok, map()} | {:error, term()}
  def focus(params) when is_map(params) do
    chains = Map.get(params, :chains, [])
    monitor_type = Map.get(params, :monitor_type, "blocks")
    interval = Map.get(params, :interval_seconds, 12)
    max_polls = Map.get(params, :max_polls, 1)

    session_params = params
      |> Map.put_new(:limit, 10)
      |> Map.put_new(:rate_limit_per_second, 3)

    results = 1..max_polls
      |> Enum.map(fn cycle ->
        chain_results = chains
          |> Task.async_stream(fn chain_id ->
            chain_params = session_params
              |> Map.put(:chains, [chain_id])
              |> Map.put(:data_type, data_type_for_monitor(monitor_type))
            Aggregator.focus(chain_params)
          end, timeout: 30000, max_concurrency: 3)
          |> Enum.map(fn
            {:ok, {:ok, result}} -> {:ok, result}
            {:ok, {:error, reason}} -> {:error, reason}
            {:exit, reason} -> {:error, "Worker exited: " <> inspect(reason)}
          end)

        :timer.sleep(interval * 1000)

        %{cycle: cycle, polled_at: DateTime.utc_now() |> DateTime.to_iso8601(), results: chain_results}
      end)

    {:ok, %{
      monitor_type: monitor_type,
      chains: chains,
      interval_seconds: interval,
      total_cycles: max_polls,
      polls: results
    }}
  end

  defp data_type_for_monitor("blocks"), do: "blocks"
  defp data_type_for_monitor("transactions"), do: "account_transactions"
  defp data_type_for_monitor("events"), do: "event_logs"
  defp data_type_for_monitor(_), do: "blocks"
end
