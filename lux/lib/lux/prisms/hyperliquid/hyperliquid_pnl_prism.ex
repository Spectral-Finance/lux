defmodule Lux.Prisms.Hyperliquid.HyperliquidPnlPrism do
  @moduledoc """
  A prism that fetches realized + unrealized PnL from Hyperliquid.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidPnlPrism.run(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{
        status: "success",
        pnl_data: %{
          total_realized_pnl: "125.50",
          total_unrealized_pnl: "-12.30",
          positions: [],
          recent_fills: []
        }
      }}
  """

  use Lux.Prism,
    name: "Hyperliquid PnL Tracker",
    description: "Fetches realized and unrealized PnL with trade history from Hyperliquid",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to fetch PnL for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        pnl_data: %{
          type: :object,
          properties: %{
            total_realized_pnl: %{type: :string},
            total_unrealized_pnl: %{type: :string},
            positions: %{type: :array},
            recent_fills: %{type: :array}
          }
        }
      },
      required: ["status", "pnl_data"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(%{address: address}, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, api_url}     <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- fetch_pnl(private_key, address, api_url) do
      {:ok, %{status: "success", pnl_data: result}}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid private key not configured"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp fetch_pnl(private_key, address, api_url) do
    result =
      python variables: %{
        private_key: private_key,
        address: address,
        api_url: api_url
      } do
        ~PY"""
        from hyperliquid_utils.setup import setup

        _, info, _ = setup(private_key, address, api_url, skip_ws=True)

        # Unrealized PnL from open positions
        user_state = info.user_state(address)
        total_unrealized = 0.0
        positions = []

        for pos in user_state.get("assetPositions", []):
          p = pos["position"]
          unrealized = float(p.get("unrealizedPnl", 0))
          total_unrealized += unrealized
          positions.append({
            "coin": p["coin"],
            "size": p.get("szi", "0"),
            "entry_price": p.get("entryPx", "0"),
            "unrealized_pnl": str(unrealized),
            "return_on_equity": p.get("returnOnEquity", "0"),
            "liquidation_price": p.get("liquidationPx"),
            "leverage_type": p.get("leverage", {}).get("type", "cross"),
            "leverage_value": str(p.get("leverage", {}).get("value", 1)),
            "margin_used": p.get("marginUsed", "0"),
            "position_value": p.get("positionValue", "0")
          })

        # Realized PnL from user_fills — Official SDK: info.user_fills(address)
        fills = info.user_fills(address)
        total_realized = 0.0
        recent_fills = []

        for fill in fills[:50]:
          closed_pnl = float(fill.get("closedPnl", 0))
          total_realized += closed_pnl
          recent_fills.append({
            "coin": fill.get("coin"),
            "side": fill.get("side"),
            "price": fill.get("px"),
            "size": fill.get("sz"),
            "closed_pnl": str(closed_pnl),
            "fee": fill.get("fee"),
            "time": fill.get("time")
          })

        {
          "total_unrealized_pnl": str(round(total_unrealized, 6)),
          "total_realized_pnl":   str(round(total_realized, 6)),
          "positions":            positions,
          "recent_fills":         recent_fills
        }
        """
      end

    case result do
      %{"error" => e} -> {:error, e}
      r when is_map(r) -> {:ok, r}
      _ -> {:error, "Unexpected response"}
    end
  end
end
