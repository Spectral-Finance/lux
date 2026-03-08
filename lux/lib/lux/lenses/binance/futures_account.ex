defmodule Lux.Lenses.Binance.FuturesAccount do
  @moduledoc """
  Lens for Binance Futures account: positions, balances, income history.
  """

  alias Lux.Integrations.Binance.Client

  def focus(params, _opts \\ []) do
    action = params[:action] || params["action"] || "positions"
    api_key = params[:api_key] || params["api_key"]
    api_secret = params[:api_secret] || params["api_secret"]
    plug = params[:plug]

    client_opts = %{signed: true, futures: true}
    client_opts = if api_key, do: Map.put(client_opts, :api_key, api_key), else: client_opts
    client_opts = if api_secret, do: Map.put(client_opts, :secret_key, api_secret), else: client_opts
    client_opts = if plug, do: Map.put(client_opts, :plug, plug), else: client_opts

    case action do
      "positions" -> get_positions(client_opts)
      "balance" -> get_balance(client_opts)
      "income" -> get_income(params, client_opts)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp get_positions(opts) do
    case Client.request(:get, "/fapi/v2/positionRisk", opts) do
      {:ok, positions} when is_list(positions) ->
        active = positions
          |> Enum.filter(fn p -> parse_float(p["positionAmt"]) != 0.0 end)
          |> Enum.map(fn p ->
            %{
              symbol: p["symbol"],
              side: if(parse_float(p["positionAmt"]) > 0, do: "LONG", else: "SHORT"),
              quantity: parse_float(p["positionAmt"]) |> abs(),
              entry_price: parse_float(p["entryPrice"]),
              mark_price: parse_float(p["markPrice"]),
              unrealized_pnl: parse_float(p["unRealizedProfit"]),
              leverage: parse_int(p["leverage"]),
              margin_type: p["marginType"],
              liquidation_price: parse_float(p["liquidationPrice"])
            }
          end)
        {:ok, %{positions: active, count: length(active)}}
      error -> error
    end
  end

  defp get_balance(opts) do
    case Client.request(:get, "/fapi/v2/balance", opts) do
      {:ok, balances} when is_list(balances) ->
        non_zero = balances
          |> Enum.filter(fn b -> parse_float(b["balance"]) != 0.0 end)
          |> Enum.map(fn b ->
            %{
              asset: b["asset"],
              balance: parse_float(b["balance"]),
              available: parse_float(b["availableBalance"]),
              unrealized_pnl: parse_float(b["crossUnPnl"])
            }
          end)
        {:ok, %{balances: non_zero, count: length(non_zero)}}
      error -> error
    end
  end

  defp get_income(params, opts) do
    query_params = %{"limit" => "#{params[:limit] || 50}"}
    query_params = if params[:symbol], do: Map.put(query_params, "symbol", params[:symbol]), else: query_params
    query_params = if params[:income_type], do: Map.put(query_params, "incomeType", params[:income_type]), else: query_params

    case Client.request(:get, "/fapi/v1/income", Map.put(opts, :params, query_params)) do
      {:ok, income} when is_list(income) ->
        parsed = Enum.map(income, fn i ->
          %{
            symbol: i["symbol"],
            income_type: i["incomeType"],
            income: parse_float(i["income"]),
            asset: i["asset"],
            time: i["time"]
          }
        end)
        {:ok, %{income: parsed, count: length(parsed)}}
      error -> error
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(n) when is_number(n), do: n * 1.0

  defp parse_int(nil), do: 1
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(n) when is_integer(n), do: n
end
