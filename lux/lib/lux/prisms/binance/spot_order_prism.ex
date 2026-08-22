defmodule Lux.Prisms.Binance.SpotOrderPrism do
  @moduledoc """
  A Prism for placing new spot orders (LIMIT, MARKET, etc.) on Binance.

  ## Examples

      iex> Lux.Prisms.Binance.SpotOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   timeInForce: "GTC",
      ...>   quantity: "0.01",
      ...>   price: "95000.00",
      ...>   api_key: "key",
      ...>   secret_key: "secret"
      ...> })
      {:ok, %{"orderId" => 123456, "status" => "NEW", "symbol" => "BTCUSDT"}}
  """

  use Lux.Prism,
    name: "Binance Spot Order Prism",
    description: "Places a new spot order on Binance Exchange.",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair (e.g. 'BTCUSDT')"},
        side: %{type: :string, enum: ["BUY", "SELL"], description: "Order side"},
        type: %{
          type: :string,
          enum: ["LIMIT", "MARKET", "STOP_LOSS", "STOP_LOSS_LIMIT", "TAKE_PROFIT", "TAKE_PROFIT_LIMIT", "LIMIT_MAKER"],
          description: "Order type"
        },
        timeInForce: %{type: :string, enum: ["GTC", "IOC", "FOK"], description: "Time in force"},
        quantity: %{type: :number, description: "Order quantity"},
        price: %{type: :number, description: "Order price"},
        stopPrice: %{type: :number, description: "Stop trigger price"},
        newClientOrderId: %{type: :string, description: "Custom order ID"}
      },
      required: ["symbol", "side", "type"]
    }

  alias Lux.Binance.Client

  def handler(input, context) do
    opts = build_opts(input, context)
    order_params = build_order_params(input)

    case Client.request(:post, :spot, "/api/v3/order", order_params, opts) do
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
