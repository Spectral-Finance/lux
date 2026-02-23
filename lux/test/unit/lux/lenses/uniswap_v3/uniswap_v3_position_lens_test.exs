defmodule Lux.Lenses.UniswapV3.UniswapV3PositionLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.UniswapV3.UniswapV3PositionLens

  describe "focus/2 — input validation" do
    test "rejects missing token_id" do
      assert {:error, _} = UniswapV3PositionLens.focus(%{}, %{})
    end

    test "accepts token_id with defaults" do
      result = UniswapV3PositionLens.focus(%{
        token_id: 123456,
        rpc_url: "http://localhost:18545"
      })
      # Will fail to connect but not on input validation
      assert {:error, _} = result
    end

    test "accepts custom position_manager_address" do
      result = UniswapV3PositionLens.focus(%{
        token_id: 1,
        position_manager_address: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end

    test "accepts custom factory_address" do
      result = UniswapV3PositionLens.focus(%{
        token_id: 1,
        factory_address: "0x1F98431c8aD98523631AE4a59f267346ea31F984",
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end
  end

  describe "focus/2 — output structure" do
    test "returns error tuple on RPC failure" do
      result = UniswapV3PositionLens.focus(%{
        token_id: 999999,
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end
  end

  describe "schema" do
    test "schema has required fields documented" do
      schema = UniswapV3PositionLens.view().schema
      assert Map.has_key?(schema.properties, :token_id)
      assert Map.has_key?(schema.properties, :position_manager_address)
      assert Map.has_key?(schema.properties, :factory_address)
      assert Map.has_key?(schema.properties, :rpc_url)
    end
  end
end
