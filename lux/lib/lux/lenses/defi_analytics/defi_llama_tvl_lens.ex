defmodule Lux.Lenses.DeFiAnalytics.DeFiLlamaTvlLens do
  @moduledoc """
  A lens for fetching TVL (Total Value Locked) data from DeFiLlama.

  Retrieves protocol TVL, historical TVL charts, and chain-level metrics
  using the free DeFiLlama API (no authentication required).

  ## Example

      iex> Lux.Lenses.DeFiAnalytics.DeFiLlamaTvlLens.focus(%{
      ...>   protocol: "uniswap"
      ...> })
      {:ok, %{
        protocol: "uniswap",
        current_tvl: 4500000000.0,
        tvl_usd: "$4.50B",
        chain_tvls: %{"Ethereum" => 3200000000.0, "Arbitrum" => 800000000.0},
        historical: [
          %{date: 1708300800, tvl: 4480000000.0},
          ...
        ],
        status: "success"
      }}

      iex> Lux.Lenses.DeFiAnalytics.DeFiLlamaTvlLens.focus(%{})
      {:ok, %{
        total_tvl: 95000000000.0,
        top_protocols: [
          %{name: "Lido", tvl: 21000000000.0, category: "Liquid Staking"},
          ...
        ],
        status: "success"
      }}
  """

  use Lux.Lens,
    name: "DeFiLlama TVL",
    description: "Fetches TVL data and historical metrics for DeFi protocols via DeFiLlama API",
    schema: %{
      type: :object,
      properties: %{
        protocol: %{
          type: :string,
          description: "Protocol slug (e.g. 'uniswap', 'aave', 'curve-dex'). Omit for global TVL overview."
        },
        include_historical: %{
          type: :boolean,
          description: "Include historical TVL chart data (default: true)",
          default: true
        },
        historical_days: %{
          type: :integer,
          description: "Number of historical days to return (default: 30)",
          default: 30,
          minimum: 1,
          maximum: 365
        },
        top_n: %{
          type: :integer,
          description: "Number of top protocols to return in overview mode (default: 10)",
          default: 10,
          minimum: 1,
          maximum: 100
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
    include_historical = Map.get(input, :include_historical, true)
    historical_days = Map.get(input, :historical_days, 30)
    top_n = Map.get(input, :top_n, 10)

    Logger.info("DeFiLlama TVL lens: protocol=#{protocol || "global"}")

    result =
      python variables: %{
               base_url: @defillama_base,
               protocol: protocol,
               include_historical: include_historical,
               historical_days: historical_days,
               top_n: top_n
             } do
        ~PY"""
        import urllib.request
        import json
        import time

        def fetch(url, timeout=15):
            req = urllib.request.Request(url, headers={"User-Agent": "LuxDeFiAnalytics/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())

        def format_tvl(val):
            if val >= 1e9:
                return f"${val/1e9:.2f}B"
            elif val >= 1e6:
                return f"${val/1e6:.2f}M"
            elif val >= 1e3:
                return f"${val/1e3:.2f}K"
            return f"${val:.2f}"

        try:
            if protocol:
                # Single protocol TVL
                data = fetch(f"{base_url}/protocol/{protocol}")
                current_tvl = data.get("currentChainTvls", {})
                total_tvl = sum(current_tvl.values()) if current_tvl else data.get("tvl", 0)

                # Historical data (last N days)
                hist_raw = data.get("tvl", [])
                if isinstance(hist_raw, list) and len(hist_raw) > 0:
                    cutoff = int(time.time()) - (historical_days * 86400)
                    historical = [
                        {"date": entry["date"], "tvl": entry["totalLiquidityUSD"]}
                        for entry in hist_raw
                        if entry.get("date", 0) >= cutoff
                    ] if include_historical else []
                else:
                    historical = []

                {
                    "protocol": protocol,
                    "name": data.get("name", protocol),
                    "category": data.get("category", "Unknown"),
                    "current_tvl": total_tvl,
                    "tvl_usd": format_tvl(total_tvl),
                    "chain_tvls": current_tvl,
                    "chains": data.get("chains", []),
                    "historical": historical[-historical_days:] if historical else [],
                    "description": data.get("description", ""),
                    "url": data.get("url", ""),
                    "status": "success"
                }
            else:
                # Global TVL overview
                protocols = fetch(f"{base_url}/protocols")
                sorted_protos = sorted(protocols, key=lambda x: x.get("tvl", 0), reverse=True)

                top = []
                for p in sorted_protos[:top_n]:
                    top.append({
                        "name": p.get("name", ""),
                        "slug": p.get("slug", ""),
                        "tvl": p.get("tvl", 0),
                        "tvl_usd": format_tvl(p.get("tvl", 0)),
                        "category": p.get("category", ""),
                        "chains": p.get("chains", []),
                        "change_1d": p.get("change_1d", 0),
                        "change_7d": p.get("change_7d", 0)
                    })

                total_tvl = sum(p.get("tvl", 0) for p in protocols)

                # Historical global TVL
                historical = []
                if include_historical:
                    charts = fetch(f"{base_url}/charts")
                    cutoff = int(time.time()) - (historical_days * 86400)
                    historical = [
                        {"date": entry["date"], "tvl": entry["totalLiquidityUSD"]}
                        for entry in charts
                        if entry.get("date", 0) >= cutoff
                    ][-historical_days:]

                {
                    "total_tvl": total_tvl,
                    "total_tvl_usd": format_tvl(total_tvl),
                    "protocol_count": len(protocols),
                    "top_protocols": top,
                    "historical": historical,
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
