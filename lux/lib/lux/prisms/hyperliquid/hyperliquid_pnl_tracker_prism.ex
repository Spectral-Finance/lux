defmodule Lux.Prisms.Hyperliquid.HyperliquidPnLTrackerPrism do
  @moduledoc """
  A prism that tracks unrealized PnL and portfolio metrics for Hyperliquid positions.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidPnLTrackerPrism.run(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         status: "success",
         portfolio_summary: %{
           "total_unrealized_pnl" => 150.5,
           "total_position_value" => 5000.0,
           "account_value" => 10000.0,
           "margin_used" => 1000.0
         },
         position_details: [
           %{
             "coin" => "ETH",
             "unrealized_pnl" => 100.0,
             "entry_px" => "2800.0",
             "position_size" => "1.0",
             "position_value" => "3000.0",
             "return_on_equity" => "0.05"
           }
         ]
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid PnL Tracker",
    description: "Tracks unrealized PnL and portfolio metrics for Hyperliquid positions",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to track PnL for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        portfolio_summary: %{
          type: :object,
          properties: %{
            total_unrealized_pnl: %{type: :number},
            total_position_value: %{type: :number},
            account_value: %{type: :number},
            margin_used: %{type: :number}
          },
          required: ["total_unrealized_pnl", "account_value"]
        },
        position_details: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              coin: %{type: :string},
              unrealized_pnl: %{type: :number},
              entry_px: %{type: :string},
              position_size: %{type: :string},
              position_value: %{type: :string},
              return_on_equity: %{type: :string}
            },
            required: ["coin", "unrealized_pnl"]
          }
        }
      },
      required: ["status", "portfolio_summary", "position_details"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(%{address: address} = _input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, %{}} <- Lux.Python.import_package("hyperliquid_utils.setup"),
         {:ok, result} <- fetch_pnl_data(private_key, address, api_url) do
      {:ok, result}
    else
      {:error, :missing_private_key} ->
        {:error, "Hyperliquid account private key is not configured"}

      {:error, :missing_api_url} ->
        {:error, "Hyperliquid API URL is not configured"}

      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to track PnL: #{inspect(reason)}"}
    end
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp fetch_pnl_data(private_key, target_address, api_url) do
    python_result =
      python variables: %{
               private_key: private_key,
               target_address: target_address,
               api_url: api_url
             } do
        ~PY"""
        from hyperliquid.info import Info
        from hyperliquid_utils.setup import setup

        _, info, _ = setup(private_key, target_address, api_url, skip_ws=True)

        # Fetch user state containing positions and PnL
        user_state = info.user_state(target_address)

        # Extract cross-margin summary data
        cross_margin = user_state.get("crossMarginSummary", {})
        account_value = float(cross_margin.get("accountValue", "0"))
        total_margin_used = float(cross_margin.get("totalMarginUsed", "0"))
        total_ntl_pos = float(cross_margin.get("totalNtlPos", "0"))

        # Process individual position PnL
        position_details = []
        total_unrealized_pnl = 0.0
        total_position_value = 0.0

        for asset_pos in user_state.get("assetPositions", []):
            pos = asset_pos.get("position", {})

            coin = pos.get("coin", "UNKNOWN")
            entry_px = pos.get("entryPx", "0")
            position_size = pos.get("size", "0")
            position_value = float(pos.get("positionValue", "0"))
            unrealized_pnl = float(pos.get("unrealizedPnl", "0"))
            return_on_equity = pos.get("returnOnEquity", "0")

            total_unrealized_pnl += unrealized_pnl
            total_position_value += position_value

            position_details.append({
                "coin": coin,
                "unrealized_pnl": unrealized_pnl,
                "entry_px": entry_px,
                "position_size": position_size,
                "position_value": pos.get("positionValue", "0"),
                "return_on_equity": return_on_equity
            })

        {
            "portfolio_summary": {
                "total_unrealized_pnl": total_unrealized_pnl,
                "total_position_value": total_position_value,
                "account_value": account_value,
                "margin_used": total_margin_used
            },
            "position_details": position_details
        }
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, Map.put(result, "status", "success")}
    end
  end
end