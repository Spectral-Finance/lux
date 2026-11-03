defmodule Lux.Prisms.Analytics.Defi.DexVolumePrism do
  @moduledoc """
  Analyzes multi-chain DEX trading volume, 24h totals, and protocol market shares.
  """

  use Lux.Prism,
    name: "DeFi DEX Volume",
    description: "Computes total 24h DEX volume and dominant protocol market shares",
    input_schema: %{
      type: :object,
      properties: %{
        protocols: %{type: :array, description: "List of DEX protocol records from DeFiLlama"}
      },
      required: ["protocols"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_24h_volume_usd: %{type: :number},
        dex_count: %{type: :integer},
        top_dex: %{type: :string},
        top_dex_volume_usd: %{type: :number}
      },
      required: ["total_24h_volume_usd", "dex_count"]
    }

  def handler(input, _ctx) do
    protocols = Map.get(input, :protocols) || Map.get(input, "protocols", [])

    parsed =
      Enum.map(protocols, fn p ->
        vol = parse_num(p["total24h"] || p[:total24h] || p["dailyVolume"] || p[:daily_volume] || 0.0)
        name = p["name"] || p[:name] || "Unknown"
        {name, vol}
      end)
      |> Enum.sort_by(fn {_n, v} -> v end, :desc)

    total_vol =
      parsed
      |> Enum.map(fn {_n, v} -> v end)
      |> Enum.sum()
      |> Float.round(2)

    {top_name, top_vol} =
      case parsed do
        [{n, v} | _] -> {n, Float.round(v, 2)}
        _ -> {"None", 0.0}
      end

    {:ok,
     %{
       total_24h_volume_usd: total_vol,
       dex_count: length(parsed),
       top_dex: top_name,
       top_dex_volume_usd: top_vol
     }}
  end

  defp parse_num(v) when is_number(v), do: v * 1.0
  defp parse_num(s) when is_binary(s) do
    case Float.parse(s) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_num(_), do: 0.0
end
