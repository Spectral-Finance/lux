defmodule Lux.Lenses.Binance.AccountInfoLens do
  @moduledoc """
  A lens that fetches account information from the Binance API.

  Retrieves balances, positions (futures), and account status for both
  spot and futures trading accounts.

  Unlike standard Lux lenses that use the `Lux.Lens` macro, this lens
  uses the Binance Client directly for authenticated (signed) requests.

  ## Examples

      # Get spot account info
      iex> Lux.Lenses.Binance.AccountInfoLens.focus(%{
      ...>   type: "spot_account"
      ...> })
      {:ok, %{
        balances: [%{asset: "BTC", free: "0.001", locked: "0.0"}],
        account_type: "SPOT",
        can_trade: true
      }}

      # Get futures account info
      iex> Lux.Lenses.Binance.AccountInfoLens.focus(%{
      ...>   type: "futures_account"
      ...> })
      {:ok, %{
        total_wallet_balance: "10000.00",
        positions: [...],
        available_balance: "5000.00"
      }}

      # Get open orders
      iex> Lux.Lenses.Binance.AccountInfoLens.focus(%{
      ...>   type: "open_orders",
      ...>   symbol: "BTCUSDT"
      ...> })
      {:ok, %{orders: [...]}}
  """

  alias Lux.Integrations.Binance.Client

  require Logger

  @doc """
  Returns the lens metadata.
  """
  def view do
    %{
      name: "Binance Account Info",
      description: "Fetches account information and portfolio data from Binance",
      schema: %{
        type: :object,
        properties: %{
          type: %{
            type: :string,
            description: "Type of account data to fetch",
            enum: ["spot_account", "futures_account", "open_orders", "trade_history", "futures_positions"]
          },
          symbol: %{
            type: :string,
            description: "Trading pair symbol (required for open_orders and trade_history)"
          },
          limit: %{
            type: :integer,
            description: "Number of results to return"
          }
        },
        required: ["type"]
      }
    }
  end

  @doc """
  Focuses the lens to fetch the requested account data.

  ## Options

    * `:plug` - A Req.Test plug for testing
  """
  @spec focus(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def focus(params, opts \\ []) do
    plug = Keyword.get(opts, :plug, nil)
    type = Map.fetch!(params, :type)

    fetch_data(type, params, plug)
  end

  defp fetch_data("spot_account", _params, plug) do
    Client.request(:get, "/api/v3/account", %{}, signed: true, endpoint: :spot, plug: plug)
    |> handle_result(fn data ->
      balances =
        data["balances"]
        |> Enum.filter(fn b ->
          free = Decimal.new(b["free"])
          locked = Decimal.new(b["locked"])
          Decimal.gt?(Decimal.add(free, locked), Decimal.new("0"))
        end)
        |> Enum.map(fn b ->
          %{asset: b["asset"], free: b["free"], locked: b["locked"]}
        end)

      {:ok, %{
        balances: balances,
        account_type: data["accountType"],
        can_trade: data["canTrade"],
        can_withdraw: data["canWithdraw"],
        can_deposit: data["canDeposit"]
      }}
    end)
  end

  defp fetch_data("futures_account", _params, plug) do
    Client.request(:get, "/fapi/v2/account", %{}, signed: true, endpoint: :futures, plug: plug)
    |> handle_result(fn data ->
      positions =
        data["positions"]
        |> Enum.filter(fn p ->
          amt = Decimal.new(p["positionAmt"])
          not Decimal.eq?(amt, Decimal.new("0"))
        end)
        |> Enum.map(fn p ->
          %{
            symbol: p["symbol"],
            position_amt: p["positionAmt"],
            entry_price: p["entryPrice"],
            unrealized_profit: p["unrealizedProfit"],
            leverage: p["leverage"],
            margin_type: p["marginType"],
            liquidation_price: p["liquidationPrice"]
          }
        end)

      {:ok, %{
        total_wallet_balance: data["totalWalletBalance"],
        total_unrealized_profit: data["totalUnrealizedProfit"],
        total_margin_balance: data["totalMarginBalance"],
        available_balance: data["availableBalance"],
        positions: positions
      }}
    end)
  end

  defp fetch_data("open_orders", params, plug) do
    query = if Map.has_key?(params, :symbol), do: %{symbol: params.symbol}, else: %{}

    Client.request(:get, "/api/v3/openOrders", query, signed: true, endpoint: :spot, plug: plug)
    |> handle_result(fn orders ->
      formatted = Enum.map(orders, fn o ->
        %{
          order_id: o["orderId"],
          symbol: o["symbol"],
          side: o["side"],
          type: o["type"],
          price: o["price"],
          orig_qty: o["origQty"],
          executed_qty: o["executedQty"],
          status: o["status"],
          time_in_force: o["timeInForce"],
          time: o["time"]
        }
      end)
      {:ok, %{orders: formatted}}
    end)
  end

  defp fetch_data("trade_history", params, plug) do
    symbol = Map.fetch!(params, :symbol)
    limit = Map.get(params, :limit, 100)

    Client.request(:get, "/api/v3/myTrades", %{symbol: symbol, limit: limit}, signed: true, endpoint: :spot, plug: plug)
    |> handle_result(fn trades ->
      formatted = Enum.map(trades, fn t ->
        %{
          id: t["id"],
          order_id: t["orderId"],
          symbol: t["symbol"],
          price: t["price"],
          qty: t["qty"],
          commission: t["commission"],
          commission_asset: t["commissionAsset"],
          time: t["time"],
          is_buyer: t["isBuyer"],
          is_maker: t["isMaker"]
        }
      end)
      {:ok, %{trades: formatted}}
    end)
  end

  defp fetch_data("futures_positions", _params, plug) do
    Client.request(:get, "/fapi/v2/positionRisk", %{}, signed: true, endpoint: :futures, plug: plug)
    |> handle_result(fn positions ->
      active =
        positions
        |> Enum.filter(fn p ->
          amt = Decimal.new(p["positionAmt"])
          not Decimal.eq?(amt, Decimal.new("0"))
        end)
        |> Enum.map(fn p ->
          %{
            symbol: p["symbol"],
            position_amt: p["positionAmt"],
            entry_price: p["entryPrice"],
            mark_price: p["markPrice"],
            unrealized_profit: p["unRealizedProfit"],
            liquidation_price: p["liquidationPrice"],
            leverage: p["leverage"],
            margin_type: p["marginType"],
            notional: p["notional"]
          }
        end)

      {:ok, %{positions: active}}
    end)
  end

  defp fetch_data(type, _params, _plug) do
    {:error, "Unknown account data type: #{type}"}
  end

  defp handle_result({:ok, data}, transform_fn), do: transform_fn.(data)
  defp handle_result({:error, _} = error, _), do: error
end
