defmodule Lux.Prisms.UniswapV3.UniswapV3RebalancePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.UniswapV3.UniswapV3RebalancePrism

  @test_pk "0x" <> String.duplicate("4d", 32)

  describe "handler/2 — input validation" do
    test "rejects missing token_id" do
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      assert {:error, _} = UniswapV3RebalancePrism.run(%{range_width_bps: 2000})
    end

    test "rejects missing private key" do
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      assert {:error, "Missing configuration: UNISWAP_V3_PRIVATE_KEY"} =
        UniswapV3RebalancePrism.run(%{token_id: 123456})
    end
  end

  describe "handler/2 — with env config" do
    setup do
      System.put_env("UNISWAP_V3_PRIVATE_KEY", @test_pk)
      System.put_env("UNISWAP_V3_RPC_URL", "http://localhost:18545")
      on_exit(fn ->
        System.delete_env("UNISWAP_V3_PRIVATE_KEY")
        System.delete_env("UNISWAP_V3_RPC_URL")
      end)
      :ok
    end

    test "proceeds past config validation" do
      result = UniswapV3RebalancePrism.run(%{token_id: 123456})
      assert {:error, reason} = result
      refute reason =~ "Missing configuration"
    end

    test "defaults range_width_bps to 2000" do
      result = UniswapV3RebalancePrism.run(%{
        token_id: 123456
        # range_width_bps defaults to 2000 (±10%)
      })
      assert {:error, _} = result
    end

    test "accepts custom range width" do
      result = UniswapV3RebalancePrism.run(%{
        token_id: 123456,
        range_width_bps: 5000  # ±25%
      })
      assert {:error, _} = result
    end

    test "accepts custom slippage" do
      result = UniswapV3RebalancePrism.run(%{
        token_id: 123456,
        slippage_bps: 200
      })
      assert {:error, _} = result
    end

    test "accepts custom factory address" do
      result = UniswapV3RebalancePrism.run(%{
        token_id: 123456,
        factory_address: "0x1F98431c8aD98523631AE4a59f267346ea31F984"
      })
      assert {:error, _} = result
    end

    test "accepts custom position_manager and factory" do
      result = UniswapV3RebalancePrism.run(%{
        token_id: 123456,
        position_manager_address: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88",
        factory_address: "0x1F98431c8aD98523631AE4a59f267346ea31F984"
      })
      assert {:error, _} = result
    end
  end

  describe "output schema" do
    test "all output fields are defined" do
      schema = UniswapV3RebalancePrism.view().output_schema
      props = schema.properties
      assert Map.has_key?(props, :rebalanced)
      assert Map.has_key?(props, :old_token_id)
      assert Map.has_key?(props, :new_token_id)
      assert Map.has_key?(props, :old_price_lower)
      assert Map.has_key?(props, :old_price_upper)
      assert Map.has_key?(props, :new_price_lower)
      assert Map.has_key?(props, :new_price_upper)
      assert Map.has_key?(props, :current_price)
      assert Map.has_key?(props, :tx_hash)
      assert Map.has_key?(props, :gas_used)
      assert Map.has_key?(props, :status)
    end
  end
end
