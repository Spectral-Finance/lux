defmodule Lux.Lenses.Binance.AccountInfo do
  @moduledoc """
  A lens for fetching account information from the Binance API.
  """

  alias Lux.Integrations.Binance
  alias Lux.Integrations.Binance.Client

  use Lux.Lens,
    name: "Binance Account Info",
    description: "Fetches account balances and positions from Binance",
    url: "#{Binance.spot_base_url()}/api/v3/account",
    method: :get,
    headers: Binance.headers(),
    schema: %{
      type: :object,
      properties: %{endpoint: %{type: :string, enum: ["balances", "positions", "futures_account"]}},
      required: ["endpoint"]
    }

  @impl true
  def before_focus(params), do: %{url: Binance.spot_base_url(), params: params}

  @impl true
  def after_focus(%{"params" => params}), do: fetch(params)
  def after_focus(params) when is_map(params), do: fetch(params)

  defp fetch(params) do
    endpoint = to_string(params[:endpoint] || params["endpoint"])
    plug = params[:plug] || params["plug"]
    opts = %{signed: true}
    opts = if plug, do: Map.put(opts, :plug, plug), else: opts

    case endpoint do
      "balances" -> fetch_balances(opts)
      "positions" -> fetch_positions(opts)
      "futures_account" -> fetch_futures_account(opts)
      other -> {:error, "Unknown endpoint: #{other}"}
    end
  end

  defp fetch_balances(opts) do
    case Client.request(:get, "/api/v3/account", opts) do
      {:ok, %{"balances" => balances}} ->
        {:ok, %{balances: balances
          |> Enum.filter(&(&1["free"] != "0.00000000" or &1["locked"] != "0.00000000"))
          |> Enum.map(&%{asset: &1["asset"], free: &1["free"], locked: &1["locked"]})
        }}
      {:error, e} -> {:error, e}
    end
  end

  defp fetch_positions(opts) do
    case Client.request(:get, "/fapi/v2/positionRisk", Map.put(opts, :futures, true)) do
      {:ok, positions} when is_list(positions) ->
        {:ok, %{positions: positions
          |> Enum.filter(&(&1["positionAmt"] != "0" and &1["positionAmt"] != "0.000"))
          |> Enum.map(&%{
            symbol: &1["symbol"], position_amt: &1["positionAmt"],
            entry_price: &1["entryPrice"], mark_price: &1["markPrice"],
            unrealized_profit: &1["unRealizedProfit"], leverage: &1["leverage"],
            margin_type: &1["marginType"], liquidation_price: &1["liquidationPrice"]
          })
        }}
      {:error, e} -> {:error, e}
    end
  end

  defp fetch_futures_account(opts) do
    case Client.request(:get, "/fapi/v2/account", Map.put(opts, :futures, true)) do
      {:ok, d} ->
        {:ok, %{
          total_wallet_balance: d["totalWalletBalance"],
          total_unrealized_profit: d["totalUnrealizedProfit"],
          total_margin_balance: d["totalMarginBalance"],
          available_balance: d["availableBalance"],
          max_withdraw_amount: d["maxWithdrawAmount"]
        }}
      {:error, e} -> {:error, e}
    end
  end
end
