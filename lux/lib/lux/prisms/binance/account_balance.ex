defmodule Lux.Prisms.Binance.AccountBalancePrism do
  @moduledoc """
  Aggregates spot wallet balances and computes total portfolio value in USDT.
  """

  use Lux.Prism,
    name: "Binance Account Balance",
    description: "Calculates total asset equity across Binance Spot balances",
    input_schema: %{
      type: :object,
      properties: %{
        balances: %{type: :array, description: "List of account balance items"},
        prices: %{type: :object, description: "Current market prices mapping"}
      },
      required: ["balances"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_spot_usdt: %{type: :number},
        balances: %{type: :array}
      },
      required: ["total_spot_usdt", "balances"]
    }

  alias Lux.Integrations.Binance.Portfolio

  def handler(input, _ctx) do
    balances = Map.get(input, :balances) || Map.get(input, "balances", [])
    prices = Map.get(input, :prices) || Map.get(input, "prices", %{})

    result = Portfolio.aggregate_spot_balances(balances, prices)
    {:ok, result}
  end
end
