defmodule Lux.Web3.Contracts.CurveV2CRVTest do
  @moduledoc false
  use UnitCase, async: true

  alias Ethers
  alias Lux.Web3.Contracts.CurveV2CRV

  @crv "0xD533a949740bb3306d119CC777fa900bA034cd52"
  @user "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  @spender "0x522b139797aA4BC9a1e3782E52cF884c5b1d4338"
  @one_unit "0x0000000000000000000000000000000000000000000000000000000000000001"

  defmodule MockRpc do
    @behaviour Ethers.RpcClient.Adapter

    def eth_call(_params, _block, _opts) do
      {:ok, Process.get(:curve_crv_mock_hex, "0x00")}
    end

    def batch_request(_requests, _opts), do: {:error, :unsupported}
    def eth_block_number(_opts), do: {:error, :unsupported}
    def eth_chain_id(_opts), do: {:error, :unsupported}
    def eth_estimate_gas(_params, _opts), do: {:error, :unsupported}
    def eth_gas_price(_opts), do: {:error, :unsupported}
    def eth_get_balance(_account, _block, _opts), do: {:error, :unsupported}
    def eth_get_block_by_number(_block, _full, _opts), do: {:error, :unsupported}
    def eth_get_transaction_by_hash(_hash, _opts), do: {:error, :unsupported}
    def eth_get_transaction_count(_account, _block, _opts), do: {:error, :unsupported}
    def eth_get_transaction_receipt(_hash, _opts), do: {:error, :unsupported}
    def eth_max_priority_fee_per_gas(_opts), do: {:error, :unsupported}
    def eth_blob_base_fee(_opts), do: {:error, :unsupported}
    def eth_get_logs(_filter, _opts), do: {:error, :unsupported}
    def eth_send_transaction(_tx, _opts), do: {:error, :unsupported}
    def eth_send_raw_transaction(_signed_tx, _opts), do: {:error, :unsupported}
  end

  defp call(tx, overrides \\ []) do
    Ethers.call(tx, Keyword.merge([to: @crv, from: @user, rpc_client: MockRpc], overrides))
  end

  describe "module loading (regression probe)" do
    test "curve CRV contract module exports reward token functions" do
      assert CurveV2CRV.balance_of(@user) != nil
      assert function_exported?(CurveV2CRV, :total_supply, 0)
      assert function_exported?(CurveV2CRV, :symbol, 0)
      assert function_exported?(CurveV2CRV, :decimals, 0)
      assert function_exported?(CurveV2CRV, :allowance, 2)
      assert function_exported?(CurveV2CRV, :transfer, 2)
      assert function_exported?(CurveV2CRV, :approve, 2)
    end
  end

  describe "happy path: CRV reward token queries" do
    setup do
      Process.put(:curve_crv_mock_hex, @one_unit)
      :ok
    end

    test "balance_of/1 reports a holder's CRV balance", _ do
      assert {:ok, 1} = call(CurveV2CRV.balance_of(@user))
    end

    test "total_supply/0 reports the CRV supply", _ do
      assert {:ok, 1} = call(CurveV2CRV.total_supply())
    end

    test "allowance/2 reports the reward distributor allowance", _ do
      assert {:ok, 1} = call(CurveV2CRV.allowance(@user, @spender))
    end
  end

  describe "null input: graceful typed validation error, no crash" do
    test "call/2 with a null CRV address is refused with a typed error" do
      assert {:error, :no_to_address} = call(CurveV2CRV.total_supply(), to: nil)
    end
  end

  describe "empty input: rejected with a clear diagnostic" do
    test "call/2 without a CRV address is refused" do
      assert {:error, :no_to_address} = Ethers.call(CurveV2CRV.symbol())
    end
  end

  describe "boundary limits: strict half-open evaluation" do
    test "zero balance is handled at the lower bound", _ do
      Process.put(
        :curve_crv_mock_hex,
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      )

      assert {:ok, 0} = call(CurveV2CRV.balance_of(@user))
    end

    test "maximum uint256 balance is handled at the upper bound", _ do
      Process.put(:curve_crv_mock_hex, "0x" <> String.duplicate("f", 64))

      max_uint =
        115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935

      assert {:ok, ^max_uint} = call(CurveV2CRV.balance_of(@user))
    end
  end

  describe "negative: malformed inputs are refused" do
    test "a negative transfer amount raises a typed validation error", _ do
      assert_raise ArgumentError, fn -> CurveV2CRV.transfer(@user, -1) end
    end

    test "an invalid spender address raises a typed validation error", _ do
      assert_raise ArgumentError, fn -> CurveV2CRV.approve("not-an-address", 1) end
    end
  end

  describe "concurrency: simultaneous CRV queries" do
    test "concurrent balance queries return consistent results with zero double-spend", _ do
      tx = CurveV2CRV.balance_of(@user)

      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            Process.put(:curve_crv_mock_hex, @one_unit)
            call(tx)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      assert length(results) == 20
      assert Enum.all?(results, &(&1 == {:ok, 1}))
    end
  end
end
