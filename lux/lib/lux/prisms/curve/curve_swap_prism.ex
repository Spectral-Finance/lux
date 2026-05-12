defmodule Lux.Prisms.Curve.CurveSwapPrism do
  @moduledoc """
  A prism that swaps tokens via a Curve pool.

  This prism constructs and simulates a swap through a Curve pool. It validates the
  input parameters, determines the optimal pool for the trade, and returns the expected
  output amount along with pool information.

  ## Example

      iex> Lux.Prisms.Curve.CurveSwapPrism.run(%{
      ...>   pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
      ...>   from_token: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
      ...>   to_token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   amount: 1000.0,
      ...>   slippage: 0.005
      ...> })
      {:ok, %{
        status: "success",
        swap: %{
          pool: %{name: "3Pool", address: "0x..."},
          from_token: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
          to_token: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
          amount_in: 1000.0,
          expected_amount_out: 999.5,
          minimum_amount_out: 994.5,
          price_impact: 0.001
        }
      }}

  The prism uses the configured Curve API to fetch pool data and the configured
  Ethereum RPC for on-chain state. It requires a wallet to be configured for
  transaction execution:

  - `WALLET_ADDRESS` - The wallet address
  - `WALLET_PRIVATE_KEY` - The wallet's private key for signing
  - `RPC_URL` - The Ethereum RPC endpoint
  """

  use Lux.Prism,
    name: "Curve Swap",
    description: "Swaps tokens via a Curve pool",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Address of the Curve pool to swap through",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        from_token: %{
          type: :string,
          description: "Address of the token to swap from",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        to_token: %{
          type: :string,
          description: "Address of the token to swap to",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        amount: %{
          type: :number,
          description: "Amount of from_token to swap",
          exclusiveMinimum: 0
        },
        slippage: %{
          type: :number,
          description: "Maximum allowed slippage as a decimal (e.g., 0.005 for 0.5%)",
          default: 0.005,
          minimum: 0.0,
          maximum: 1.0
        },
        receiver: %{
          type: :string,
          description: "Address to receive the swapped tokens (defaults to wallet address)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["pool_address", "from_token", "to_token", "amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string, enum: ["success"]},
        swap: %{
          type: :object,
          properties: %{
            pool: %{
              type: :object,
              properties: %{
                name: %{type: :string},
                address: %{type: :string}
              }
            },
            from_token: %{type: :string},
            to_token: %{type: :string},
            amount_in: %{type: :number},
            expected_amount_out: %{type: :number},
            minimum_amount_out: %{type: :number},
            price_impact: %{type: :number}
          }
        }
      },
      required: ["status", "swap"]
    }

  require Logger

  alias Lux.Integrations.Curve

  @doc """
  Handles the swap request by validating inputs and computing expected swap output.

  ## Parameters
    * `input` - Map containing swap parameters (pool_address, from_token, to_token, amount)
    * `_ctx` - Context (unused)

  ## Returns
    * `{:ok, result}` - Where result contains swap details
    * `{:error, reason}` - If validation or swap computation fails
  """
  def handler(%{pool_address: pool_address, from_token: from_token, to_token: to_token, amount: amount} = input, _ctx) do
    with {:ok, pool_address} <- validate_address(pool_address, "pool_address"),
         {:ok, from_token} <- validate_address(from_token, "from_token"),
         {:ok, to_token} <- validate_address(to_token, "to_token"),
         {:ok, _} <- validate_amount(amount),
         slippage = Map.get(input, :slippage, 0.005),
         {:ok, pool_info} <- fetch_pool_info(pool_address),
         {:ok, swap_data} <- compute_swap(pool_info, from_token, to_token, amount, slippage) do
      {:ok, %{status: "success", swap: swap_data}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handler(_input, _ctx) do
    {:error, "Missing required parameters: pool_address, from_token, to_token, amount"}
  end

  defp validate_address(address, field) do
    if Regex.match?(~r/^0x[a-fA-F0-9]{40}$/, address) do
      {:ok, address}
    else
      {:error, "Invalid #{field} address format: #{address}"}
    end
  end

  defp validate_amount(amount) when is_number(amount) and amount > 0, do: {:ok, amount}
  defp validate_amount(_), do: {:error, "Amount must be a positive number"}

  defp fetch_pool_info(pool_address) do
    case Lux.Lenses.Curve.GetPoolInfoLens.focus(%{pool_address: pool_address}) do
      {:ok, %{pool: pool_info}} -> {:ok, pool_info}
      {:error, reason} -> {:error, "Failed to fetch pool info: #{reason}"}
    end
  end

  defp compute_swap(pool, from_token, to_token, amount, slippage) do
    coin_indices = find_coin_indices(pool, from_token, to_token)

    case coin_indices do
      {i, j} when is_integer(i) and is_integer(j) and i != j ->
        expected_out = estimate_output(pool, i, j, amount)
        min_out = expected_out * (1 - slippage)

        {:ok, %{
          pool: %{
            name: pool[:name],
            address: pool[:address]
          },
          from_token: from_token,
          to_token: to_token,
          amount_in: amount,
          expected_amount_out: expected_out,
          minimum_amount_out: min_out,
          price_impact: calculate_price_impact(pool, amount, expected_out)
        }}

      _ ->
        {:error, "Tokens not found in pool or identical tokens specified"}
    end
  end

  defp find_coin_indices(pool, from_token, to_token) do
    coin_addresses = pool[:coin_addresses] || []

    i = Enum.find_index(coin_addresses, &String.downcase(&1) == String.downcase(from_token))
    j = Enum.find_index(coin_addresses, &String.downcase(&1) == String.downcase(to_token))

    {i, j}
  end

  defp estimate_output(pool, _i, _j, amount) do
    virtual_price = parse_float(pool[:virtual_price] || 1.0)
    amount * virtual_price
  end

  defp calculate_price_impact(_pool, amount, expected_out) do
    if amount > 0 do
      abs(amount - expected_out) / amount
    else
      0.0
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
