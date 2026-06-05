defmodule Lux.Web3.WalletTest do
  use ExUnit.Case, async: true

  describe "create_wallet" do
    test "returns private_key and address" do
      {:ok, wallet} = Lux.Web3.Wallet.create_wallet()
      assert String.length(wallet.private_key) == 64
      assert String.starts_with?(wallet.address, "0x")
      assert String.length(wallet.address) == 42
    end
  end

  describe "hex_to_int" do
    test "handles 0x0" do
      assert Lux.Web3.Wallet.hex_to_int("0x0") == 0
    end
    test "handles normal hex" do
      assert Lux.Web3.Wallet.hex_to_int("0x5208") == 21000
    end
  end
end
