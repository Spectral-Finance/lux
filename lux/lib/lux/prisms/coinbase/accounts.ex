defmodule Lux.Prisms.Coinbase.AccountsPrism do
  @moduledoc """
  Aggregates Coinbase account balances and total USD portfolio valuation.
  """

  use Lux.Prism,
    name: "Coinbase Accounts Prism",
    description: "Calculates net USD value across Coinbase asset accounts",
    input_schema: %{
      type: :object,
      properties: %{
        accounts: %{type: :array, description: "Raw accounts list from Coinbase API"},
        prices: %{type: :object, description: "USD price map for assets"}
      },
      required: ["accounts"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_portfolio_usd: %{type: :number},
        accounts: %{type: :array}
      },
      required: ["total_portfolio_usd", "accounts"]
    }

  alias Lux.Integrations.Coinbase.AccountManager

  def handler(input, _ctx) do
    accounts = Map.get(input, :accounts) || Map.get(input, "accounts", [])
    prices = Map.get(input, :prices) || Map.get(input, "prices", %{})

    result = AccountManager.aggregate_accounts(accounts, prices)
    {:ok, result}
  end
end
