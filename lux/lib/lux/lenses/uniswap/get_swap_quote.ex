defmodule Lux.Lenses.Uniswap.GetSwapQuote do
  @moduledoc """
  Lens for fetching a swap quote from Uniswap V3 using the Quoter contract.

  Returns the estimated output amount for a given input amount and token path.

  ## Examples

      Lux.Lenses.Uniswap.GetSwapQuote.focus(%{
        token_in: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        token_out: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        fee: 3000,
        amount_in: 1000000000000000000,
        network: "mainnet"
      })
  """

  use Lux.Lens,
    name: "Uniswap.GetSwapQuote",
    description: "Fetches estimated output amount for a single swap path via Uniswap V3 Quoter",
    url: "https://eth-mainnet.g.alchemy.com/v2",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        token_in: %{
          type: :string,
          description: "Token input contract address"
        },
        token_out: %{
          type: :string,
          description: "Token output contract address"
        },
        fee: %{
          type: :integer,
          description: "Fee tier"
        },
        amount_in: %{
          type: :integer,
          description: "Amount of token_in (in Wei/atomic units)"
        },
        sqrt_price_limit_x96: %{
          type: :integer,
          description: "Optional price limit",
          default: 0
        },
        network: %{
          type: :string,
          description: "Network to query",
          default: "mainnet"
        }
      },
      required: ["token_in", "token_out", "fee", "amount_in"]
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
    token_in = Map.fetch!(params, :token_in)
    token_out = Map.fetch!(params, :token_out)
    fee = Map.fetch!(params, :fee)
    amount_in = Map.fetch!(params, :amount_in)
    sqrt_price_limit_x96 = Map.get(params, :sqrt_price_limit_x96, 0)
    network = Map.get(params, :network, "mainnet")

    # Configure network
    Application.put_env(:lux, Uniswap, network: network)

    with {:ok, _} <- Uniswap.validate_address(token_in),
         {:ok, _} <- Uniswap.validate_address(token_out),
         {:ok, _} <- Uniswap.validate_fee_tier(fee),
         {:ok, amount_out} <- Uniswap.get_swap_quote(token_in, token_out, fee, amount_in, sqrt_price_limit_x96) do
      {:ok,
       %{
         amount_in: amount_in,
         amount_out: amount_out,
         token_in: token_in,
         token_out: token_out,
         fee: fee,
         network: network
       }}
    end
  end
end
