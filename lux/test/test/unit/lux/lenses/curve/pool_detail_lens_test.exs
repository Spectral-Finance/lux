defmodule Lux.Lenses.Curve.PoolDetailTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Curve.PoolDetail

  describe "view/0" do
    test "returns a properly configured lens" do
      lens = PoolDetail.view()
      assert lens.name == "Curve.PoolDetail"
      assert lens.method == :get
      assert is_binary(lens.url)
    end

    test "requires pool_name in schema" do
      lens = PoolDetail.view()
      assert Map.has_key?(lens.schema.properties, :pool_name)
      assert lens.schema.required == ["pool_name"]
    end
  end

  describe "before_focus/1" do
    test "builds correct URL with default pool" do
      result = PoolDetail.before_focus(%{})
      assert %{"url" => url, "pool_name" => "3crypto"} = result
      assert String.contains?(url, "/pools/3crypto")
    end

    test "builds correct URL with specified pool" do
      result = PoolDetail.before_focus(%{pool_name: "aave"})
      assert %{"url" => url, "pool_name" => "aave"} = result
      assert String.contains?(url, "/pools/aave")
    end

    test "supports chain override" do
      result = PoolDetail.before_focus(%{pool_name: "3crypto", chain_name: "polygon"})
      assert %{"url" => url} = result
      assert String.contains?(url, "polygon")
    end
  end

  describe "after_focus/1" do
    test "processes successful pool detail response" do
      response = %{
        "status" => "success",
        "result" => %{
          "pool_name" => "3crypto",
          "pool_symbol" => "crv3crypto",
          "pool_type" => "standard",
          "pool_address" => "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
          "gauge_address" => "0x000000003988d5541Ab068c586F8Ef090397dA5a",
          "tvl_usd" => 150_000_000,
          "volumes_24h" => 5_000_000,
          "fee_24h" => 2_500,
          "apy" => %{"base" => 0.5, "rewards" => 2.3, "total" => 2.8},
          "reserves" => %{
            "0" => %{"balance" => 50_000_000, "balanceFormatted" => "50M", "weight" => 33, "decimals" => 18},
            "1" => %{"balance" => 50_000_000, "balanceFormatted" => "50M", "weight" => 33, "decimals" => 6},
            "2" => %{"balance" => 50_000_000, "balanceFormatted" => "50M", "weight" => 34, "decimals" => 6}
          },
          "coins" => [
            %{"name" => "DAI", "symbol" => "DAI", "address" => "0x6B175474E89094C44Da98b954EedeAC495271d0F", "balance" => 50_000_000, "weight" => 33, "decimals" => 18},
            %{"name" => "USDC", "symbol" => "USDC", "address" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "balance" => 50_000_000, "weight" => 33, "decimals" => 6},
            %{"name" => "USDT", "symbol" => "USDT", "address" => "0xdAC17F958D2ee523a2206206994597C13D831ec7", "balance" => 50_000_000, "weight" => 34, "decimals" => 6}
          ],
          "swapData" => %{},
          "rewardTokens" => ["0xD533a949740bb3306d119CC777fa900bA034cd52"],
          "rewardTickers" => ["CRV"],
          "poolId" => 0
        }
      }

      {:ok, result} = PoolDetail.after_focus(response)
      assert result.pool_name == "3crypto"
      assert result.pool_symbol == "crv3crypto"
      assert result.tvl_usd == 150_000_000
      assert result.volumes_24h == 5_000_000
      assert result.fee_24h == 2_500
      assert length(result.coins) == 3
      assert hd(result.coins).name == "DAI"
      assert hd(result.coins).symbol == "DAI"
      assert Map.has_key?(result.reserves, "0")
      assert result.reserves["0"].balance == 50_000_000
      assert result.reserves["0"].decimals == 18
    end

    test "handles API error response" do
      response = %{"status" => "error", "error" => "Pool not found"}
      {:error, error_msg} = PoolDetail.after_focus(response)
      assert String.contains?(error_msg, "Curve API error")
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "data"}
      {:error, error_msg} = PoolDetail.after_focus(response)
      assert error_msg == "Unexpected response format"
    end
  end
end
