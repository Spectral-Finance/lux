defmodule Lux.Prisms.Binance.FuturesOrderPrism do
  @moduledoc """
  A Prism for placing new USD-M Futures orders (LIMIT, MARKET, STOP, etc.) on Binance Futures.

  ## Examples

      iex> Lux.Prisms.Binance.FuturesOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   timeInForce: "GTC",
      ...>   quantity: "0.01",
      ...>   price: "95000.00",
      ...>   api_key: "key",
      ...>   secret_key: "secret"
      ...> })
      {:ok, %{"orderId" => 987654, "status" => "NEW", "symbol" => "BTCUSDT"}}
  """

  use Lux.Prism,
    name: "Binance Futures Order Prism",
    description: "Places a new USD-M Futures order on Binance Futures Exchange.",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Futures trading pair (e.g. 'BTCUSDT')"},
        side: %{type: :string, enum: ["BUY", "SELL"], description: "Order side"},
        positionSide: %{type: :string, enum: ["BOTH", "LONG", "SHORT"], default: "BOTH", description: "Position side"},
        type: %{
          type: :string,
          enum: ["LIMIT", "MARKET", "STOP", "STOP_MARKET", "TAKE_PROFIT", "TAKE_PROFIT_MARKET", "TRAILING_STOP_MARKET"],
          description: "Order type"
        },
        timeInForce: %{type: :string, enum: ["GTC", "IOC", "FOK", "GTX"], description: "Time in force"},
        quantity: %{type: :number, description: "Order quantity"},
        price: %{type: :number, description: "Order price"},
        stopPrice: %{type: :number, description: "Stop price"},
        reduceOnly: %{type: :boolean, default: false, description: "Reduce only flag"},
        newClientOrderId: %{type: :string, description: "Custom client order ID"}
      },
      required: ["symbol", "side", "type"]
    }

  alias Lux.Binance.Client

  def handler(input, context) do
    opts = build_opts(input, context)
    order_params = build_order_params(input)

    case Client.request(:post, :futures, "/fapi/v1/order", order_params, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_order_params(input) do
    input
    |> Map.drop([:api_key, :secret_key, :testnet, :recv_window, :req_options, "api_key", "secret_key", "testnet", "recv_window", "req_options"])
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      case to_string_val(v) do
        nil -> acc
        val -> Map.put(acc, to_string(k), val)
      end
    end)
  end

  defp to_string_val(nil), do: nil
  defp to_string_val(v) when is_binary(v), do: v
  defp to_string_val(v) when is_boolean(v), do: to_string(v)
  defp to_string_val(v) when is_integer(v), do: Integer.to_string(v)
  defp to_string_val(v) when is_float(v), do: Float.to_string(v)
  defp to_string_val(v) when is_atom(v), do: Atom.to_string(v)
  defp to_string_val(v), do: inspect(v)

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
