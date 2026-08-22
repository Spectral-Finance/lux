defmodule Lux.Prisms.Binance.SpotOpenOrdersPrism do
  @moduledoc """
  A Prism for querying all current open spot orders on Binance.

  ## Examples

      iex> Lux.Prisms.Binance.SpotOpenOrdersPrism.run(%{symbol: "BTCUSDT", api_key: "key", secret_key: "secret"})
      {:ok, [%{"orderId" => 123456, "symbol" => "BTCUSDT", "price" => "95000.00"}]}
  """

  use Lux.Prism,
    name: "Binance Spot Open Orders Prism",
    description: "Queries all current open spot orders on Binance.",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Optional trading pair symbol (e.g. 'BTCUSDT')"}
      }
    }

  alias Lux.Binance.Client

  def handler(input, context) do
    opts = build_opts(input, context)
    params = build_params(input)

    case Client.request(:get, :spot, "/api/v3/openOrders", params, opts) do
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
