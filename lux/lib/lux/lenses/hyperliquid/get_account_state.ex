defmodule Lux.Lenses.Hyperliquid.GetAccountState do
  @moduledoc """
  A lens for fetching account state from Hyperliquid.

  Returns comprehensive account information including margin summary, asset positions,
  withdrawable balance, and cross margin maintenance ratio. Essential for risk monitoring
  and margin management.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.GetAccountState.focus(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{
        margin_summary: %{
          account_value: "10000.0",
          total_margin_used: "1000.0",
          total_ntl_pos: "2000.0",
          total_raw_usd: "10000.0"
        },
        cross_maintenance_margin_ratio: "0.0625",
        withdrawable: "8000.0",
        asset_positions: [
          %{
            coin: "ETH",
            size: "1.0",
            entry_px: "2800.0",
            leverage: %{type: "cross", value: 5},
            liquidation_px: "1400.0",
            unrealized_pnl: "100.0",
            margin_used: "560.0",
            position_value: "2800.0",
            return_on_equity: "0.1786"
          }
        ]
      }}
  """

  alias Lux.Integrations.Hyperliquid

  use Lux.Lens,
    name: "Hyperliquid Get Account State",
    description: "Fetches account state and margin information from Hyperliquid exchange",
    url: "#{Hyperliquid.info_url()}",
    method: :post,
    headers: Hyperliquid.headers(),
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to fetch account state for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    }

  require Logger

  @impl true
  def before_focus(params) do
    address = Map.get(params, :address, Map.get(params, "address"))

    %{
      url: Hyperliquid.info_url(),
      type: "clearinghouseState",
      user: address
    }
  end

  @impl true
  def after_focus(%{
        "crossMarginSummary" => margin_summary,
        "assetPositions" => positions
      } = response) do
    parsed_state = %{
      margin_summary: %{
        account_value: margin_summary["accountValue"],
        total_margin_used: margin_summary["totalMarginUsed"],
        total_ntl_pos: margin_summary["totalNtlPos"],
        total_raw_usd: margin_summary["totalRawUsd"]
      },
      cross_maintenance_margin_ratio: response["crossMaintenanceMarginRatio"],
      withdrawable: response["withdrawable"],
      asset_positions:
        Enum.map(positions, fn %{"position" => pos, "type" => type} ->
          %{
            coin: pos["coin"],
            size: pos["szi"],
            entry_px: pos["entryPx"],
            leverage: %{
              type: type,
              value: parse_leverage_value(pos["leverage"])
            },
            liquidation_px: pos["liquidationPx"],
            unrealized_pnl: pos["unrealizedPnl"],
            margin_used: pos["marginUsed"],
            position_value: pos["positionValue"],
            return_on_equity: pos["returnOnEquity"]
          }
        end)
    }

    Logger.info(
      "Successfully fetched account state from Hyperliquid (account_value: #{margin_summary["accountValue"]})"
    )

    {:ok, parsed_state}
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Failed to fetch account state from Hyperliquid: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(response) do
    Logger.error("Unexpected Hyperliquid account state response: #{inspect(response)}")
    {:error, "Unexpected response format"}
  end

  defp parse_leverage_value(nil), do: 1

  defp parse_leverage_value(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 1
    end
  end

  defp parse_leverage_value(val) when is_number(val), do: val
  defp parse_leverage_value(_), do: 1
end
