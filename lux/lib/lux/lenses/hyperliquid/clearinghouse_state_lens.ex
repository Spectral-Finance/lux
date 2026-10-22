defmodule Lux.Lenses.Hyperliquid.ClearinghouseStateLens do
  @moduledoc """
  A lens for querying user account state, margins, and active perpetual positions from Hyperliquid.

  ## Examples

      iex> ClearinghouseStateLens.focus(%{user: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"})
      {:ok, %{
        account_value: 10000.0,
        total_margin_used: 1000.0,
        total_ntl_pos: 5000.0,
        withdrawable: 9000.0,
        positions: [...]
      }}
  """

  use Lux.Lens,
    name: "Hyperliquid Clearinghouse State Lens",
    description: "Queries account state, margin usage, and positions from Hyperliquid",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        user: %{
          type: :string,
          description: "Ethereum address of the account",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["user"]
    }

  def before_focus(params) do
    user = Map.get(params, :user) || Map.get(params, "user")
    %{"type" => "clearinghouseState", "user" => user}
  end

  @doc """
  Transforms the clearinghouse state into a structured account model.
  """
  @impl true
  def after_focus(
        %{"crossMarginSummary" => summary, "assetPositions" => asset_positions} = response
      ) do
    positions =
      asset_positions
      |> Enum.map(fn item ->
        pos = item["position"] || item

        %{
          coin: pos["coin"],
          size: parse_float(pos["szi"] || pos["size"]),
          entry_price: parse_float(pos["entryPx"]),
          liquidation_price: parse_float(pos["liquidationPx"]),
          margin_used: parse_float(pos["marginUsed"]),
          position_value: parse_float(pos["positionValue"]),
          unrealized_pnl: parse_float(pos["unrealizedPnl"]),
          return_on_equity: parse_float(pos["returnOnEquity"]),
          leverage: pos["leverage"]
        }
      end)

    {:ok,
     %{
       account_value: parse_float(summary["accountValue"]),
       total_margin_used: parse_float(summary["totalMarginUsed"]),
       total_ntl_pos: parse_float(summary["totalNtlPos"]),
       total_raw_usd: parse_float(summary["totalRawUsd"]),
       withdrawable: parse_float(response["withdrawable"]),
       maintenance_margin_ratio: parse_float(response["crossMaintenanceMarginRatio"]),
       positions: positions
     }}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(other) do
    {:error, "Unexpected clearinghouse response format: #{inspect(other)}"}
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
