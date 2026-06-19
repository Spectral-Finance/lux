defmodule Lux.Beams.Hyperliquid.HyperliquidAPI do
  @moduledoc """
  HTTP client for Hyperliquid exchange API.
  Handles order placement, position queries, and margin checks.
  """

  @base_url "https://api.hyperliquid.xyz"

  def fetch_positions(address) do
    case Req.post("#{@base_url}/info",
      json: %{type: "clearinghouseState", user: address},
      headers: %{"content-type" => "application/json"}
    ) do
      {:ok, %{status: 200, body: body}} -> {:ok, parse_positions(body)}
      {:ok, %{status: code}} -> {:error, "API returned #{code}"}
      {:error, err} -> {:error, err}
    end
  end

  def place_order(address, order_params) do
    case Req.post("#{@base_url}/exchange",
      json: Map.merge(%{action: %{type: "order"}}, order_params),
      headers: %{"content-type" => "application/json"}
    ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: code}} -> {:error, "API returned #{code}"}
      {:error, err} -> {:error, err}
    end
  end

  def cancel_order(address, order_id) do
    case Req.post("#{@base_url}/exchange",
      json: %{action: %{type: "cancel"}, user: address, oid: order_id},
      headers: %{"content-type" => "application/json"}
    ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: code}} -> {:error, "API returned #{code}"}
      {:error, err} -> {:error, err}
    end
  end

  defp parse_positions(body) do
    case body do
      %{"assetPositions" => positions} ->
        Enum.map(positions, fn p ->
          pos = p["position"]
          %{
            coin: pos["coin"],
            size: parse_entry(pos, "szi"),
            entry_px: parse_entry(pos, "entryPx"),
            unrealized_pnl: parse_entry(pos, "unrealizedPnl"),
            liquidation_price: parse_entry(pos, "liquidationPx")
          }
        end)
      _ -> []
    end
  end

  defp parse_entry(map, key) do
    case Map.get(map, key) do
      nil -> 0.0
      val when is_number(val) -> val
      val -> String.to_float(val)
    end
  end
end
