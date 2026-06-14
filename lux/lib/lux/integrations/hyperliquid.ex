defmodule Lux.Integrations.Hyperliquid do
  @moduledoc "Hyperliquid DEX integration for perpetual trading."
  @base_url "https://api.hyperliquid.xyz"

  def metadata, do: post_info(%{"type" => "meta"})
  def all_mids, do: post_info(%{"type" => "allMids"})
  def orderbook(coin), do: post_info(%{"type" => "l2Book", "coin" => coin})
  def recent_trades(coin), do: post_info(%{"type" => "trades", "coin" => coin})
  def candle_snapshot(coin, interval, limit \\ 100), do: post_info(%{"type" => "candleSnapshot", "coin" => coin, "interval" => interval, "limit" => limit})

  defp post_info(body) do
    url = "#{@base_url}/info"
    req(:post, url, body, false)
  end

  defp req(method, url, body, _signed) do
    case Req.post(url, json: body, headers: [{"Content-Type", "application/json"}], receive_timeout: 10_000) do
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, e} -> {:error, e}
    end
  end
end
