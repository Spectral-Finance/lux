defmodule Lux.Prisms.Binance.FuturesAccountPrism do
  @moduledoc """
  A Prism for retrieving USD-M Futures account info, total margin, wallet balance, and open positions summary.

  ## Examples

      iex> Lux.Prisms.Binance.FuturesAccountPrism.run(%{api_key: "key", secret_key: "secret"})
      {:ok, %{"totalInitialMargin" => "0.00000000", "totalWalletBalance" => "1000.00000000", "positions" => [...]}}
  """

  use Lux.Prism,
    name: "Binance Futures Account Prism",
    description: "Retrieves USD-M Futures account summary, margin, and balances from Binance.",
    input_schema: %{
      type: :object,
      properties: %{
        recv_window: %{type: :integer, default: 5000, description: "Receive window in milliseconds"},
        api_key: %{type: :string, description: "Binance API Key"},
        secret_key: %{type: :string, description: "Binance Secret Key"},
        testnet: %{type: :boolean, default: false, description: "Whether to use Binance Futures testnet"}
      }
    }

  alias Lux.Binance.Client

  def handler(input, context) do
    opts = build_opts(input, context)

    case Client.request(:get, :futures, "/fapi/v2/account", %{}, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_opts(input, context) do
    ctx = context || %{}
    recv_window = Map.get(input, :recv_window) || Map.get(input, "recv_window", 5000)
    api_key = Map.get(input, :api_key) || Map.get(input, "api_key") || Map.get(ctx, :api_key)
    secret_key = Map.get(input, :secret_key) || Map.get(input, "secret_key") || Map.get(ctx, :secret_key)
    testnet? = Map.get(input, :testnet) || Map.get(input, "testnet", false) || Map.get(ctx, :testnet, false)
    req_options = Map.get(input, :req_options) || Map.get(ctx, :req_options, [])

    [
      signed: true,
      api_key: api_key,
      secret_key: secret_key,
      testnet: testnet?,
      recv_window: recv_window,
      req_options: req_options
    ]
  end
end
