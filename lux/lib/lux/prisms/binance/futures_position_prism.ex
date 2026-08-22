defmodule Lux.Prisms.Binance.FuturesPositionPrism do
  @moduledoc """
  A Prism for querying USD-M Futures position risk details, entry price, mark price, leverage, and unrealized PnL.

  ## Examples

      iex> Lux.Prisms.Binance.FuturesPositionPrism.run(%{symbol: "BTCUSDT", api_key: "key", secret_key: "secret"})
      {:ok, [%{"entryPrice" => "0.00000", "leverage" => "20", "markPrice" => "95100.50", "symbol" => "BTCUSDT", "positionAmt" => "0.000"}]}
  """

  use Lux.Prism,
    name: "Binance Futures Position Prism",
    description: "Queries current USD-M Futures open position information and margin risk.",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Optional futures trading pair symbol (e.g. 'BTCUSDT')"}
      }
    }

  alias Lux.Binance.Client

  def handler(input, context) do
    opts = build_opts(input, context)
    params = build_params(input)

    case Client.request(:get, :futures, "/fapi/v2/positionRisk", params, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_params(input) do
    case Map.get(input, :symbol) || Map.get(input, "symbol") do
      nil -> %{}
      symbol -> %{symbol: symbol}
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
