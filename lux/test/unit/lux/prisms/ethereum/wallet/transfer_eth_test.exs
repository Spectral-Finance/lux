defmodule Lux.Prisms.Ethereum.Wallet.TransferEthTest do
  @moduledoc """
  Test suite for the TransferEth prism.
  Verifies end-to-end ETH transfers using the test EthereumTester provider.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Ethereum.Wallet.TransferEth

  @agent_ctx %{agent: %{name: "TestAgent"}}
  # Hardhat account 0 private key — test only
  @test_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @test_recipient "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

  describe "handler/2 — validation" do
    test "rejects missing private_key" do
      assert {:error, _} = TransferEth.handler(%{
        to: @test_recipient,
        amount_eth: "0.001"
      }, @agent_ctx)
    end

    test "rejects missing to address" do
      assert {:error, _} = TransferEth.handler(%{
        private_key: @test_private_key,
        amount_eth: "0.001"
      }, @agent_ctx)
    end

    test "rejects missing amount_eth" do
      assert {:error, _} = TransferEth.handler(%{
        private_key: @test_private_key,
        to: @test_recipient
      }, @agent_ctx)
    end

    test "rejects zero amount" do
      assert {:error, _} = TransferEth.handler(%{
        private_key: @test_private_key,
        to: @test_recipient,
        amount_eth: "0"
      }, @agent_ctx)
    end

    test "rejects negative amount" do
      assert {:error, _} = TransferEth.handler(%{
        private_key: @test_private_key,
        to: @test_recipient,
        amount_eth: "-0.1"
      }, @agent_ctx)
    end

    test "rejects non-numeric amount" do
      assert {:error, _} = TransferEth.handler(%{
        private_key: @test_private_key,
        to: @test_recipient,
        amount_eth: "one-eth"
      }, @agent_ctx)
    end
  end

  describe "handler/2 — transfer on test network" do
    test "successfully transfers ETH on test network" do
      assert {:ok, result} = TransferEth.handler(%{
        private_key: @test_private_key,
        to: @test_recipient,
        amount_eth: "0.001",
        network: "test"
      }, @agent_ctx)

      assert is_binary(result.transaction_hash)
      assert byte_size(result.transaction_hash) == 66
      assert result.from == "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
      assert result.to == @test_recipient
      assert result.amount_eth == "0.001"
      assert result.network == "test"
    end
  end
end
