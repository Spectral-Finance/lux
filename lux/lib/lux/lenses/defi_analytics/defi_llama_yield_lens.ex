defmodule Lux.Lenses.DeFiAnalytics.DeFiLlamaYieldLens do
  @moduledoc """
  A lens for fetching yield pool data from DeFiLlama.

  Retrieves APY, TVL, and metrics for yield-bearing pools across DeFi protocols,
  with filtering support by chain, project, symbol, and minimum APY.

  ## Example

      iex> Lux.Lenses.DeFiAnalytics.DeFiLlamaYieldLens.focus(%{
      ...>   chain: "Ethereum",
      ...>   min_apy: 5.0,
      ...>   top_n: 5
      ...> })
      {:ok, %{
        pools: [
          %{
            pool_id: "747c1d2a-c668-4682-b9f9-296708a3dd90",
            project: "lido",
            symbol: "STETH",
            chain: "Ethereum",
            apy: 3.85,
            tvl_usd: 21000000000.0,
            apy_base: 3.85,
            apy_reward: 0.0,
            il_risk: "no"
          },
          ...
        ],
        total_pools: 8432,
        filtered_count: 127,
        status: "success"
      }}
  """

  use Lux.Lens,
    name: "DeFiLlama Yield Pools",
    description: "Fetches yield pool APY and TVL data from DeFiLlama with filtering support",
    schema: %{
      type: :object,
      properties: %{
        chain: %{
          type: :string,
          description: "Filter by blockchain (e.g. 'Ethereum', 'Arbitrum', 'BSC')"
        },
        project: %{
          type: :string,
          description: "Filter by project slug (e.g. 'aave-v3', 'curve-dex', 'compound')"
        },
        symbol: %{
          type: :string,
          description: "Filter by token symbol (e.g. 'USDC', 'ETH', 'WBTC')"
        },
        min_apy: %{
          type: :number,
          description: "Minimum APY percentage filter (e.g. 5.0 = 5%)",
          minimum: 0,
          default: 0
        },
        min_tvl: %{
          type: :number,
          description: "Minimum TVL in USD filter",
          minimum: 0,
          default: 0
        },
        max_il_risk: %{
          type: :string,
          description: "Maximum impermanent loss risk ('no', 'low', 'medium', 'high', 'very high')"
        },
        top_n: %{
          type: :integer,
          description: "Return top N pools by APY (default: 20)",
          default: 20,
          minimum: 1,
          maximum: 200
        },
        sort_by: %{
          type: :string,
          description: "Sort field: 'apy' (default), 'tvl', 'apy_base'",
          default: "apy",
          enum: ["apy", "tvl", "apy_base"]
        }
      }
    }

  import Lux.Python
  require Lux.Python
  require Logger

  @defillama_yields "https://yields.llama.fi"

  @impl true
  def focus(input, _agent) do
    Logger.info("DeFiLlama yield lens: chain=#{Map.get(input, :chain, "all")} project=#{Map.get(input, :project, "all")}")

    result =
      python variables: %{
               base_url: @defillama_yields,
               chain_filter: Map.get(input, :chain, nil),
               project_filter: Map.get(input, :project, nil),
               symbol_filter: Map.get(input, :symbol, nil),
               min_apy: Map.get(input, :min_apy, 0),
               min_tvl: Map.get(input, :min_tvl, 0),
               max_il_risk: Map.get(input, :max_il_risk, nil),
               top_n: Map.get(input, :top_n, 20),
               sort_by: Map.get(input, :sort_by, "apy")
             } do
        ~PY"""
        import urllib.request
        import json

        IL_RISK_ORDER = {"no": 0, "low": 1, "medium": 2, "high": 3, "very high": 4}

        def fetch(url, timeout=20):
            req = urllib.request.Request(url, headers={"User-Agent": "LuxDeFiAnalytics/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())

        def format_tvl(val):
            if val is None: return "N/A"
            if val >= 1e9: return f"${val/1e9:.2f}B"
            if val >= 1e6: return f"${val/1e6:.2f}M"
            if val >= 1e3: return f"${val/1e3:.2f}K"
            return f"${val:.2f}"

        try:
            data = fetch(f"{base_url}/pools")
            pools = data.get("data", [])
            total_count = len(pools)

            # Apply filters
            if chain_filter:
                pools = [p for p in pools if p.get("chain", "").lower() == chain_filter.lower()]
            if project_filter:
                pools = [p for p in pools if p.get("project", "").lower() == project_filter.lower()]
            if symbol_filter:
                pools = [p for p in pools if symbol_filter.upper() in p.get("symbol", "").upper()]
            if min_apy > 0:
                pools = [p for p in pools if (p.get("apy") or 0) >= min_apy]
            if min_tvl > 0:
                pools = [p for p in pools if (p.get("tvlUsd") or 0) >= min_tvl]
            if max_il_risk:
                max_il_val = IL_RISK_ORDER.get(max_il_risk.lower(), 4)
                pools = [
                    p for p in pools
                    if IL_RISK_ORDER.get((p.get("ilRisk") or "no").lower(), 0) <= max_il_val
                ]

            filtered_count = len(pools)

            # Sort
            if sort_by == "tvl":
                pools.sort(key=lambda x: x.get("tvlUsd") or 0, reverse=True)
            elif sort_by == "apy_base":
                pools.sort(key=lambda x: x.get("apyBase") or 0, reverse=True)
            else:
                pools.sort(key=lambda x: x.get("apy") or 0, reverse=True)

            # Format results
            formatted = []
            for p in pools[:top_n]:
                formatted.append({
                    "pool_id": p.get("pool", ""),
                    "project": p.get("project", ""),
                    "symbol": p.get("symbol", ""),
                    "chain": p.get("chain", ""),
                    "apy": round(p.get("apy") or 0, 4),
                    "apy_base": round(p.get("apyBase") or 0, 4),
                    "apy_reward": round(p.get("apyReward") or 0, 4),
                    "tvl_usd": p.get("tvlUsd") or 0,
                    "tvl_formatted": format_tvl(p.get("tvlUsd") or 0),
                    "il_risk": p.get("ilRisk") or "no",
                    "stable_coin": p.get("stablecoin") or False,
                    "reward_tokens": p.get("rewardTokens") or [],
                    "underlying_tokens": p.get("underlyingTokens") or []
                })

            # Summary stats
            all_apys = [p.get("apy") or 0 for p in pools if p.get("apy")]
            avg_apy = sum(all_apys) / len(all_apys) if all_apys else 0
            total_filtered_tvl = sum(p.get("tvlUsd") or 0 for p in pools)

            {
                "pools": formatted,
                "total_pools": total_count,
                "filtered_count": filtered_count,
                "avg_apy": round(avg_apy, 4),
                "total_tvl_filtered": total_filtered_tvl,
                "total_tvl_formatted": format_tvl(total_filtered_tvl),
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
