defmodule Lux.Prisms.EventMonitor.QueryEventsPrism do
  @moduledoc """
  Prism for querying stored smart contract events.

  Provides flexible querying over previously captured events with support
  for filtering by address, event name, chain, block range, and pagination.

  ## Examples

      iex> Lux.Prisms.EventMonitor.QueryEventsPrism.run(%{
      ...>   address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   event_name: "Transfer",
      ...>   from_block: 18000000,
      ...>   limit: 50
      ...> })
      {:ok, %{events: [...], count: 42}}
  """

  use Lux.Prism,
    name: "Query Contract Events",
    description: "Queries stored smart contract events with flexible filtering",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Filter by contract address"
        },
        event_name: %{
          type: :string,
          description: "Filter by event name"
        },
        chain_id: %{
          type: :integer,
          description: "Filter by chain ID"
        },
        from_block: %{
          type: :integer,
          description: "Minimum block number"
        },
        to_block: %{
          type: :integer,
          description: "Maximum block number"
        },
        limit: %{
          type: :integer,
          description: "Maximum results to return (default: 100)"
        },
        offset: %{
          type: :integer,
          description: "Number of results to skip (default: 0)"
        },
        order: %{
          type: :string,
          enum: ["asc", "desc"],
          description: "Sort order by block number (default: desc)"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        events: %{
          type: :array,
          description: "List of matching events"
        },
        count: %{
          type: :integer,
          description: "Number of events returned"
        }
      },
      required: ["events", "count"]
    }

  alias Lux.EventMonitor

  @impl true
  def handler(input, ctx) do
    monitor = get_monitor(ctx)

    query =
      input
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Enum.map(fn
        {"order", "asc"} -> {:order, :asc}
        {"order", "desc"} -> {:order, :desc}
        {:order, "asc"} -> {:order, :asc}
        {:order, "desc"} -> {:order, :desc}
        {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
        {k, v} -> {k, v}
      end)
      |> Map.new()

    case EventMonitor.query_events(monitor, query) do
      {:ok, events} ->
        serialized =
          Enum.map(events, fn event ->
            %{
              address: event.address,
              event_name: event.event_name,
              block_number: event.block_number,
              transaction_hash: event.transaction_hash,
              log_index: event.log_index,
              chain_id: event.chain_id,
              decoded_params: event.decoded_params,
              timestamp: event.timestamp,
              data: event.data,
              topics: event.topics
            }
          end)

        {:ok, %{events: serialized, count: length(serialized)}}

      {:error, reason} ->
        {:error, "Failed to query events: #{inspect(reason)}"}
    end
  end

  defp get_monitor(nil), do: Lux.EventMonitor
  defp get_monitor(%{monitor: monitor}), do: monitor
  defp get_monitor(_), do: Lux.EventMonitor
end
