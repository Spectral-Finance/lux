defmodule Lux.Prisms.PancakeSwap.PositionsPrism do
  @moduledoc """
  Tracks a wallet's PancakeSwap farming positions across one or more chains.

  For every entry in `positions` the prism reads the staked LP amount
  (`userInfo(pid, user)`) and the pending CAKE reward (`pendingCake(pid, user)`) from the
  chain's MasterChef contract. A failing entry (unknown chain, RPC failure, ...) is
  reported with `status: "error"` and does not fail the whole call, so a single
  unreachable chain never hides the other positions.

  Amounts are wei values returned as strings.

  ## Example

      iex> Lux.Prisms.PancakeSwap.PositionsPrism.run(%{
      ...>   address: "0x00000000000000000000000000000000000000aa",
      ...>   positions: [%{chain: "bsc", pool_id: 2}, %{chain: "base", pool_id: 1, masterchef: "0x..."}]
      ...> })
      {:ok,
       %{
         address: "0x00000000000000000000000000000000000000aa",
         positions: [
           %{chain: "bsc", pool_id: 2, status: "ok", staked: "1000", pending_cake: "5"},
           %{chain: "base", pool_id: 1, status: "error", error: "..."}
         ],
         total_pending_cake: "5",
         pending_cake_by_chain: %{"bsc" => "5"},
         positions_ok: 1,
         positions_failed: 1
       }}
  """

  use Lux.Prism,
    name: "PancakeSwap Positions",
    description:
      "Reads staked LP amounts and pending CAKE for farming positions on several chains",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Wallet address that owns the positions",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        positions: %{
          type: :array,
          description: "Farm positions to read",
          items: %{
            type: :object,
            properties: %{
              chain: %{type: :string, description: "Chain name or id"},
              pool_id: %{type: :integer, minimum: 0},
              masterchef: %{type: :string, description: "Override the MasterChef address"},
              rpc_url: %{type: :string, description: "Override the JSON-RPC endpoint"}
            },
            required: ["chain", "pool_id"]
          }
        }
      },
      required: ["address", "positions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string},
        positions: %{type: :array},
        total_pending_cake: %{type: :string},
        pending_cake_by_chain: %{type: :object},
        positions_ok: %{type: :integer},
        positions_failed: %{type: :integer}
      },
      required: ["address", "positions", "total_pending_cake"]
    }

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client

  def handler(input, _ctx) do
    address = PancakeSwap.field(input, :address)
    entries = PancakeSwap.field(input, :positions)

    cond do
      not PancakeSwap.valid_address?(address) ->
        {:error, "address must be a valid 0x-prefixed Ethereum address"}

      not is_list(entries) or entries == [] ->
        {:error, "positions must be a non-empty list"}

      true ->
        positions = Enum.map(entries, &read_position(address, &1))
        {:ok, summarize(address, positions)}
    end
  end

  defp read_position(address, entry) when is_map(entry) do
    chain_input = PancakeSwap.field(entry, :chain)
    pool_id = PancakeSwap.field(entry, :pool_id)

    base = %{chain: chain_name(chain_input), pool_id: pool_id}

    with {:ok, chain} <- PancakeSwap.fetch_chain(chain_input),
         :ok <- validate_pool_id(pool_id),
         {:ok, masterchef} <-
           PancakeSwap.address(chain, :masterchef_v2, PancakeSwap.field(entry, :masterchef)),
         opts = PancakeSwap.rpc_opts(entry),
         {:ok, [staked, _reward_debt, _boost]} <-
           Client.eth_call(
             chain,
             masterchef,
             "userInfo(uint256,address)",
             [pool_id, address],
             ["uint256", "uint256", "uint256"],
             opts
           ),
         {:ok, [pending]} <-
           Client.eth_call(
             chain,
             masterchef,
             "pendingCake(uint256,address)",
             [pool_id, address],
             ["uint256"],
             opts
           ) do
      Map.merge(base, %{
        chain: chain.name,
        chain_id: chain.id,
        status: "ok",
        staked: Integer.to_string(staked),
        pending_cake: Integer.to_string(pending)
      })
    else
      {:error, reason} ->
        Map.merge(base, %{status: "error", error: PancakeSwap.format_error(reason)})
    end
  end

  defp read_position(_address, entry) do
    %{
      chain: nil,
      pool_id: nil,
      status: "error",
      error: "invalid position entry: #{inspect(entry)}"
    }
  end

  defp validate_pool_id(pool_id) when is_integer(pool_id) and pool_id >= 0, do: :ok
  defp validate_pool_id(_), do: {:error, "pool_id must be a non-negative integer"}

  defp chain_name(chain_input) do
    case PancakeSwap.chain(chain_input) do
      {:ok, chain} -> chain.name
      {:error, _} -> chain_input
    end
  end

  defp summarize(address, positions) do
    ok = Enum.filter(positions, &(&1.status == "ok"))

    by_chain =
      Enum.reduce(ok, %{}, fn position, acc ->
        Map.update(
          acc,
          position.chain,
          String.to_integer(position.pending_cake),
          &(&1 + String.to_integer(position.pending_cake))
        )
      end)

    %{
      address: address,
      positions: positions,
      total_pending_cake: by_chain |> Map.values() |> Enum.sum() |> Integer.to_string(),
      pending_cake_by_chain:
        Map.new(by_chain, fn {chain, amount} -> {chain, Integer.to_string(amount)} end),
      positions_ok: length(ok),
      positions_failed: length(positions) - length(ok)
    }
  end
end
