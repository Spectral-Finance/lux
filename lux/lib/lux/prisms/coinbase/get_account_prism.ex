defmodule Lux.Prisms.Coinbase.GetAccountPrism do
  @moduledoc """
  A prism that retrieves account and portfolio information from Coinbase.

  Supports:
  - List all accounts for the authenticated user
  - Get a specific account by UUID
  - List all portfolios
  - Get portfolio breakdown

  Requires COINBASE_API_KEY and COINBASE_API_SECRET environment variables.

  ## Example - List Accounts

      iex> Lux.Prisms.Coinbase.GetAccountPrism.run(%{
      ...>   action: "list_accounts"
      ...> })
      {:ok, %{accounts: [...]}}

  ## Example - Portfolio Breakdown

      iex> Lux.Prisms.Coinbase.GetAccountPrism.run(%{
      ...>   action: "get_portfolio_breakdown",
      ...>   portfolio_uuid: "uuid-123",
      ...>   currency: "USD"
      ...> })
  """

  use Lux.Prism,
    name: "Coinbase Account & Portfolio",
    description: "List accounts, get account details, list portfolios, and get portfolio breakdown",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The action to perform",
          enum: ["list_accounts", "get_account", "list_portfolios", "get_portfolio_breakdown"]
        },
        account_uuid: %{
          type: :string,
          description: "Account UUID (required for get_account)"
        },
        portfolio_uuid: %{
          type: :string,
          description: "Portfolio UUID (required for get_portfolio_breakdown)"
        },
        currency: %{
          type: :string,
          description: "Currency for portfolio breakdown"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of results"
        },
        retail_portfolio_id: %{
          type: :string,
          description: "Retail portfolio ID filter"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        data: %{type: :object, description: "Account or portfolio data"}
      }
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    python variables: %{input: input} do
      ~PY"""
      import os
      from coinbase.rest.accounts import get_accounts, get_account
      from coinbase.rest.portfolios import get_portfolios, get_portfolio_breakdown

      api_key = os.getenv("COINBASE_API_KEY")
      api_secret = os.getenv("COINBASE_API_SECRET")

      if not api_key or not api_secret:
          raise ValueError("COINBASE_API_KEY and COINBASE_API_SECRET environment variables are required")

      from coinbase.rest.rest_base import RESTBase
      client = RESTBase(api_key=api_key, api_secret=api_secret)

      get_accounts.__self__ = client
      get_account.__self__ = client
      get_portfolios.__self__ = client
      get_portfolio_breakdown.__self__ = client

      action = input.get("action")
      result = {"action": action}

      if action == "list_accounts":
          params = {}
          if input.get("limit"): params["limit"] = input.get("limit")
          if input.get("retail_portfolio_id"): params["retail_portfolio_id"] = input.get("retail_portfolio_id")
          resp = get_accounts(**params)
          result["data"] = resp.data if hasattr(resp, 'data') else resp
          result["account_count"] = len(result["data"]) if isinstance(result["data"], list) else 0

      elif action == "get_account":
          account_uuid = input.get("account_uuid")
          if not account_uuid:
              raise ValueError("account_uuid is required for get_account")
          resp = get_account(account_uuid)
          result["data"] = resp.data if hasattr(resp, 'data') else resp

      elif action == "list_portfolios":
          resp = get_portfolios()
          result["data"] = resp.data if hasattr(resp, 'data') else resp
          result["portfolio_count"] = len(result["data"]) if isinstance(result["data"], list) else 0

      elif action == "get_portfolio_breakdown":
          portfolio_uuid = input.get("portfolio_uuid")
          if not portfolio_uuid:
              raise ValueError("portfolio_uuid is required for get_portfolio_breakdown")
          params = {}
          if input.get("currency"): params["currency"] = input.get("currency")
          resp = get_portfolio_breakdown(portfolio_uuid, **params)
          result["data"] = resp.data if hasattr(resp, 'data') else resp

      else:
          raise ValueError(f"Unknown action: {action}")

      result
      """
    end
    |> handle_python_result()
  end

  defp handle_python_result(result) when is_map(result) do
    case Map.get(result, "error") do
      nil -> {:ok, result}
      err when is_binary(err) -> {:error, err}
      _ -> {:ok, result}
    end
  end

  defp handle_python_result({:error, error}) do
    {:error, error}
  end
end
