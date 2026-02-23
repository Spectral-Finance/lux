defmodule Lux.Lenses.Hyperliquid.HyperliquidPnlLens do
  @moduledoc """
  A lens for tracking profit and loss (PnL) on Hyperliquid perpetual positions.

  Returns current open P&L for all positions, including unrealized gains/losses,
  return on equity, entry prices, and current mark prices.

  ## Example

      iex> HyperliquidPnlLens.focus(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> }, %{agent: %{name: "TradeAgent"}})
      {:ok, %{
        address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
        total_unrealized_pnl: "250.50",
        total_account_value: "10250.50",
        positions: [
          %{
            coin: "ETH",
            side: "long",
            size: "1.0",
            entry_price: "2800.0",
            mark_price: "3050.5",
            unrealized_pnl: "250.50",
            return_on_equity: "0.25",
            liquidation_price: "2100.0",
            leverage: "2.0",
            margin_used: "1000.0"
          }
        ]
      }}
  """

  use Lux.Lens,
    name: "Hyperliquid PnL Tracker",
    description: "Fetches current P&L, positions, and ROE metrics from Hyperliquid",
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to fetch PnL for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @impl true
  def focus(%{address: address} = _input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"
    Logger.info("Agent #{agent_name} fetching PnL for #{address}")

    with {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, result} <- fetch_pnl(address, api_url) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Package import failed: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_pnl(address, api_url) do
    result =
      python variables: %{address: address, api_url: api_url} do
        ~PY"""
        from hyperliquid.info import Info

        try:
            info = Info(api_url, skip_ws=True)
            user_state = info.user_state(address)

            positions = []
            for asset_pos in user_state.get("assetPositions", []):
                pos = asset_pos.get("position", {})
                coin = pos.get("coin", "")

                # Determine side from size
                size_str = pos.get("szi", "0")
                size = float(size_str)
                side = "long" if size > 0 else "short"

                positions.append({
                    "coin": coin,
                    "side": side,
                    "size": str(abs(size)),
                    "entry_price": pos.get("entryPx", "0"),
                    "mark_price": pos.get("positionValue", "0"),
                    "unrealized_pnl": pos.get("unrealizedPnl", "0"),
                    "return_on_equity": pos.get("returnOnEquity", "0"),
                    "liquidation_price": pos.get("liquidationPx", ""),
                    "leverage": pos.get("leverage", {}).get("value", "0") if isinstance(pos.get("leverage"), dict) else str(pos.get("leverage", "0")),
                    "margin_used": pos.get("marginUsed", "0")
                })

            margin_summary = user_state.get("crossMarginSummary", {})
            total_pnl = sum(float(p["unrealized_pnl"]) for p in positions)
            account_value = float(margin_summary.get("accountValue", "0"))

            {
                "address": address,
                "total_unrealized_pnl": str(round(total_pnl, 6)),
                "total_account_value": str(round(account_value, 6)),
                "positions": positions
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      positions = Enum.map(result["positions"], fn pos ->
        %{
          coin: pos["coin"],
          side: pos["side"],
          size: pos["size"],
          entry_price: pos["entry_price"],
          mark_price: pos["mark_price"],
          unrealized_pnl: pos["unrealized_pnl"],
          return_on_equity: pos["return_on_equity"],
          liquidation_price: pos["liquidation_price"],
          leverage: pos["leverage"],
          margin_used: pos["margin_used"]
        }
      end)

      {:ok, %{
        address: result["address"],
        total_unrealized_pnl: result["total_unrealized_pnl"],
        total_account_value: result["total_account_value"],
        positions: positions
      }}
    end
  end
end
