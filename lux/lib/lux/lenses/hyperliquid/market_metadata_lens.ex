defmodule Lux.Lenses.Hyperliquid.MarketMetadataLens do
  @moduledoc """
  A lens for fetching perpetual market metadata, asset specifications, and live context from Hyperliquid.

  ## Examples

      # Fetch all markets
      iex> MarketMetadataLens.focus()
      {:ok, %{markets: [...]}}

      # Fetch specific market
      iex> MarketMetadataLens.focus(%{coin: "BTC"})
      {:ok, %{markets: [...]}}
  """

  use Lux.Lens,
    name: "Hyperliquid Market Metadata Lens",
    description: "Fetches universe specifications and live market context from Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Optional coin symbol to filter (e.g. BTC, ETH)"
        }
      }
    }

  def before_focus(params) do
    %{
      "type" => "metaAndAssetCtxs",
      "requested_coin" => Map.get(params, :coin) || Map.get(params, "coin")
    }
  end

  @doc """
  Transforms the Hyperliquid metaAndAssetCtxs API response into structured market models.
  """
  @impl true
  def after_focus([%{"universe" => universe}, asset_ctxs] = _response)
      when is_list(universe) and is_list(asset_ctxs) do
    markets =
      universe
      |> Enum.zip(asset_ctxs)
      |> Enum.map(fn {meta, ctx} ->
        %{
          coin: meta["name"],
          sz_decimals: meta["szDecimals"],
          max_leverage: meta["maxLeverage"],
          only_isolated: Map.get(meta, "onlyIsolated", false),
          mark_price: parse_float(ctx["markPx"]),
          mid_price: parse_float(ctx["midPx"]),
          oracle_price: parse_float(ctx["oraclePx"]),
          funding_rate: parse_float(ctx["funding"]),
          open_interest: parse_float(ctx["openInterest"]),
          day_volume: parse_float(ctx["dayNtlVlm"]),
          prev_day_price: parse_float(ctx["prevDayPx"])
        }
      end)

    {:ok, %{markets: markets}}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(other) do
    {:error, "Unexpected response format: #{inspect(other)}"}
  end

  defp parse_float(nil), do: 0.0
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
