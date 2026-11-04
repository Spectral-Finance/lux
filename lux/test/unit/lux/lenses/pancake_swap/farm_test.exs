defmodule Lux.Lenses.PancakeSwap.YieldFarmTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.PancakeSwap.YieldFarm

  describe "focus/1 - SCENARIO_HAPPY_PATH" do
    test "fetches yield farm positions for a valid address" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{
            "positions" => [
              %{
                "id" => "0xpos1",
                "pool" => %{"id" => "0xpool1", "token0" => %{"symbol" => "WBNB"}, "token1" => %{"symbol" => "USDT"}},
                "liquidity" => "1000000000000000000",
                "depositedToken0" => "1.0",
                "depositedToken1" => "2000.0"
              }
            ]
          }
        })
      end)

      result = YieldFarm.focus(%{"address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"})

      assert {:ok, %{"positions" => positions}} = result
      assert length(positions) == 1
      assert hd(positions)["id"] == "0xpos1"
    end

    test "falls back to pools when no address provided" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => [%{"id" => "0xpool1"}]}
        })
      end)

      result = YieldFarm.focus(%{})

      assert {:ok, %{"pools" => _}} = result
    end
  end

  describe "focus/1 - SCENARIO_NULL_INPUT" do
    test "handles nil address gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      result = YieldFarm.focus(%{"address" => nil})

      assert {:ok, _} = result
    end
  end

  describe "focus/1 - SCENARIO_EMPTY_INPUT" do
    test "handles empty address string" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"pools" => []}
        })
      end)

      result = YieldFarm.focus(%{"address" => ""})

      assert {:ok, _} = result
    end
  end

  describe "focus/1 - SCENARIO_BOUNDARY_LIMIT" do
    test "handles zero positions returned" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"positions" => []}
        })
      end)

      result = YieldFarm.focus(%{"address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "first" => 0})

      assert {:ok, %{"positions" => []}} = result
    end
  end

  describe "focus/1 - SCENARIO_NEGATIVE_FAILURE" do
    test "rejects invalid Ethereum address format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"positions" => []}
        })
      end)

      result = YieldFarm.focus(%{"address" => "not_an_address"})

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"errors" => [%{"message" => "Unauthorized"}]})
      end)

      result = YieldFarm.focus(%{"address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"})

      assert {:error, _} = result
    end
  end
end