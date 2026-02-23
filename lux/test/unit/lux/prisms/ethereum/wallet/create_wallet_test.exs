defmodule Lux.Prisms.Ethereum.Wallet.CreateWalletTest do
  @moduledoc """
  Test suite for the CreateWallet prism.
  Verifies wallet generation with HD derivation (BIP-39/44).
  """

  use UnitCase, async: true

  alias Lux.Prisms.Ethereum.Wallet.CreateWallet

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "creates a valid 12-word wallet at default index" do
      assert {:ok, result} = CreateWallet.handler(%{}, @agent_ctx)

      assert is_binary(result.address)
      assert String.starts_with?(result.address, "0x")
      assert byte_size(result.address) == 42

      assert is_binary(result.private_key)
      assert String.starts_with?(result.private_key, "0x")
      assert byte_size(result.private_key) == 66

      mnemonic_words = String.split(result.mnemonic, " ")
      assert length(mnemonic_words) == 12

      assert result.hd_path == "m/44'/60'/0'/0/0"
    end

    test "creates a wallet at account index 1" do
      assert {:ok, result} = CreateWallet.handler(%{account_index: 1}, @agent_ctx)

      assert result.hd_path == "m/44'/60'/0'/0/1"
      assert String.starts_with?(result.address, "0x")
    end

    test "creates a 24-word wallet when specified" do
      assert {:ok, result} = CreateWallet.handler(%{num_words: 24}, @agent_ctx)

      mnemonic_words = String.split(result.mnemonic, " ")
      assert length(mnemonic_words) == 24
    end

    test "generates unique addresses on each call" do
      assert {:ok, wallet1} = CreateWallet.handler(%{}, @agent_ctx)
      assert {:ok, wallet2} = CreateWallet.handler(%{}, @agent_ctx)

      assert wallet1.address != wallet2.address
      assert wallet1.mnemonic != wallet2.mnemonic
      assert wallet1.private_key != wallet2.private_key
    end

    test "returns all required fields" do
      assert {:ok, result} = CreateWallet.handler(%{}, @agent_ctx)

      assert Map.has_key?(result, :address)
      assert Map.has_key?(result, :private_key)
      assert Map.has_key?(result, :mnemonic)
      assert Map.has_key?(result, :hd_path)
    end
  end
end
