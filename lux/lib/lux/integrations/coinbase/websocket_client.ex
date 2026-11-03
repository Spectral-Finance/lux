defmodule Lux.Integrations.Coinbase.WebsocketClient do
  @moduledoc """
  WebSocket feed client and message parser for Coinbase Advanced Trade.
  Formats channel subscriptions and parses incoming real-time market data.
  """

  alias Lux.Integrations.Coinbase.Signer

  @ws_url "wss://advanced-trade-ws.coinbase.com"

  @doc """
  Returns Coinbase Advanced Trade WebSocket endpoint.
  """
  @spec ws_url() :: String.t()
  def ws_url, do: @ws_url

  @doc """
  Builds a public channel subscription message.
  """
  @spec build_subscribe_message(String.t(), list(String.t())) :: map()
  def build_subscribe_message(channel, product_ids) when is_binary(channel) and is_list(product_ids) do
    %{
      "type" => "subscribe",
      "product_ids" => Enum.map(product_ids, &String.upcase/1),
      "channel" => channel
    }
  end

  @doc """
  Builds an authenticated channel subscription message (e.g. for user channel).
  """
  @spec build_auth_subscribe_message(String.t(), list(String.t()), String.t(), String.t()) :: map()
  def build_auth_subscribe_message(channel, product_ids, api_key, secret_key) do
    ts = to_string(:os.system_time(:second))
    # For WS auth: timestamp + channel + comma-separated products
    products_str = Enum.map_join(product_ids, ",", &String.upcase/1)
    message = ts <> channel <> products_str
    signature = :crypto.mac(:hmac, :sha256, secret_key, message) |> Base.encode16(case: :lower)

    %{
      "type" => "subscribe",
      "product_ids" => Enum.map(product_ids, &String.upcase/1),
      "channel" => channel,
      "api_key" => api_key,
      "timestamp" => ts,
      "signature" => signature
    }
  end

  @doc """
  Parses incoming WebSocket events from Coinbase Advanced Trade.
  """
  @spec parse_event(map()) :: {:ok, atom(), map()} | {:error, term()}
  def parse_event(%{"channel" => "ticker", "events" => events}) do
    parsed_tickers =
      Enum.flat_map(events, fn evt ->
        Enum.map(evt["tickers"] || [], fn t ->
          %{
            product_id: t["product_id"],
            price: parse_float(t["price"]),
            volume_24_h: parse_float(t["volume_24_h"]),
            low_24_h: parse_float(t["low_24_h"]),
            high_24_h: parse_float(t["high_24_h"]),
            price_percentage_chg_24_h: parse_float(t["price_percentage_chg_24_h"])
          }
        end)
      end)

    {:ok, :ticker, parsed_tickers}
  end

  def parse_event(%{"channel" => "market_trades", "events" => events}) do
    parsed_trades =
      Enum.flat_map(events, fn evt ->
        Enum.map(evt["trades"] || [], fn tr ->
          %{
            trade_id: tr["trade_id"],
            product_id: tr["product_id"],
            price: parse_float(tr["price"]),
            size: parse_float(tr["size"]),
            side: tr["side"],
            time: tr["time"]
          }
        end)
      end)

    {:ok, :market_trades, parsed_trades}
  end

  def parse_event(%{"channel" => "candles", "events" => events}) do
    parsed_candles =
      Enum.flat_map(events, fn evt ->
        Enum.map(evt["candles"] || [], fn c ->
          %{
            start: c["start"],
            low: parse_float(c["low"]),
            high: parse_float(c["high"]),
            open: parse_float(c["open"]),
            close: parse_float(c["close"]),
            volume: parse_float(c["volume"])
          }
        end)
      end)

    {:ok, :candles, parsed_candles}
  end

  def parse_event(other), do: {:ok, :generic, other}

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end
