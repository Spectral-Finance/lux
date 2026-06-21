defmodule Lux.Prisms.Web3.CreateWalletPrismTest do
  use ExUnit.Case, async: false

  import Mock

  alias Lux.Prisms.Web3.CreateWalletPrism
  alias Lux.Web3.TransactionManager

  setup_all do
    Registry.start_link(keys: :unique, name: Lux.Web3.TransactionManagerRegistry)
    DynamicSupervisor.start_link(strategy: :one_for_one, name: Lux.Web3.TransactionManagerSupervisor)
    :ok
  end

  test "successfully generates new wallet, encrypts, and starts transaction manager" do
    with_mocks([
      {Ethers, [], [
        get_transaction_count: fn _addr -> {:ok, 0} end
      ]}
    ]) do
      # Generate new wallet
      assert {:ok, result} = CreateWalletPrism.handler(%{}, %{})
      
      assert Map.has_key?(result, :address)
      assert Map.has_key?(result, :encrypted_private_key)
      assert String.starts_with?(result.address, "0x")
      assert is_binary(result.encrypted_private_key)

      # Verify transaction manager was started
      assert {:ok, _pid} = TransactionManager.get_manager(result.address)
    end
  end

  test "successfully imports existing private key and starts transaction manager" do
    with_mocks([
      {Ethers, [], [
        get_transaction_count: fn _addr -> {:ok, 5} end
      ]}
    ]) do
      # Import private key
      private_key = "0x0000000000000000000000000000000000000000000000000000000000000001"
      expected_address = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"

      assert {:ok, result} = CreateWalletPrism.handler(%{private_key: private_key}, %{})
      assert result.address == expected_address
      assert is_binary(result.encrypted_private_key)

      # Verify transaction manager was started and has correct address
      assert {:ok, pid} = TransactionManager.get_manager(expected_address)
      Process.sleep(50)
      state = :sys.get_state(pid)
      assert state.nonce == 5
    end
  end
end
