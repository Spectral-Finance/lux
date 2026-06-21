defmodule Lux.Prisms.Web3.WalletImportTest do
  use ExUnit.Case, async: false
  import Mock

  alias Lux.Prisms.Web3.WalletImport
  alias Lux.Integrations.Web3.WalletManager

  test "handler imports wallet" do
    with_mock WalletManager, [import_wallet: fn _name, _pk -> {:ok, "0x123"} end] do
      assert {:ok, %{status: "imported", address: "0x123"}} = 
               WalletImport.handler(%{name: "w1", private_key: "0xaa"}, %{})
    end
  end

  test "handler derives hd wallet" do
    with_mock WalletManager, [derive_hd_account: fn _name, _mnem, _path -> {:ok, "0xabc"} end] do
      assert {:ok, %{status: "derived", address: "0xabc"}} = 
               WalletImport.handler(%{name: "w2", mnemonic: "test test"}, %{})
    end
  end
end
