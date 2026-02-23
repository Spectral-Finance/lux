defmodule Lux.Lenses.DeFiAnalytics.DeFiLlamaVolumeLens do
  @moduledoc """
  A lens for fetching DEX volume and protocol fee analytics from DeFiLlama.

  Retrieves 24h/7d/30d volume data and fee revenue for decentralized exchanges
  and DeFi protocols using the DeFiLlama Volumes API.

  ## Example

      iex> Lux.Lenses.DeFiAnalytics.DeFiLlamaVolumeLens.focus(%{
      ...>   protocol: "uniswap",
      ...>   data_type: "dexs"
      ...> })
      {:ok, %{
        protocol: "uniswap",
        volume_24h: 1200000000.0,
        volume_7d: 8400000000.0,
        volume_1m: 36000000000.0,
        fees_24h: 3600000.0,
        revenue_24h: 0.0,
        chains: ["Ethereum", "Arbitrum", "Optimism"],
        status: "success"
      }}

      iex> Lux.Lenses.DeFiAnalytics.DeFiLlamaVolumeLens.focus(%{
      ...>   data_type: "dexs",
      ...>   top_n: 5
      ...> })
      {:ok, %{
        total_volume_24h: 5800000000.0,
        top_protocols: [...],
        status: "success"
      }}
  """

  use Lux.Lens,
    name: "DeFiLlama Volume & Fees",
    description: "Fetches DEX volume and protocol fee data from DeFiLlama for comprehensive analytics",
    schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug for specific protocol analytics (e.g. 'uniswap', 'curve-dex')"
        },
        data_type: %{
          type: :string,
          description: "Data category: 'dexs' (default), 'options', 'fees'",
          default: "dexs",
          enum: ["dexs", "options", "fees"]
        },
        chain: %{
          type: :string,
          description: "Filter by chain (e.g. 'Ethereum', 'Arbitrum')"
        },
        top_n: %{
          type: :integer,
          description: "Number of top protocols to return in overview mode (default: 10)",
          default: 10,
          minimum: 1,
          maximum: 50
        },
        exclude_total_data_chart: %{
          type: :boolean,
          description: "Exclude historical chart data for faster response (default: true)",
          default: true
        }
      }
    }

  import Lux.Python
  require Lux.Python
  require Logger

  @defillama_base "https://api.llama.fi"

  @impl true
  def focus(input, _agent) do
    protocol = Map.get(input, :protocol, nil)
    data_type = Map.get(input, :data_type, "dexs")
    chain = Map.get(input, :chain, nil)
    top_n = Map.get(input, :top_n, 10)
    exclude_chart = Map.get(input, :exclude_total_data_chart, true)

    Logger.info("DeFiLlama volume lens: type=#{data_type} protocol=#{protocol || "overview"}")

    result =
      python variables: %{
               base_url: @defillama_base,
               protocol: protocol,
               data_type: data_type,
               chain_filter: chain,
               top_n: top_n,
               exclude_chart: exclude_chart
             } do
        ~PY"""
        import urllib.request
        import json

        def fetch(url, timeout=20):
            req = urllib.request.Request(url, headers={"User-Agent": "LuxDeFiAnalytics/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())

        def format_vol(val):
            if val is None: return "N/A"
            if val >= 1e9: return f"${val/1e9:.2f}B"
            if val >= 1e6: return f"${val/1e6:.2f}M"
            if val >= 1e3: return f"${val/1e3:.2f}K"
            return f"${val:.2f}"

        try:
            exclude_param = "excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true" if exclude_chart else ""

            if protocol:
                # Single protocol volume/fees
                url = f"{base_url}/summary/{data_type}/{protocol}"
                if exclude_param:
                    url += f"?{exclude_param}"
                data = fetch(url)

                vol24h = data.get("total24h") or 0
                vol7d = data.get("total7d") or 0
                vol30d = data.get("totalAllTime") or 0  # Use as monthly proxy
                fees24h = data.get("totalFees24h") or 0
                revenue24h = data.get("totalRevenue24h") or 0

                # Chain breakdown
                chain_data = data.get("breakdownChart", {})

                {
                    "protocol": protocol,
                    "name": data.get("name", protocol),
                    "data_type": data_type,
                    "volume_24h": vol24h,
                    "volume_24h_formatted": format_vol(vol24h),
                    "volume_7d": vol7d,
                    "volume_7d_formatted": format_vol(vol7d),
                    "volume_alltime": vol30d,
                    "fees_24h": fees24h,
                    "fees_24h_formatted": format_vol(fees24h),
                    "revenue_24h": revenue24h,
                    "revenue_24h_formatted": format_vol(revenue24h),
                    "chains": data.get("chains", []),
                    "category": data.get("category", ""),
                    "status": "success"
                }
            else:
                # Overview of all protocols
                url = f"{base_url}/overview/{data_type}"
                params = []
                if exclude_param:
                    params.append(exclude_param)
                if chain_filter:
                    params.append(f"chain={chain_filter}")
                if params:
                    url += "?" + "&".join(params)

                data = fetch(url)
                protocols = data.get("protocols", [])

                # Sort by 24h volume
                protocols.sort(key=lambda x: x.get("total24h") or 0, reverse=True)

                top = []
                for p in protocols[:top_n]:
                    vol24h = p.get("total24h") or 0
                    top.append({
                        "name": p.get("name", ""),
                        "slug": p.get("module", ""),
                        "volume_24h": vol24h,
                        "volume_24h_formatted": format_vol(vol24h),
                        "volume_7d": p.get("total7d") or 0,
                        "fees_24h": p.get("totalFees24h") or 0,
                        "chains": p.get("chains", []),
                        "category": p.get("category", ""),
                        "change_1d": p.get("change_1d") or 0
                    })

                total_vol24h = data.get("total24h") or 0
                total_vol7d = data.get("total7d") or 0

                {
                    "data_type": data_type,
                    "total_volume_24h": total_vol24h,
                    "total_volume_24h_formatted": format_vol(total_vol24h),
                    "total_volume_7d": total_vol7d,
                    "total_volume_7d_formatted": format_vol(total_vol7d),
                    "protocol_count": len(protocols),
                    "top_protocols": top,
                    "status": "success"
                }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)}
    end
  end
end
