defmodule Lux.Prisms.Hyperliquid.HyperliquidLiquidationMonitorPrism do
  @moduledoc """
  A prism that monitors liquidation risk for Hyperliquid positions.

  This prism fetches the user's positions, calculates liquidation proximity
  for each position, and classifies positions into risk levels (safe, warning, critical).

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidLiquidationMonitorPrism.run(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
      ...>   warning_threshold: 0.2,
      ...>   critical_threshold: 0.1
      ...> })
      {:ok,
       %{
         status: "success",
         positions: [
           %{
             "coin" => "ETH",
             "entry_px" => "2800.0",
             "liquidation_px" => "2100.0",
             "mark_px" => "2900.0",
             "distance_to_liquidation" => 0.276,
             "risk_level" => "safe"
           }
         ],
         summary: %{
           "total_positions" => 1,
           "safe_count" => 1,
           "warning_count" => 0,
           "critical_count" => 0
         }
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid Liquidation Monitor",
    description: "Monitors liquidation risk for Hyperliquid positions with configurable thresholds",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to monitor positions for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        warning_threshold: %{
          type: :number,
          description: "Distance-to-liquidation ratio for warning level (default: 0.2 = 20%)",
          default: 0.2
        },
        critical_threshold: %{
          type: :number,
          description: "Distance-to-liquidation ratio for critical level (default: 0.1 = 10%)",
          default: 0.1
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        positions: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              coin: %{type: :string},
              entry_px: %{type: :string},
              liquidation_px: %{type: :string},
              mark_px: %{type: :string},
              distance_to_liquidation: %{type: :number},
              risk_level: %{type: :string}
            },
            required: ["coin", "risk_level"]
          }
        },
        summary: %{
          type: :object,
          properties: %{
            total_positions: %{type: :integer},
            safe_count: %{type: :integer},
            warning_count: %{type: :integer},
            critical_count: %{type: :integer}
          },
          required: ["total_positions", "safe_count", "warning_count", "critical_count"]
        }
      },
      required: ["status", "positions", "summary"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  @default_warning_threshold 0.2
  @default_critical_threshold 0.1

  def handler(%{address: address} = input, _ctx) do
    warning_threshold = Map.get(input, :warning_threshold, @default_warning_threshold)
    critical_threshold = Map.get(input, :critical_threshold, @default_critical_threshold)

    with {:ok, private_key} <- get_private_key(),
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, %{positions: positions_data, market_prices: market_prices}} <-
           fetch_positions_and_prices(private_key, address, api_url) do
      positions =
        Enum.map(positions_data, fn pos ->
          analyze_position_risk(pos, market_prices, warning_threshold, critical_threshold)
        end)

      summary = build_summary(positions)

      {:ok, %{status: "success", positions: positions, summary: summary}}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to monitor liquidations: #{inspect(reason)}"}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp fetch_positions_and_prices(private_key, address, api_url) do
    python_result =
      python variables: %{
               private_key: private_key,
               target_address: address,
               api_url: api_url
             } do
        ~PY"""
        from collections import defaultdict
        from hyperliquid.info import Info
        from hyperliquid_utils.setup import setup

        _, info, _ = setup(private_key, target_address, api_url, skip_ws=True)

        # Fetch user state (positions)
        user_state = info.user_state(target_address)

        # Fetch market prices
        token_metadata = info.meta_and_asset_ctxs()
        token_names, token_price = token_metadata[0], token_metadata[1]

        market_prices = {}
        for idx, token_name in enumerate(token_names["universe"]):
            market_prices[token_name["name"]] = token_price[idx]

        {
            "positions": user_state.get("assetPositions", []),
            "market_prices": market_prices
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end

  defp analyze_position_risk(position, market_prices, warning_threshold, critical_threshold) do
    position_data = position["position"] || position[:position] || %{}
    coin = position_data["coin"] || position_data[:coin] || "UNKNOWN"

    entry_px = to_string(position_data["entryPx"] || "0")
    liquidation_px_raw = position_data["liquidationPx"] || "nil"
    mark_px_raw = get_mark_price(coin, market_prices)

    {mark_px, _} = Float.parse(to_string(mark_px_raw))
    {entry_px_val, _} = Float.parse(entry_px)

    # Calculate distance to liquidation as a ratio
    distance_to_liquidation =
      calculate_distance(mark_px, liquidation_px_raw, entry_px_val)

    risk_level = classify_risk(distance_to_liquidation, warning_threshold, critical_threshold)

    %{
      "coin" => coin,
      "entry_px" => entry_px,
      "liquidation_px" => format_liquidation_px(liquidation_px_raw),
      "mark_px" => Float.round(mark_px, 2),
      "distance_to_liquidation" => Float.round(distance_to_liquidation, 4),
      "risk_level" => risk_level
    }
  end

  defp get_mark_price(coin, market_prices) when is_map(market_prices) do
    case Map.get(market_prices, coin) do
      nil -> "0"
      price_data when is_map(price_data) -> Map.get(price_data, "markPx", "0")
      price -> price
    end
  end

  defp calculate_distance(mark_px, "nil", _entry_px), do: 1.0
  defp calculate_distance(mark_px, liquidation_px_str, _entry_px) when is_binary(liquidation_px_str) do
    case Float.parse(liquidation_px_str) do
      {liq_px, ^liquidation_px_str} when mark_px > 0 ->
        abs(mark_px - liq_px) / mark_px

      _ ->
        1.0
    end
  end

  defp calculate_distance(_mark_px, _liquidation_px, _entry_px), do: 1.0

  defp format_liquidation_px("nil"), do: "N/A"
  defp format_liquidation_px(px), do: px

  defp classify_risk(distance, warning_threshold, critical_threshold)
       when distance <= critical_threshold,
       do: "critical"

  defp classify_risk(distance, warning_threshold, _critical_threshold)
       when distance <= warning_threshold,
       do: "warning"

  defp classify_risk(_distance, _warning_threshold, _critical_threshold), do: "safe"

  defp build_summary(positions) do
    total = length(positions)

    safe_count = Enum.count(positions, &(&1["risk_level"] == "safe"))
    warning_count = Enum.count(positions, &(&1["risk_level"] == "warning"))
    critical_count = Enum.count(positions, &(&1["risk_level"] == "critical"))

    %{
      "total_positions" => total,
      "safe_count" => safe_count,
      "warning_count" => warning_count,
      "critical_count" => critical_count
    }
  end
end