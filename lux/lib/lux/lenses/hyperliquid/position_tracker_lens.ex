defmodule Lux.Lenses.Hyperliquid.PositionTrackerLens do
  @moduledoc """
  A lens that tracks open positions, PnL, and margin usage on Hyperliquid.

  This lens fetches and processes position data from the Hyperliquid exchange,
  providing a comprehensive view of all open positions including unrealized PnL,
  margin usage, and leverage for each position.

  ## Example

      # Track positions for a specific address
      iex> Lux.Lenses.Hyperliquid.PositionTrackerLens.focus(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{
        positions: [
          %{
            coin: "ETH",
            size: "1.0",
            entry_price: "2800.0",
            mark_price: "2950.0",
            unrealized_pnl: "150.0",
            return_on_equity: "0.15",
            leverage: "2.0",
            liquidation_price: "1400.0",
            margin_used: "1000.0",
            position_value: "2000.0"
          }
        ],
        summary: %{
          total_positions: 1,
          total_unrealized_pnl: "150.0",
          total_margin_used: "1000.0",
          account_value: "10000.0"
        }
      }}

  The lens reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Lens,
    name: "Hyperliquid Position Tracker",
    description: "Tracks open positions, PnL, and margin usage on Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to track positions for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    }

  import Lux.Python

  alias Lux.Config

  require Logger

  def before_focus(params) do
    Map.merge(params, %{"type" => "clearinghouseState", "user" => params["address"]})
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Position tracking failed: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(body) when is_map(body) do
    result = process_positions(body)
    Logger.info("Position tracking completed", result)
    {:ok, result}
  end

  def after_focus(body) when is_list(body) do
    result = process_positions(%{"assetPositions" => body})
    {:ok, result}
  end

  @doc """
  Processes raw position data into a structured format.
  """
  def process_positions(data) do
    asset_positions = Map.get(data, "assetPositions", [])
    margin_summary = Map.get(data, "crossMarginSummary", %{})

    positions =
      Enum.map(asset_positions, fn pos ->
        position_data = Map.get(pos, "position", %{})

        %{
          coin: Map.get(position_data, "coin", ""),
          size: Map.get(position_data, "size", "0"),
          entry_price: Map.get(position_data, "entryPx", "0"),
          mark_price: Map.to_string(Map.get(position_data, "markPx", "0")),
          unrealized_pnl: calculate_unrealized_pnl(position_data),
          return_on_equity: Map.get(position_data, "returnOnEquity", "0"),
          leverage: Map.get(position_data, "leverage", "1"),
          liquidation_price: Map.get(position_data, "liquidationPx", "nil"),
          margin_used: Map.get(position_data, "marginUsed", "0"),
          position_value: Map.get(position_data, "positionValue", "0"),
          side: determine_side(position_data)
        }
      end)

    total_unrealized_pnl =
      Enum.reduce(positions, 0.0, fn pos, acc ->
        acc + String.to_float(pos.unrealized_pnl)
      end)

    total_margin_used =
      String.to_float(Map.get(margin_summary, "totalMarginUsed", "0"))

    account_value = String.to_float(Map.get(margin_summary, "accountValue", "0"))

    %{
      positions: positions,
      summary: %{
        total_positions: length(positions),
        total_unrealized_pnl: Float.to_string(total_unrealized_pnl),
        total_margin_used: Float.to_string(total_margin_used),
        account_value: Float.to_string(account_value),
        utilization_ratio: calculate_utilization_ratio(total_margin_used, account_value)
      }
    }
  end

  defp calculate_unrealized_pnl(position_data) do
    size = String.to_float(Map.get(position_data, "size", "0"))
    entry_px = String.to_float(Map.get(position_data, "entryPx", "0"))
    mark_px = String.to_float(Map.get(position_data, "markPx", "0"))

    pnl = (mark_px - entry_px) * size
    Float.to_string(abs(pnl))
  end

  defp determine_side(position_data) do
    size = String.to_float(Map.get(position_data, "size", "0"))

    if size > 0 do
      "long"
    else
      "short"
    end
  end

  defp calculate_utilization_ratio(margin_used, account_value)
       when account_value > 0 do
    ratio = margin_used / account_value
    Float.round(ratio, 4) |> Float.to_string()
  end

  defp calculate_utilization_ratio(_, _), do: "0"
end
