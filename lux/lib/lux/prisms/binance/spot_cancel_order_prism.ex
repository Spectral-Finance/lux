defmodule Lux.Prisms.Binance.SpotCancelOrderPrism do
  @moduledoc """
  A Prism for cancelling an active spot order on Binance.

  ## Examples

      iex> Lux.Prisms.Binance.SpotCancelOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   orderId: 123456,
      ...>   api_key: "key",
      ...>   secret_key: "secret"
      ...> })
      {:ok, %{"orderId" => 123456, "status" => "CANCELED", "symbol" => "BTCUSDT"}}
  """

  use Lux.Prism,
    name: "Binance Spot Cancel Order Prism",
    description: "Cancels an active spot order on Binance.",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair (e.g. 'BTCUSDT')"},
        orderId: %{type: :integer, description: "Binance order ID"},
        origClientOrderId: %{type: :string, description: "Client custom order ID"}
      },
      required: ["symbol"]
    }

  alias Lux.Binance.Client

  def handler(input, context) do
    opts = build_opts(input, context)
    cancel_params = build_cancel_params(input)

    case Client.request(:delete, :spot, "/api/v3/order", cancel_params, opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_cancel_params(input) do
    input
    |> Map.drop([:api_key, :secret_key, :testnet, :recv_window, :req_options, "api_key", "secret_key", "testnet", "recv_window", "req_options"])
    |> Enum.map(fn {k, v} -> {to_string(k), to_string_val(v)} end)
    |> Map.new()
  end

  defp to_string_val(v) when is_binary(v), do: v
  defp to_string_val(v), do: to_string(v)

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
