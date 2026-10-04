defmodule Lux.Lenses.Coinbase.AccountLens do
  @moduledoc """
  Lens for loading user account balances and portfolio valuation breakdown from Coinbase Advanced Trade.
  """
  use Lux.Lens,
    name: "Coinbase Account Lens",
    description: "Fetches user balances, accounts, and portfolio breakdowns from Coinbase Advanced Trade",
    schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["get_accounts", "get_account", "get_portfolio_breakdown"],
          description: "Account query action"
        },
        account_uuid: %{
          type: :string,
          description: "Specific account identifier"
        },
        portfolio_uuid: %{
          type: :string,
          description: "Specific portfolio identifier"
        }
      },
      required: ["action"]
    }

  require Logger
  import Lux.Python

  @impl true
  def focus(params) do
    action = Map.get(params, "action") || Map.get(params, :action) || "get_accounts"
    account_uuid = Map.get(params, "account_uuid") || Map.get(params, :account_uuid)
    portfolio_uuid = Map.get(params, "portfolio_uuid") || Map.get(params, :portfolio_uuid)

    python_result =
      python variables: %{
               action: action,
               account_uuid: account_uuid,
               portfolio_uuid: portfolio_uuid
             } do
        ~PY"""
        from lux.coinbase.rest import CoinbaseRestClient

        client = CoinbaseRestClient()
        res = {}

        if action == "get_accounts":
            accounts = client.get_accounts()
            res = {"status": "ok", "accounts": [a.model_dump() for a in accounts]}
        elif action == "get_account":
            account = client.get_account(account_uuid)
            res = {"status": "ok", "account": account.model_dump()}
        elif action == "get_portfolio_breakdown":
            summary = client.get_portfolio_breakdown(portfolio_uuid=portfolio_uuid)
            res = {"status": "ok", "portfolio": summary.model_dump()}
        else:
            res = {"status": "error", "message": f"Unsupported action {action}"}

        res
        """
      end

    after_focus(python_result)
  end

  @doc """
  Transforms the response into a structured Elixir map.
  """
  def after_focus(%{"status" => "ok"} = result) do
    {:ok, result}
  end

  def after_focus(%{"status" => "error", "message" => msg}) do
    {:error, msg}
  end

  def after_focus(%{"error" => err}) do
    {:error, err}
  end

  def after_focus(other) when is_map(other) do
    {:ok, other}
  end

  def after_focus(err) do
    {:error, "Unexpected account response: #{inspect(err)}"}
  end
end
