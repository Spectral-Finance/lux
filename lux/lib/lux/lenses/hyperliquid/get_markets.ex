defmodule Lux.Lenses.Hyperliquid.GetMarkets do
  @moduledoc """
  A lens for fetching available perpetual markets from Hyperliquid.

  Returns metadata about all available trading pairs including leverage limits,
  size decimals, and current market data like mark price, funding rate, and open interest.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.GetMarkets.focus(%{})
      {:ok, %{
        markets: [
          %{
            name: "ETH",
            sz_decimals: 4,
            max_leverage: 50,
            mark_px: "2800.0",
            funding: "0.0001",
            open_interest: "1000000.0",
            prev_day_px: "2750.0",
            day_ntl_vlm: "50000000.0",
            premium: "0.0001",
            oracle_px: "2799.5"
          }
        ]
      }}
  """

  alias Lux.Integrations.Hyperliquid

  use Lux.Lens,
    name: "Hyperliquid Get Markets",
    description: "Fetches available perpetual markets from Hyperliquid exchange",
    url: "#{Hyperliquid.info_url()}",
    method: :post,
    headers: Hyperliquid.headers(),
    schema: %{
      type: :object,
      properties: %{},
      additionalProperties: false
    }

  require Logger

  @impl true
  def before_focus(_params) do
    %{url: Hyperliquid.info_url(), type: "metaAndAssetCtxs"}
  end

  @impl true
  def after_focus([meta, asset_ctxs]) when is_map(meta) and is_list(asset_ctxs) do
    universe = Map.get(meta, "universe", [])

    markets =
      universe
      |> Enum.with_index()
      |> Enum.map(fn {token_meta, idx} ->
        asset_ctx = Enum.at(asset_ctxs, idx, %{})

        %{
          name: token_meta["name"],
          sz_decimals: token_meta["szDecimals"],
          max_leverage: token_meta["maxLeverage"],
          mark_px: asset_ctx["markPx"],
          funding: asset_ctx["funding"],
          open_interest: asset_ctx["openInterest"],
          prev_day_px: asset_ctx["prevDayPx"],
          day_ntl_vlm: asset_ctx["dayNtlVlm"],
          premium: asset_ctx["premium"],
          oracle_px: asset_ctx["oraclePx"]
        }
      end)

    Logger.info("Successfully fetched #{length(markets)} markets from Hyperliquid")
    {:ok, %{markets: markets}}
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Failed to fetch markets from Hyperliquid: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(response) do
    Logger.error("Unexpected Hyperliquid markets response: #{inspect(response)}")
    {:error, "Unexpected response format"}
  end
end
