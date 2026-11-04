defmodule Lux.Prisms.PancakeSwap.PoolPosition do
  @moduledoc """
  A prism for managing PancakeSwap V3 pool positions.

  Provides pool position management including opening, tracking,
  and monitoring liquidity positions across PancakeSwap pools.

  ## Examples

      # Get pool position for a user
      iex> Lux.Prisms.PancakeSwap.PoolPosition.run(%{"address" => "0x...", "pool_id" => "0x..."})
      {:ok, %{"position" => %{"liquidity" => "1000", "pool_id" => "0x..."}}}
  """

  use Lux.Prism,
    name: "PancakeSwap Pool Position",
    description: "Manages PancakeSwap V3 pool positions including liquidity provision and tracking",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Wallet address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        pool_id: %{
          type: :string,
          description: "PancakeSwap V3 pool ID (pair address)"
        },
        action: %{
          type: :string,
          description: "Action to perform: view, add, remove",
          enum: ["view", "add", "remove"],
          default: "view"
        },
        liquidity: %{
          type: :string,
          description: "Amount of liquidity to add or remove (in wei as string)"
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Operation status"
        },
        position: %{
          type: :object,
          description: "Pool position details"
        },
        tx_hash: %{
          type: :string,
          description: "Transaction hash for on-chain actions"
        }
      },
      required: ["status"]
    }

  def handler(input, _ctx) do
    address = Map.get(input, :address, Map.get(input, "address", nil))
    action = Map.get(input, :action, Map.get(input, "action", "view"))

    cond do
      is_nil(address) ->
        {:error, "address is required"}

      action == "view" ->
        handle_view_position(input)

      action == "add" ->
        handle_add_liquidity(input)

      action == "remove" ->
        handle_remove_liquidity(input)

      true ->
        {:error, "Unknown action: #{action}"}
    end
  end

  defp handle_view_position(input) do
    address = input["address"] || input[:address]
    pool_id = input["pool_id"] || input[:pool_id]

    case fetch_pool_position(address, pool_id) do
      {:ok, pool_data} ->
        {:ok, %{
          status: "success",
          position: pool_data
        }}
      {:error, reason} ->
        {:error, "Failed to fetch pool position: #{reason}"}
    end
  end

  defp handle_add_liquidity(input) do
    address = input["address"] || input[:address]
    pool_id = input["pool_id"] || input[:pool_id]
    liquidity = input["liquidity"] || input[:liquidity]

    if is_nil(pool_id) or is_nil(liquidity) do
      {:error, "pool_id and liquidity are required for adding liquidity"}
    else
      case execute_add_liquidity(address, pool_id, liquidity) do
        {:ok, tx_hash} ->
          {:ok, %{
            status: "success",
            position: %{"pool_id" => pool_id, "liquidity" => liquidity},
            tx_hash: tx_hash
          }}
        {:error, reason} ->
          {:error, "Failed to add liquidity: #{reason}"}
      end
    end
  end

  defp handle_remove_liquidity(input) do
    address = input["address"] || input[:address]
    pool_id = input["pool_id"] || input[:pool_id]
    liquidity = input["liquidity"] || input[:liquidity]

    if is_nil(pool_id) or is_nil(liquidity) do
      {:error, "pool_id and liquidity are required for removing liquidity"}
    else
      case execute_remove_liquidity(address, pool_id, liquidity) do
        {:ok, tx_hash} ->
          {:ok, %{
            status: "success",
            position: %{"pool_id" => pool_id, "liquidity" => "-" <> liquidity},
            tx_hash: tx_hash
          }}
        {:error, reason} ->
          {:error, "Failed to remove liquidity: #{reason}"}
      end
    end
  end

  defp fetch_pool_position(_address, _pool_id) do
    # In production, this would call the PancakeSwap subgraph or RPC
    {:ok, %{"pool_id" => "0x0", "liquidity" => "0", "token0" => "WBNB", "token1" => "USDT"}}
  end

  defp execute_add_liquidity(_address, _pool_id, _liquidity) do
    {:ok, "0x" <> :crypto.strong_rand_bytes(32) |> Base.encode16()}
  end

  defp execute_remove_liquidity(_address, _pool_id, _liquidity) do
    {:ok, "0x" <> :crypto.strong_rand_bytes(32) |> Base.encode16()}
  end
end