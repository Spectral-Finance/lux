defmodule Lux.Prisms.Binance.Exchange do
  @moduledoc """
  Prism for Binance exchange request, order, stream, portfolio, and rate-limit plans.
  """

  use Lux.Prism,
    name: "Binance Exchange",
    description:
      "Builds Binance spot/futures REST, WebSocket, order, portfolio, and rate-limit plans",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "rest_request",
            "spot_order",
            "futures_order",
            "order_management",
            "websocket",
            "portfolio",
            "rate_limits",
            "trading_system"
          ]
        },
        params: %{type: :object}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status", "result"]
    }

  alias Lux.Integrations.Binance.Exchange, as: Binance

  def handler(%{action: "rest_request"} = input, _ctx),
    do: input |> params() |> Binance.rest_request_plan() |> normalize()

  def handler(%{action: "spot_order"} = input, _ctx),
    do: input |> params() |> Binance.spot_order_plan() |> normalize()

  def handler(%{action: "futures_order"} = input, _ctx),
    do: input |> params() |> Binance.futures_order_plan() |> normalize()

  def handler(%{action: "order_management"} = input, _ctx) do
    input |> params() |> Binance.order_management_plan() |> normalize()
  end

  def handler(%{action: "websocket"} = input, _ctx),
    do: input |> params() |> Binance.websocket_plan() |> normalize()

  def handler(%{action: "portfolio"} = input, _ctx),
    do: input |> params() |> Binance.portfolio_snapshot() |> normalize()

  def handler(%{action: "rate_limits"} = input, _ctx) do
    params = params(input)

    params
    |> Map.get(:requests, [])
    |> Binance.rate_limit_report(Map.get(params, :opts, %{}))
    |> normalize()
  end

  def handler(%{action: "trading_system"} = input, _ctx),
    do: input |> params() |> Binance.trading_system_plan() |> normalize()

  def handler(_input, _ctx), do: {:error, "Unsupported Binance exchange operation"}

  defp params(input), do: Map.get(input, :params, %{})
  defp normalize({:ok, result}), do: {:ok, %{status: "success", result: result}}
  defp normalize({:error, reason}), do: {:error, reason}
end
