defmodule Lux.Prisms.Trading.Hyperliquid.ManageMarginPrism do
  @moduledoc """
  Evaluates margin ratio, account equity, free collateral, and margin call status for Hyperliquid.
  """

  use Lux.Prism,
    name: "Manage Hyperliquid Margin",
    description: "Evaluates account margin requirements, leverage bounds, and free collateral",
    input_schema: %{
      type: :object,
      properties: %{
        wallet_balance: %{type: :number, description: "Account collateral balance in USD"},
        positions: %{type: :array, items: %{type: :object}, description: "List of open position maps"}
      },
      required: ["wallet_balance", "positions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        account_equity: %{type: :number},
        total_notional: %{type: :number},
        free_collateral: %{type: :number},
        margin_ratio: %{type: :number},
        margin_call: %{type: :boolean}
      },
      required: ["account_equity", "free_collateral", "margin_ratio", "margin_call"]
    }

  alias Lux.Trading.Hyperliquid.MarginController

  def handler(input, _ctx) do
    balance = Map.get(input, :wallet_balance) || Map.get(input, "wallet_balance", 0.0)
    positions = Map.get(input, :positions) || Map.get(input, "positions", [])

    result = MarginController.evaluate_account_margin(balance * 1.0, positions)

    {:ok,
     %{
       account_equity: result.account_equity,
       total_notional: result.total_notional,
       free_collateral: result.free_collateral,
       margin_ratio: result.margin_ratio,
       margin_call: result.margin_call?
     }}
  end
end
