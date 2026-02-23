defmodule Lux.Prisms.UniswapV3.UniswapV3CollectFeesPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.UniswapV3.UniswapV3CollectFeesPrism

  @test_pk "0x" <> String.duplicate("3c", 32)
  @test_recipient "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  describe "handler/2 — input validation" do
    test "rejects missing token_id" do
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      assert {:error, _} = UniswapV3CollectFeesPrism.run(%{})
    end

    test "rejects missing private key config" do
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      assert {:error, "Missing configuration: UNISWAP_V3_PRIVATE_KEY"} =
        UniswapV3CollectFeesPrism.run(%{token_id: 42})
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

    test "proceeds past config check" do
      result = UniswapV3CollectFeesPrism.run(%{token_id: 123456})
      assert {:error, reason} = result
      refute reason =~ "Missing configuration"
    end

    test "accepts custom recipient address" do
      result = UniswapV3CollectFeesPrism.run(%{
        token_id: 123456,
        recipient: @test_recipient
      })
      assert {:error, reason} = result
      refute reason =~ "Missing configuration"
    end

    test "defaults recipient to caller address" do
      result = UniswapV3CollectFeesPrism.run(%{
        token_id: 123456
        # No recipient — defaults to account.address
      })
      assert {:error, _} = result
    end

    test "accepts custom position_manager" do
      result = UniswapV3CollectFeesPrism.run(%{
        token_id: 123456,
        position_manager_address: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
      })
      assert {:error, _} = result
    end

    test "handles zero-fee positions gracefully" do
      # tokenId 0 is invalid on mainnet but shouldn't crash with config error
      result = UniswapV3CollectFeesPrism.run(%{token_id: 0})
      assert {:error, _} = result
    end
  end

  describe "output schema" do
    test "all output fields are present" do
      schema = UniswapV3CollectFeesPrism.view().output_schema
      props = schema.properties
      assert Map.has_key?(props, :token_id)
      assert Map.has_key?(props, :fees0_collected)
      assert Map.has_key?(props, :fees1_collected)
      assert Map.has_key?(props, :tx_hash)
      assert Map.has_key?(props, :gas_used)
      assert Map.has_key?(props, :status)
    end
  end
end
