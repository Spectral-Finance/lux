defmodule Lux.Prisms.Ethereum.Wallet.ImportWalletTest do
  @moduledoc """
  Test suite for the ImportWallet prism.
  Verifies importing wallets from private keys and mnemonics.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Ethereum.Wallet.ImportWallet

  @agent_ctx %{agent: %{name: "TestAgent"}}

  # Standard test vectors (Hardhat default account 0)
  @test_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @expected_address "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @test_mnemonic "test test test test test test test test test test test junk"

  describe "handler/2 — private key import" do
    test "imports wallet from private key with 0x prefix" do
      assert {:ok, result} = ImportWallet.handler(%{
        source: "private_key",
        value: @test_private_key
      }, @agent_ctx)

      assert result.address == @expected_address
      assert result.source == "private_key"
    end

    test "imports wallet from private key without 0x prefix" do
      no_prefix = String.trim_leading(@test_private_key, "0x")

      assert {:ok, result} = ImportWallet.handler(%{
        source: "private_key",
        value: no_prefix
      }, @agent_ctx)

      assert result.address == @expected_address
    end
  end

  describe "handler/2 — mnemonic import" do
    test "imports wallet from mnemonic at default index 0" do
      assert {:ok, result} = ImportWallet.handler(%{
        source: "mnemonic",
        value: @test_mnemonic
      }, @agent_ctx)

      # Hardhat mnemonic index 0 = 0xf39Fd6...
      assert result.address == @expected_address
      assert result.source == "mnemonic"
    end

    test "derives different address at account index 1" do
      assert {:ok, result0} = ImportWallet.handler(%{
        source: "mnemonic",
        value: @test_mnemonic,
        account_index: 0
      }, @agent_ctx)

      assert {:ok, result1} = ImportWallet.handler(%{
        source: "mnemonic",
        value: @test_mnemonic,
        account_index: 1
      }, @agent_ctx)

      assert result0.address != result1.address
    end
  end

  describe "handler/2 — validation" do
    test "rejects invalid source type" do
      assert {:error, _} = ImportWallet.handler(%{
        source: "seed_phrase",
        value: @test_mnemonic
      }, @agent_ctx)
    end

    test "rejects missing value" do
      assert {:error, _} = ImportWallet.handler(%{
        source: "private_key"
      }, @agent_ctx)
    end

    test "rejects missing source" do
      assert {:error, _} = ImportWallet.handler(%{
        value: @test_private_key
      }, @agent_ctx)
    end

    test "rejects invalid private key" do
      assert {:error, _} = ImportWallet.handler(%{
        source: "private_key",
        value: "0xinvalidkey"
      }, @agent_ctx)
    end
  end
end
