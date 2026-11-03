defmodule Lux.Analytics.Defi.DefiLlamaTest do
  use UnitCase, async: true

  alias Lux.Analytics.Defi.DefiLlama

  describe "URL builders" do
    test "constructs protocol and endpoint URLs" do
      assert DefiLlama.protocol_tvl_url("Uniswap") == "https://api.llama.fi/protocol/uniswap"
      assert DefiLlama.chains_tvl_url() == "https://api.llama.fi/v2/chains"
      assert DefiLlama.dex_volume_url() == "https://api.llama.fi/overview/dexs"
      assert DefiLlama.dex_volume_url("Arbitrum") == "https://api.llama.fi/overview/dexs/arbitrum"
      assert DefiLlama.yield_pools_url() == "https://yields.llama.fi/pools"
    end
  end

  describe "parse_protocol_tvl/1" do
    test "extracts TVL, change_1d, and chain breakdown" do
      data = %{
        "name" => "Aave V3",
        "symbol" => "AAVE",
        "category" => "Lending",
        "tvl" => "12500000000.50",
        "change_1d" => "-2.45",
        "currentChainTvls" => %{
          "Ethereum" => 8000000000.0,
          "Arbitrum" => 2500000000.0,
          "Polygon" => 2000000000.50
        }
      }

      parsed = DefiLlama.parse_protocol_tvl(data)

      assert parsed.name == "Aave V3"
      assert parsed.symbol == "AAVE"
      assert parsed.category == "Lending"
      assert parsed.total_tvl_usd == 12_500_000_000.50
      assert parsed.change_1d_pct == -2.45
      assert map_size(parsed.chain_tvls) == 3
    end
  end

  describe "filter_yield_pools/2" do
    test "filters pools by min TVL, chain, and APY range" do
      pools = [
        %{
          "pool" => "pool-1",
          "project" => "uniswap-v3",
          "symbol" => "USDC-USDT",
          "chain" => "Ethereum",
          "tvlUsd" => "50000000.0",
          "apy" => "8.5"
        },
        %{
          "pool" => "pool-2",
          "project" => "curve",
          "symbol" => "3pool",
          "chain" => "Arbitrum",
          "tvlUsd" => "500000.0",
          "apy" => "4.2"
        },
        %{
          "pool" => "pool-3",
          "project" => "aave-v3",
          "symbol" => "WETH",
          "chain" => "Ethereum",
          "tvlUsd" => "100000000.0",
          "apy" => "3.1"
        }
      ]

      criteria = %{
        min_tvl_usd: 1_000_000.0,
        chain: "Ethereum",
        min_apy_pct: 5.0
      }

      filtered = DefiLlama.filter_yield_pools(pools, criteria)

      assert length(filtered) == 1
      [match] = filtered
      assert match.pool_id == "pool-1"
      assert match.apy_pct == 8.5
    end
  end
end
