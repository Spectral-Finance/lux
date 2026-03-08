defmodule Lux.Prisms.Web3.CreateWalletTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Web3.CreateWallet

  describe "handler/2 create action" do
    test "creates a new wallet" do
      assert {:ok, result} = CreateWallet.handler(%{action: "create"}, [])
      assert result.address =~ ~r/^0x[0-9a-fA-F]{40}$/
      assert result.chain_id == 1
      assert result.private_key =~ ~r/^0x[0-9a-f]{64}$/
    end

    test "creates with custom chain_id" do
      assert {:ok, result} = CreateWallet.handler(%{action: "create", chain_id: 137}, [])
      assert result.chain_id == 137
    end
  end

  describe "handler/2 import action" do
    test "imports from private key" do
      # First create a wallet to get a valid key
      {:ok, created} = CreateWallet.handler(%{action: "create"}, [])

      assert {:ok, imported} =
               CreateWallet.handler(
                 %{action: "import", private_key: created.private_key},
                 []
               )

      assert imported.address == created.address
    end

    test "returns error without private key" do
      assert {:error, _} = CreateWallet.handler(%{action: "import"}, [])
    end
  end
end
