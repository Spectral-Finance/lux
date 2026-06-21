defmodule Lux.Lenses.Uniswap.GetPoolInfo do
  @moduledoc """
  Lens for fetching comprehensive pool information from Uniswap V3.

  Returns pool details including current price, tick, liquidity, fee tier,
  token pair addresses, and tick spacing.

  ## Examples

      # Get pool info by providing token addresses and fee tier
      Lux.Lenses.Uniswap.GetPoolInfo.focus(%{
        token_a: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        token_b: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        fee: 3000,
        network: "mainnet"
      })
      # => {:ok, %{
      #   pool_address: "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8",
      #   token0: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      #   token1: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      #   fee: 3000,
      #   fee_label: "0.3%",
      #   sqrt_price_x96: 1234567890,
      #   tick: -200410,
      #   price: 1850.42,
      #   liquidity: 12345678901234,
      #   unlocked: true
      # }}

      # Get pool info by pool address directly
      Lux.Lenses.Uniswap.GetPoolInfo.focus(%{
        pool_address: "0x8ad599c3a0ff1de082011efddc58f1908eb6e6d8",
        network: "mainnet"
      })
  """

  use Lux.Lens,
    name: "Uniswap.GetPoolInfo",
    description: "Fetches comprehensive pool information from Uniswap V3 including price, liquidity, and fee data",
    url: "https://eth-mainnet.g.alchemy.com/v2",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Direct pool contract address (optional if token_a, token_b, and fee are provided)"
        },
        token_a: %{
          type: :string,
          description: "First token address of the pair"
        },
        token_b: %{
          type: :string,
          description: "Second token address of the pair"
        },
        fee: %{
          type: :integer,
          description: "Fee tier in hundredths of a basis point (100, 500, 3000, or 10000)",
          enum: [100, 500, 3000, 10_000]
        },
        network: %{
          type: :string,
          description: "Network to query (mainnet, goerli, sepolia, arbitrum, optimism, polygon, base)",
          default: "mainnet"
        },
        decimals0: %{
          type: :integer,
          description: "Decimals for token0 (for price calculation)",
          default: 18
        },
        decimals1: %{
          type: :integer,
          description: "Decimals for token1 (for price calculation)",
          default: 18
        }
      },
      required: []
    }

  alias Lux.Integrations.Uniswap

  @impl true
  def after_focus(_response) do
    # This lens uses custom focus logic rather than HTTP
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
         {:ok, slot0} <- Uniswap.get_pool_slot0(pool_address),
         {:ok, liquidity} <- Uniswap.get_pool_liquidity(pool_address) do
      price = Uniswap.sqrt_price_x96_to_price(slot0.sqrt_price_x96, decimals0, decimals1)

      {:ok,
       %{
         pool_address: pool_address,
         sqrt_price_x96: slot0.sqrt_price_x96,
         tick: slot0.tick,
         price: price,
         liquidity: liquidity,
         observation_index: slot0.observation_index,
         observation_cardinality: slot0.observation_cardinality,
         fee_protocol: slot0.fee_protocol,
         unlocked: slot0.unlocked,
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
    {:error,
     "Either pool_address or (token_a, token_b, fee) must be provided"}
  end
end
