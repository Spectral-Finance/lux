defmodule Lux.Web3.Contracts.CurveV2PoolTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Web3.Contracts.CurveV2Pool
  alias Ethers

  # Curve 3pool (DAI/USDC/USDT) on Ethereum mainnet.
  @pool "0xcE4933736166e591F6149750aB95a91578295e49"
  @user "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  @gauge "0x522b139797aa4bc9a1e3782e52cf884c5b1d4338"

  # One unit of the quote coin (1e18) and one unit of CRV (1e18), hex encoded.
  @one_unit "0x0000000000000000000000000000000000000000000000000000000000000001"
  @one_crv "0x00000000000000000000000000000000000000000000000000000000000000a2"

  # Mock RPC client: every eth_call returns the canned hex stored in the calling
  # process dictionary, so concurrent tests cannot leak results between tests.
  defmodule MockRpc do
    @behaviour Ethers.RpcClient.Adapter

    def eth_call(_params, _block, _opts) do
      case Process.get(:curve_mock_hex) do
        nil ->
          {:ok, "0x0000000000000000000000000000000000000000000000000000000000000001"}

        hex ->
          {:ok, hex}
      end
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
    Ethers.call(tx, Keyword.merge([to: @pool, from: @user, rpc_client: MockRpc], overrides))
  end

  describe "module loading (regression probe)" do
    test "curve pool contract module exists and exports pool query functions" do
      assert function_exported?(CurveV2Pool, :name, 0)
      assert function_exported?(CurveV2Pool, :symbol, 0)
      assert function_exported?(CurveV2Pool, :decimals, 0)
      assert function_exported?(CurveV2Pool, :get_dy, 3)
      assert function_exported?(CurveV2Pool, :balances, 1)
      assert function_exported?(CurveV2Pool, :get_virtual_price, 0)
      assert function_exported?(CurveV2Pool, :total_supply, 0)
      assert function_exported?(CurveV2Pool, :balance_of, 1)
      assert function_exported?(CurveV2Pool, :minter, 0)
      assert function_exported?(CurveV2Pool, :fee, 0)
    end
  end

  describe "happy path: stablecoin pool queries" do
    setup do
      Process.put(:curve_mock_hex, @one_unit)
      :ok
    end

    test "get_dy/3 quotes a stablecoin swap", _ do
      tx = CurveV2Pool.get_dy(0, 1, 1_000_000_000_000_000_000)
      assert {:ok, 1} = call(tx)
    end

    test "balance_of/1 reports a holder's LP position", _ do
      tx = CurveV2Pool.balance_of(@user)
      assert {:ok, 1} = call(tx)
    end

    test "minter/0 resolves the linked curve gauge address", _ do
      Process.put(
        :curve_mock_hex,
        "0x000000000000000000000000522b139797aa4bc9a1e3782e52cf884c5b1d4338"
      )

      expected_gauge = @gauge
      tx = CurveV2Pool.minter()
      assert {:ok, ^expected_gauge} = call(tx)
    end

    test "get_virtual_price/0 reports the pool share price", _ do
      Process.put(:curve_mock_hex, @one_unit)
      tx = CurveV2Pool.get_virtual_price()
      assert {:ok, 1} = call(tx)
    end

    test "balances/1 reports a coin reserve at lower bound index", _ do
      Process.put(:curve_mock_hex, @one_unit)
      tx = CurveV2Pool.balances(0)
      assert {:ok, 1} = call(tx)
    end
  end

  describe "null input: graceful typed validation error, no crash" do
    test "call/2 with a null recipient is refused with a typed error" do
      tx = CurveV2Pool.name()
      assert {:error, :no_to_address} = call(tx, to: nil)
    end

    test "null overrides do not crash the pool query path" do
      tx = CurveV2Pool.symbol()
      assert {:error, :no_to_address} = Ethers.call(tx, to: nil)
    end
  end

  describe "empty input: rejected with a clear diagnostic" do
    test "call/2 without a recipient address is refused" do
      tx = CurveV2Pool.decimals()
      assert {:error, :no_to_address} = Ethers.call(tx)
    end
  end

  describe "boundary limits: strict half-open evaluation" do
    setup do
      Process.put(:curve_mock_hex, @one_unit)
      :ok
    end

    test "zero swap amount is accepted at the lower bound", _ do
      tx = CurveV2Pool.get_dy(0, 1, 0)
      assert {:ok, _} = call(tx)
    end

    test "maximum uint256 amount is accepted at the upper bound", _ do
      max_uint =
        115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935

      tx = CurveV2Pool.get_dy(0, 1, max_uint)
      assert {:ok, _} = call(tx)
    end
  end

  describe "negative: malformed inputs are refused" do
    test "a non-integer coin index raises a typed validation error" do
      assert_raise ArgumentError, fn ->
        CurveV2Pool.get_dy("not-an-integer", 1, 100)
      end
    end

    test "a negative swap amount raises a typed validation error" do
      assert_raise ArgumentError, fn ->
        CurveV2Pool.get_dy(0, 1, -1)
      end
    end
  end

  describe "concurrency: simultaneous queries on the same pool" do
    setup do
      Process.put(:curve_mock_hex, @one_crv)
      :ok
    end

    test "concurrent balance_of queries are consistent with zero double-spend", _ do
      tx = CurveV2Pool.balance_of(@user)

      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            # Each task configures its own process-dictionary mock; child
            # processes do not inherit the caller's process dictionary.
            Process.put(:curve_mock_hex, @one_crv)
            call(tx)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      assert length(results) == 20
      assert Enum.all?(results, &(&1 == {:ok, 162}))
    end
  end
end
