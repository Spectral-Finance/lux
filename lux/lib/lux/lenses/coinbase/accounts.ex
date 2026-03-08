defmodule Lux.Lenses.Coinbase.Accounts do
  @moduledoc """
  Lenses for Coinbase account and portfolio data.
  """

  alias Lux.Integrations.Coinbase.Client

  @spec list_accounts(map(), map()) :: {:ok, list(map())} | {:error, term()}
  def list_accounts(params \\ %{}, opts \\ %{}) do
    case Client.request(:get, "/accounts", Map.put(opts, :params, params)) do
      {:ok, %{"accounts" => accounts}} -> {:ok, Enum.map(accounts, &format_account/1)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_account(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_account(account_uuid, opts \\ %{}) do
    case Client.request(:get, "/accounts/#{account_uuid}", opts) do
      {:ok, %{"account" => account}} -> {:ok, format_account(account)}
      {:error, error} -> {:error, error}
    end
  end

  @spec list_portfolios(map()) :: {:ok, list(map())} | {:error, term()}
  def list_portfolios(opts \\ %{}) do
    case Client.request(:get, "/portfolios", opts) do
      {:ok, %{"portfolios" => portfolios}} -> {:ok, Enum.map(portfolios, &format_portfolio/1)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_portfolio(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_portfolio(portfolio_uuid, opts \\ %{}) do
    case Client.request(:get, "/portfolios/#{portfolio_uuid}", opts) do
      {:ok, %{"breakdown" => breakdown}} -> {:ok, format_portfolio_breakdown(breakdown)}
      {:error, error} -> {:error, error}
    end
  end

  defp format_account(a) do
    %{
      uuid: a["uuid"], name: a["name"], currency: a["currency"],
      available_balance: format_balance(a["available_balance"]),
      hold: format_balance(a["hold"]),
      default: a["default"], active: a["active"], type: a["type"]
    }
  end

  defp format_balance(nil), do: nil
  defp format_balance(b), do: %{value: b["value"], currency: b["currency"]}

  defp format_portfolio(p), do: %{uuid: p["uuid"], name: p["name"], type: p["type"], deleted: p["deleted"]}

  defp format_portfolio_breakdown(b) do
    %{portfolio: format_portfolio(b["portfolio"]), portfolio_balances: b["portfolio_balances"], spot_positions: b["spot_positions"]}
  end
end
