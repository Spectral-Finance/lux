defmodule Lux.Prisms.Hyperliquid.HyperliquidLiquidationPrism do
  @moduledoc """
  A prism that monitors liquidation risk for all open positions on Hyperliquid.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidLiquidationPrism.run(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
      ...>   risk_threshold: 0.1
      ...> })
      {:ok, %{status: "success", at_risk_positions: [], safe_positions: []}}
  """

  use Lux.Prism,
    name: "Hyperliquid Liquidation Monitor",
    description: "Monitors liquidation risk for open positions on Hyperliquid",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to monitor",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        risk_threshold: %{
          type: :number,
          description: "Price distance threshold (0.0-1.0) to flag as at-risk",
          default: 0.1
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        at_risk_positions: %{type: :array},
        safe_positions: %{type: :array},
        account_value: %{type: :string},
        margin_usage: %{type: :string}
      },
      required: ["status", "at_risk_positions", "safe_positions"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python

  def handler(%{address: address} = input, _ctx) do
    threshold = Map.get(input, :risk_threshold, 0.1)

    with {:ok, private_key} <- get_private_key(),
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- check_liquidation_risk(private_key, address, api_url, threshold) do
      {:ok, Map.put(result, :status, "success")}
    else
      {:error, :missing_private_key} -> {:error, "Hyperliquid account private key is not configured"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp check_liquidation_risk(private_key, address, api_url, threshold) do
    python_result =
      python variables: %{private_key: private_key, address: address, api_url: api_url, threshold: threshold} do
        ~PY"""
        from hyperliquid.info import Info
        from hyperliquid_utils.setup import setup

        _, info, _ = setup(private_key, address, api_url, skip_ws=True)
        user_state = info.user_state(address)
        meta = info.meta_and_asset_ctxs()

        token_prices = {}
        for idx, token in enumerate(meta[0]["universe"]):
          token_prices[token["name"]] = float(meta[1][idx]["markPx"])

        at_risk = []
        safe = []

        for pos in user_state.get("assetPositions", []):
          p = pos["position"]
          coin = p["coin"]
          liq_px = p.get("liquidationPx")

          if liq_px is None or liq_px == "nil":
            safe.append({"coin": coin, "liquidation_price": None})
            continue

          current_price = token_prices.get(coin, 0)
          liq_price = float(liq_px)

          if current_price == 0:
            continue

          distance = abs(liq_price - current_price) / current_price

          # Official Hyperliquid liquidation formula:
          # liq_price = price - side * margin_available / position_size / (1 - l * side)
          # maintenance margin = half of initial margin at max leverage (3-40x)
          size = float(p.get("szi", "0"))
          side = 1 if size > 0 else -1
          margin_used = float(p.get("marginUsed", "0"))
          maintenance_margin = margin_used * 0.5
          margin = user_state.get("crossMarginSummary", {})
          account_value = float(margin.get("accountValue", "0"))
          margin_available = account_value - maintenance_margin

          entry = {
            "coin": coin,
            "current_price": str(current_price),
            "liquidation_price": str(liq_price),
            "distance_pct": str(round(distance * 100, 2)),
            "size": p.get("szi", "0"),
            "side": "long" if side == 1 else "short",
            "margin_used": p.get("marginUsed", "0"),
            "maintenance_margin": str(maintenance_margin),
            "leverage_type": p.get("leverage", {}).get("type", "cross"),
            "leverage_value": str(p.get("leverage", {}).get("value", 1))
          }

          if distance < threshold:
            at_risk.append(entry)
          else:
            safe.append(entry)

        margin = user_state.get("crossMarginSummary", {})
        {
          "at_risk_positions": at_risk,
          "safe_positions": safe,
          "account_value": margin.get("accountValue", "0"),
          "margin_usage": margin.get("totalMarginUsed", "0")
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end
