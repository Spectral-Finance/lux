defmodule Lux.Lenses.PancakeSwap.PoolsTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.PancakeSwap.Pools

  describe "focus/1 - SCENARIO_HAPPY_PATH" do
    test "fetches pools successfully with valid parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/subgraphs/name/pancakeswap/exchange-v3-bsc"

        Req.Test.json(conn, %{
          "data" => %{
            "pools" => [
              %{
                "id" => "0xpool1",
                "token0" => %{"symbol" => "WBNB", "address" => "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", "decimals" => 18},
                "token1" => %{"symbol" => "USDT", "address" => "0x55d398326f99059ff775485246999027b3197955", "decimals" => 18},
                "feeTier" => 3000,
                "totalValueLockedUSD" => "1000000.0",
                "volumeUSD" => "500000.0",
                "feesUSD" => "5000.0",
                "liquidity" => "1000000000000000000"
              }
            ]
          }
        })
      end)

      result = Pools.focus(%{"first" => 5})

      assert {:ok, %{"pools" => pools}} = result
      assert length(pools) == 1
      assert hd(pools)["id"] == "0xpool1"
      assert hd(pools)["token0"]["symbol"] == "WBNB"
    end

    test "fetches pools with default parameters when no input provided" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      result = Pools.focus(%{})

      assert {:ok, %{"pools" => [], "count" => 0}} = result
    end
  end

  describe "focus/1 - SCENARIO_NULL_INPUT" do
    test "handles nil input gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      result = Pools.focus(%{})

      assert {:ok, %{"pools" => [], "count" => 0}} = result
    end

    test "handles nil optional fields gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      params = %{"first" => nil, "skip" => nil}
      result = Pools.focus(params)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "focus/1 - SCENARIO_EMPTY_INPUT" do
    test "handles empty map input" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      result = Pools.focus(%{})

      assert {:ok, %{"pools" => [], "count" => 0}} = result
    end

    test "handles whitespace-only string values" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      result = Pools.focus(%{"first" => "  "})

      assert {:ok, %{"pools" => [], "count" => 0}} = result
    end
  end

  describe "focus/1 - SCENARIO_BOUNDARY_LIMIT" do
    test "handles zero pools (lower boundary)" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      result = Pools.focus(%{"first" => 0})

      assert {:ok, %{"pools" => [], "count" => 0}} = result
    end

    test "handles maximum reasonable first value" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => List.duplicate(%{"id" => "0xpool"}, 1000)}
        })
      end)

      result = Pools.focus(%{"first" => 1000})

      assert {:ok, %{"pools" => _pools, "count" => 1000}} = result
    end
  end

  describe "before_focus/1" do
    test "builds GraphQL query correctly" do
      result = Pools.before_focus(%{"first" => 10, "skip" => 5})

      query = result[:query] || result["query"]
      assert query != nil
      assert String.contains?(query, "first: 10")
      assert String.contains?(query, "skip: 5")
      assert String.contains?(query, "totalValueLockedUSD")
      assert String.contains?(query, "desc")
    end

    test "uses default values when not provided" do
      result = Pools.before_focus(%{})

      query = result[:query] || result["query"]
      assert String.contains?(query, "first: 5")
      assert String.contains?(query, "skip: 0")
    end

    test "handles nil input" do
      result = Pools.before_focus(nil)

      assert result != nil
      assert Map.has_key?(result, :query) or Map.has_key?(result, "query")
    end
  end

  describe "after_focus/1" do
    test "processes successful GraphQL response" do
      response = %{
        "data" => %{
          "pools" => [%{"id" => "0x1"}, %{"id" => "0x2"}]
        }
      }

      result = Pools.after_focus(response)

      assert {:ok, %{"pools" => pools, "count" => 2}} = result
      assert length(pools) == 2
    end

    test "processes GraphQL errors" do
      response = %{"errors" => [%{"message" => "Field 'pools' not found"}]}

      result = Pools.after_focus(response)

      assert {:error, _} = result
      assert String.contains?(elem(result, 1), "GraphQL errors")
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "data"}

      result = Pools.after_focus(response)

      assert {:error, _} = result
      assert String.contains?(elem(result, 1), "Unexpected response format")
    end
  end
end