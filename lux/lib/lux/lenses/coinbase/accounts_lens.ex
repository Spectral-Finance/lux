defmodule Lux.Lenses.Coinbase.AccountsLens do
  @moduledoc """
  A lens for fetching account information from Coinbase.

  Returns a list of all trading accounts including balances,
  currency details, and account status.

  ## Examples

      iex> Lux.Lenses.Coinbase.AccountsLens.focus()
      {:ok, %{accounts: [
        %{
          uuid: "abc-123",
          name: "BTC Wallet",
          currency: "BTC",
          available_balance: %{value: "1.5", currency: "BTC"},
          hold: %{value: "0.0", currency: "BTC"}
        }
      ]}}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Accounts",
    description: "Fetches trading accounts from Coinbase Advanced Trade API",
    url: "https://api.coinbase.com/api/v3/brokerage/accounts",
    method: :get,
    headers: Coinbase.headers(),
    auth: Coinbase.auth(),
    schema: %{
      type: :object,
      properties: %{
        limit: %{
          type: :integer,
          description: "Maximum number of accounts to return (max 250)"
        },
        cursor: %{
          type: :string,
          description: "Pagination cursor for the next page"
        }
      }
    }

  def after_focus(%{"accounts" => accounts} = response) do
    formatted =
      Enum.map(accounts, fn account ->
        %{
          uuid: account["uuid"],
          name: account["name"],
          currency: account["currency"],
          available_balance: account["available_balance"],
          hold: account["hold"],
          type: account["type"],
          ready: account["ready"],
          default: account["default"],
          active: account["active"],
          created_at: account["created_at"],
          updated_at: account["updated_at"]
        }
      end)

    result = %{accounts: formatted}

    result =
      if response["cursor"], do: Map.put(result, :cursor, response["cursor"]), else: result

    result =
      if response["has_next"],
        do: Map.put(result, :has_next, response["has_next"]),
        else: result

    {:ok, result}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end
