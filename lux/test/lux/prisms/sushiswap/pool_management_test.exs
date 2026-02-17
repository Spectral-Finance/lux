defmodule Lux.Test.Prisms.Sushiswap.PoolManagementTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Sushiswap.PoolManagementPrism

  describe "get_pool_details/1" do
    test "returns pool details for a given pool ID" do
      pool_id = "test_pool_id"
      expected_details = %{"pool_id" => pool_id, "liquidity" => 1000}

      Sushiswap
      |> expect(:get_pool_details, fn ^pool_id -> expected_details end)

      assert PoolManagementPrism.get_pool_details(pool_id) == expected_details
    end
  end

  describe "create_pool/1" do
    test "creates a new pool with the given parameters" do
      params = %{"token_a" => "ETH", "token_b" => "USDC", "liquidity" => 500}
      expected_response = %{"pool_id" => "new_pool_id"}

      Sushiswap
      |> expect(:create_pool, fn ^params -> expected_response end)

      assert PoolManagementPrism.create_pool(params) == expected_response
    end
  end

  describe "update_pool/2" do
    test "updates an existing pool with the given parameters" do
      pool_id = "test_pool_id"
      params = %{"liquidity" => 1500}
      expected_response = %{"pool_id" => pool_id, "liquidity" => 1500}

      Sushiswap
      |> expect(:update_pool, fn ^pool_id, ^params -> expected_response end)

      assert PoolManagementPrism.update_pool(pool_id, params) == expected_response
    end
  end

  describe "delete_pool/1" do
    test "deletes a pool with the given pool ID" do
      pool_id = "test_pool_id"

      Sushiswap
      |> expect(:delete_pool, fn ^pool_id -> :ok end)

      assert PoolManagementPrism.delete_pool(pool_id) == :ok
    end
  end
end

describe "create_pool/1" do
  test "creates a new pool with the given parameters" do
    params = %{"token_a" => "ETH", "token_b" => "USDC", "liquidity" => 500}
    expected_response = %{"pool_id" => "new_pool_id"}

    Sushiswap
    |> expect(:create_pool, fn ^params -> expected_response end)

    assert PoolManagementPrism.create_pool(params) == expected_response
  end
end