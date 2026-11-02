defmodule Lux.Web3.WalletInfrastructure.MultiWalletRegistryTest do
  use UnitCase, async: true

  alias Lux.Web3.WalletInfrastructure.MultiWalletRegistry

  describe "register_wallet/5 and find_by_address/2" do
    test "registers multiple wallet types and performs case-insensitive lookups" do
      registry = []
      addr1 = "0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed"
      addr2 = "0xfb6916095ca1df60bb79ce92ce3ea74c37c5d359"

      {:ok, reg1, _} = MultiWalletRegistry.register_wallet(registry, :hd_wallet, addr1, "Treasury HD")
      {:ok, reg2, _} = MultiWalletRegistry.register_wallet(reg1, :multisig_contract, addr2, "Gnosis Safe 2/3")

      assert length(reg2) == 2

      # Find by address (case insensitive)
      assert {:ok, found1} = MultiWalletRegistry.find_by_address(reg2, String.upcase(addr1))
      assert found1.label == "Treasury HD"
      assert found1.type == :hd_wallet

      # Prevent duplicate registration
      assert {:error, reason} = MultiWalletRegistry.register_wallet(reg2, :hd_wallet, addr1, "Duplicate")
      assert String.contains?(reason, "already registered")
    end

    test "filters wallets by type" do
      registry = [
        %{address: "0x1", type: :hd_wallet, label: "W1", created_at: "", metadata: %{}},
        %{address: "0x2", type: :multisig_contract, label: "W2", created_at: "", metadata: %{}},
        %{address: "0x3", type: :hd_wallet, label: "W3", created_at: "", metadata: %{}}
      ]

      hd_list = MultiWalletRegistry.list_by_type(registry, :hd_wallet)
      assert length(hd_list) == 2
    end
  end
end
