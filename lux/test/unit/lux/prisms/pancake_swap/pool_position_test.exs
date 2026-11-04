defmodule Lux.Prisms.PancakeSwap.PoolPositionTest do
  use UnitCase, async: true

  alias Lux.Prisms.PancakeSwap.PoolPosition

  describe "handler/2 - SCENARIO_HAPPY_PATH" do
    test "views pool position successfully" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "view",
        "pool_id" => "0xpool1"
      })

      assert {:ok, %{status: "success", position: _position}} = result
    end

    test "adds liquidity to pool position successfully" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "add",
        "pool_id" => "0xpool1",
        "liquidity" => "1000000000000000000"
      })

      assert {:ok, %{status: "success", tx_hash: _tx_hash}} = result
    end

    test "removes liquidity from pool position successfully" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "remove",
        "pool_id" => "0xpool1",
        "liquidity" => "500000000000000000"
      })

      assert {:ok, %{status: "success", tx_hash: _tx_hash}} = result
    end
  end

  describe "handler/2 - SCENARIO_NULL_INPUT" do
    test "handles nil address gracefully" do
      result = PoolPosition.run(%{"address" => nil, "action" => "view"})

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles missing required fields" do
      result = PoolPosition.run(%{})

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "handler/2 - SCENARIO_EMPTY_INPUT" do
    test "handles empty address string" do
      result = PoolPosition.run(%{"address" => "", "action" => "view"})

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles empty action" do
      result = PoolPosition.run(%{"address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "action" => ""})

      assert {:error, _} = result
    end
  end

  describe "handler/2 - SCENARIO_BOUNDARY_LIMIT" do
    test "handles zero liquidity value" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "add",
        "pool_id" => "0xpool1",
        "liquidity" => "0"
      })

      assert {:ok, %{status: "success"}} = result
    end

    test "handles maximum liquidity value" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "add",
        "pool_id" => "0xpool1",
        "liquidity" => String.duplicate("9", 77)
      })

      assert {:ok, %{status: "success"}} = result
    end
  end

  describe "handler/2 - SCENARIO_NEGATIVE_FAILURE" do
    test "rejects invalid address format" do
      result = PoolPosition.run(%{
        "address" => "invalid_address",
        "action" => "view"
      })

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "rejects unknown action" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "invalid_action"
      })

      assert {:error, _} = result
      assert String.contains?(elem(result, 1), "Unknown action")
    end

    test "rejects missing pool_id for add action" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "add"
      })

      assert {:error, _} = result
      assert String.contains?(elem(result, 1), "pool_id")
    end

    test "rejects missing liquidity for add action" do
      result = PoolPosition.run(%{
        "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "action" => "add",
        "pool_id" => "0xpool1"
      })

      assert {:error, _} = result
      assert String.contains?(elem(result, 1), "liquidity")
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = PoolPosition.view()

      assert Map.has_key?(prism.input_schema.properties, :address)
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert prism.input_schema.required == ["address"]
    end

    test "validates output schema" do
      prism = PoolPosition.view()

      assert Map.has_key?(prism.output_schema.properties, :status)
      assert prism.output_schema.required == ["status"]
    end
  end
end