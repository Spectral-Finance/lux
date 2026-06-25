defmodule Lux.Lenses.Curve.PoolsListTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Curve.PoolsList

  describe "view/0" do
    test "returns a properly configured lens" do
      lens = PoolsList.view()
      assert lens.name == "Curve.PoolsList"
      assert lens.method == :get
      assert is_binary(lens.url)
      assert String.starts_with?(lens.url, Lux.Integrations.Curve.api_url())
      assert %{} == lens.auth
    end

    test "has correct schema" do
      lens = PoolsList.view()
      assert Map.has_key?(lens.schema, :properties)
      assert Map.has_key?(lens.schema.properties, :chain_name)
    end
  end

  describe "before_focus/1" do
    test "builds correct URL with default chain" do
      result = PoolsList.before_focus(%{})
      assert %{"url" => url} = result
      assert String.contains?(url, "/pools/eth/list")
    end

    test "builds correct URL with chain override" do
      result = PoolsList.before_focus(%{chain_name: "polygon"})
      assert %{"url" => url} = result
      assert String.contains?(url, "/pools/polygon/list")
    end
  end

  describe "after_focus/1" do
    test "processes successful pool list response" do
      response = %{
        "status" => "success",
        "result" => [%{
          "name" => "3crypto",
          "coins" => ["DAI", "USDC", "USDT"],
          "usdTotal" => 150_000_000,
          "usdTotalFormatted" => "$150.00M",
          "apr" => %{"base" => 0.5, "rewards" => 2.3, "total" => 2.8},
          "type" => "standard",
          "address" => "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
          "gauge_address" => "0x000000003988d5541Ab068c586F8Ef090397dA5a",
          "poolId" => 0,
          "meta" => %{}
        }]
      }

      {:ok, result} = PoolsList.after_focus(response)
      assert result.chain == "eth"
      assert result.pool_count == 1
      assert length(result.pools) == 1

      pool = List.first(result.pools)
      assert pool.name == "3crypto"
      assert pool.coins == ["DAI", "USDC", "USDT"]
      assert pool.usd_total == 150_000_000
      assert pool.apr.total == 2.8
    end

    test "handles empty pool list" do
      response = %{"status" => "success", "result" => []}
      {:ok, result} = PoolsList.after_focus(response)
      assert result.pool_count == 0
      assert result.pools == []
    end

    test "handles API error response" do
      response = %{"status" => "error", "error" => "Something went wrong"}
      {:error, error_msg} = PoolsList.after_focus(response)
      assert String.contains?(error_msg, "Curve API error")
    end

    test "handles unknown pool entry format" do
      response = %{"status" => "success", "result" => ["invalid_entry"]}
      {:ok, result} = PoolsList.after_focus(response)
      assert result.pool_count == 1
      assert List.first(result.pools) == %{}
    end
  end
end
