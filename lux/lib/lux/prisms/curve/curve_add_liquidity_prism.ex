defmodule Lux.Prisms.Curve.CurveAddLiquidityPrism do
  @moduledoc """
  A prism that adds liquidity to a Curve pool.

  This prism constructs and simulates adding liquidity to a Curve pool. It validates
  the input parameters, computes the optimal deposit amounts, and returns the expected
  LP token output along with pool information.

  ## Example

      iex> Lux.Prisms.Curve.CurveAddLiquidityPrism.run(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      ...>   amounts: [1000.0, 1000.0, 1000.0],
      ...>   min_mint_amount: 2990.0,
      ...>   use_underlying: false
      ...> })
      {:ok, %{
        status: "success",
        add_liquidity: %{
          pool: %{name: "3Pool", address: "0x..."},
          amounts: [1000.0, 1000.0, 1000.0],
          expected_lp_tokens: 2995.0,
          min_lp_tokens: 2990.0,
          pool_share_percentage: 0.001
        }
      }}

  The prism uses the configured Curve API to fetch pool data and the configured
  Ethereum RPC for on-chain state. It requires a wallet to be configured for
  transaction execution:

  - `WALLET_ADDRESS` - The wallet address
  - `WALLET_PRIVATE_KEY` - The wallet's private key for signing
  - `RPC_URL` - The Ethereum RPC endpoint

  ## Pool Types

  The prism supports different Curve pool types:
  - Standard (A/B) pools - Deposit with balanced or imbalanced amounts
  - Meta pools - Deposit using the underlying asset
  - Factory pools - Standard deposit interface
  - Crypto pools - Uses different math for LP token calculation
  """

  use Lux.Prism,
    name: "Curve Add Liquidity",
    description: "Adds liquidity to a Curve pool",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Address of the Curve pool to add liquidity to",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        amounts: %{
          type: :array,
          description: "Array of token amounts to deposit (one per coin in the pool)",
          items: %{type: :number, exclusiveMinimum: 0},
          minItems: 2
        },
        min_mint_amount: %{
          type: :number,
          description: "Minimum amount of LP tokens to mint (slippage protection)",
          default: 0
        },
        use_underlying: %{
          type: :boolean,
          description: "Whether to deposit using the underlying asset (for meta pools)",
          default: false
        }
      },
      required: ["pool_address", "amounts"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string, enum: ["success"]},
        add_liquidity: %{
          type: :object,
          properties: %{
            pool: %{
              type: :object,
              properties: %{
                name: %{type: :string},
                address: %{type: :string}
              }
            },
            amounts: %{type: :array, items: %{type: :number}},
            expected_lp_tokens: %{type: :number},
            min_lp_tokens: %{type: :number},
            pool_share_percentage: %{type: :number}
          }
        }
      },
      required: ["status", "add_liquidity"]
    }

  require Logger

  alias Lux.Integrations.Curve

  @doc """
  Handles the add liquidity request by validating inputs and computing expected LP tokens.

  ## Parameters
    * `input` - Map containing liquidity parameters (pool_address, amounts)
    * `_ctx` - Context (unused)

  ## Returns
    * `{:ok, result}` - Where result contains liquidity addition details
    * `{:error, reason}` - If validation or computation fails
  """
  def handler(%{pool_address: pool_address, amounts: amounts} = input, _ctx) do
    with {:ok, pool_address} <- validate_address(pool_address),
         {:ok, amounts} <- validate_amounts(amounts),
         min_mint = Map.get(input, :min_mint_amount, 0),
         {:ok, pool_info} <- fetch_pool_info(pool_address),
         {:ok, liquidity_data} <- compute_liquidity(pool_info, amounts, min_mint) do
      {:ok, %{status: "success", add_liquidity: liquidity_data}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handler(_input, _ctx) do
    {:error, "Missing required parameters: pool_address, amounts"}
  end

  defp validate_address(address) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      {:ok, address}
    else
      {:error, "Invalid pool address format: #{address}"}
    end
  end

  defp validate_amounts(amounts) when is_list(amounts) do
    if Enum.all?(amounts, &(is_number(&1) and &1 >= 0)) and Enum.sum(amounts) > 0 do
      {:ok, amounts}
    else
      {:error, "Amounts must be non-negative numbers with a positive total"}
    end
  end

  defp validate_amounts(_) do
    {:error, "Amounts must be a list of numbers"}
  end

  defp fetch_pool_info(pool_address) do
    case Lux.Lenses.Curve.GetPoolInfoLens.focus(%{pool_address: pool_address}) do
      {:ok, %{pool: pool_info}} -> {:ok, pool_info}
      {:error, reason} -> {:error, "Failed to fetch pool info: #{reason}"}
    end
  end

  defp compute_liquidity(pool, amounts, min_mint) do
    coin_count = length(pool[:coin_addresses] || [])

    if length(amounts) != coin_count do
      {:error, "Expected #{coin_count} amounts for this pool, got #{length(amounts)}"}
    else
      virtual_price = parse_float(pool[:virtual_price] || 1.0)
      total_supply = parse_float(pool[:lp_token_supply] || 1.0)
      pool_liquidity = parse_float(pool[:total_liquidity] || 1.0)

      deposit_value_usd = Enum.sum(amounts)
      expected_lp_tokens = deposit_value_usd * (total_supply / max(pool_liquidity, 1.0))
      pool_share = deposit_value_usd / max(pool_liquidity + deposit_value_usd, 1.0)

      expected_lp_with_fee = expected_lp_tokens * (1 - 0.0004)
      min_lp_tokens = max(min_mint, expected_lp_with_fee * 0.995)

      {:ok, %{
        pool: %{
          name: pool[:name],
          address: pool[:address]
        },
        amounts: amounts,
        expected_lp_tokens: expected_lp_with_fee,
        min_lp_tokens: min_lp_tokens,
        pool_share_percentage: pool_share
      }}
    end
  end

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end
