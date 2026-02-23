defmodule Lux.Prisms.Ethereum.Wallet.SignTransactionTest do
  @moduledoc """
  Test suite for the SignTransaction prism.
  Verifies offline transaction signing for EIP-1559 and legacy transactions.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Ethereum.Wallet.SignTransaction

  @agent_ctx %{agent: %{name: "TestAgent"}}
  @test_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @expected_from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @test_to "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

  @base_params %{
    private_key: @test_private_key,
    to: @test_to,
    nonce: 0,
    chain_id: 1
  }

  describe "handler/2 — EIP-1559 signing" do
    test "signs an EIP-1559 transaction successfully" do
      params = Map.merge(@base_params, %{
        max_fee_per_gas: "20000000000",
        max_priority_fee_per_gas: "1000000000",
        gas: 21000,
        value_wei: "1000000000000000"
      })

      assert {:ok, result} = SignTransaction.handler(params, @agent_ctx)

      assert is_binary(result.raw_transaction)
      assert String.length(result.raw_transaction) > 10

      assert is_binary(result.transaction_hash)
      assert byte_size(result.transaction_hash) == 66

      assert result.from == @expected_from
    end
  end

  describe "handler/2 — legacy signing" do
    test "signs a legacy transaction with gas_price" do
      params = Map.merge(@base_params, %{
        gas_price: "20000000000",
        gas: 21000,
        value_wei: "0"
      })

      assert {:ok, result} = SignTransaction.handler(params, @agent_ctx)

      assert is_binary(result.raw_transaction)
      assert result.from == @expected_from
    end
  end

  describe "handler/2 — determinism" do
    test "same inputs produce same signed transaction" do
      params = Map.merge(@base_params, %{
        gas_price: "20000000000",
        value_wei: "0"
      })

      assert {:ok, result1} = SignTransaction.handler(params, @agent_ctx)
      assert {:ok, result2} = SignTransaction.handler(params, @agent_ctx)

      assert result1.raw_transaction == result2.raw_transaction
      assert result1.transaction_hash == result2.transaction_hash
    end
  end

  describe "handler/2 — validation" do
    test "rejects missing private key" do
      assert {:error, _} = SignTransaction.handler(%{
        to: @test_to,
        nonce: 0
      }, @agent_ctx)
    end

    test "rejects missing to address" do
      assert {:error, _} = SignTransaction.handler(%{
        private_key: @test_private_key,
        nonce: 0
      }, @agent_ctx)
    end

    test "rejects negative nonce" do
      assert {:error, _} = SignTransaction.handler(%{
        private_key: @test_private_key,
        to: @test_to,
        nonce: -1
      }, @agent_ctx)
    end

    test "rejects missing nonce" do
      assert {:error, _} = SignTransaction.handler(%{
        private_key: @test_private_key,
        to: @test_to
      }, @agent_ctx)
    end
  end
end
