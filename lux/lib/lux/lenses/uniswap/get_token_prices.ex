defmodule Lux.Lenses.Uniswap.GetTokenPrices do
  @moduledoc """
  Lens for fetching relative token prices for a Uniswap V3 pool.

  Returns the price of token0 in terms of token1 and vice versa.

  ## Examples

      Lux.Lenses.Uniswap.GetTokenPrices.focus(%{
        token_a: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        token_b: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        fee: 3000,
        network: "mainnet"
      })
  """

  use Lux.Lens,
    name: "Uniswap.GetTokenPrices",
    description: "Computes current token prices (price of token0 in token1 and vice-versa) for a pool",
    url: "https://eth-mainnet.g.alchemy.com/v2",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Pool contract address (optional if token_a, token_b, fee are provided)"
        },
        token_a: %{
          type: :string,
          description: "First token address"
        },
        token_b: %{
          type: :string,
          description: "Second token address"
        },
        fee: %{
          type: :integer,
          description: "Fee tier"
        },
        decimals0: %{
          type: :integer,
          description: "Decimals for token0",
          default: 18
        },
        decimals1: %{
          type: :integer,
          description: "Decimals for token1",
          default: 18
        },
        network: %{
          type: :string,
          description: "Network to query",
          default: "mainnet"
        }
      },
      required: []
    }

  alias Lux.Integrations.Uniswap

  @impl true
  def after_focus(_response) do
    {:ok, %{}}
  end

  @doc """
  Custom focus implementation that queries Uniswap V3 on-chain data.
  """
  def focus(params, _opts) do
    network = Map.get(params, :network, "mainnet")
    decimals0 = Map.get(params, :decimals0, 18)
    decimals1 = Map.get(params, :decimals1, 18)

    # Configure network
    Application.put_env(:lux, Uniswap, network: network)

    with {:ok, pool_address} <- resolve_pool_address(params),
         {:ok, slot0} <- Uniswap.get_pool_slot0(pool_address) do
      price_0_in_1 = Uniswap.sqrt_price_x96_to_price(slot0.sqrt_price_x96, decimals0, decimals1)
      price_1_in_0 = if price_0_in_1 > 0, do: 1.0 / price_0_in_1, else: 0.0

      {:ok,
       %{
         pool_address: pool_address,
         price_0_in_1: price_0_in_1,
         price_1_in_0: price_1_in_0,
         sqrt_price_x96: slot0.sqrt_price_x96,
         tick: slot0.tick,
         network: network
       }}
    end
  end

  defp resolve_pool_address(%{pool_address: address}) when is_binary(address) and address != "" do
    Uniswap.validate_address(address)
  end

  defp resolve_pool_address(%{token_a: token_a, token_b: token_b, fee: fee}) do
    with {:ok, _} <- Uniswap.validate_address(token_a),
         {:ok, _} <- Uniswap.validate_address(token_b),
         {:ok, _} <- Uniswap.validate_fee_tier(fee) do
      Uniswap.get_pool(token_a, token_b, fee)
    end
  end

  defp resolve_pool_address(_) do
    {:error, "Either pool_address or (token_a, token_b, fee) must be provided"}
  end
end
