defmodule Lux.Lenses.Hyperliquid.GetPositions do
  @moduledoc """
  A lens for fetching user positions from Hyperliquid.

  Returns all open positions for a given address including entry price, size,
  leverage, liquidation price, unrealized PnL, and margin information.

  ## Examples

      iex> Lux.Lenses.Hyperliquid.GetPositions.focus(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{
        positions: [
          %{
            coin: "ETH",
            size: "1.0",
            entry_px: "2800.0",
            leverage: %{type: "cross", value: 5},
            liquidation_px: "1400.0",
            unrealized_pnl: "100.0",
            margin_used: "560.0",
            position_value: "2800.0",
            return_on_equity: "0.1786",
            max_leverage: 50
          }
        ]
      }}
  """

  alias Lux.Integrations.Hyperliquid

  use Lux.Lens,
    name: "Hyperliquid Get Positions",
    description: "Fetches user positions from Hyperliquid exchange",
    url: "#{Hyperliquid.info_url()}",
    method: :post,
    headers: Hyperliquid.headers(),
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to fetch positions for",
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
  def after_focus(%{"assetPositions" => positions}) do
    parsed_positions =
      positions
      |> Enum.map(fn %{"position" => pos, "type" => type} ->
        %{
          coin: pos["coin"],
          size: pos["szi"],
          entry_px: pos["entryPx"],
          leverage: parse_leverage(pos, type),
          liquidation_px: pos["liquidationPx"],
          unrealized_pnl: pos["unrealizedPnl"],
          margin_used: pos["marginUsed"],
          position_value: pos["positionValue"],
          return_on_equity: pos["returnOnEquity"],
          max_leverage: pos["maxLeverage"]
        }
      end)

    Logger.info("Successfully fetched #{length(parsed_positions)} positions from Hyperliquid")
    {:ok, %{positions: parsed_positions}}
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Failed to fetch positions from Hyperliquid: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(response) do
    Logger.error("Unexpected Hyperliquid positions response: #{inspect(response)}")
    {:error, "Unexpected response format"}
  end

  defp parse_leverage(pos, type) do
    leverage_value = pos["leverage"]

    %{
      type: type,
      value: parse_leverage_value(leverage_value)
    }
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
