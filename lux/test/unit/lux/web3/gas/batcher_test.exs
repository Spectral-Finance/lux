defmodule Lux.Web3.Gas.BatcherTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Gas.Batcher

  describe "create_batch/1" do
    test "errors on empty calls list" do
      assert {:error, msg} = Batcher.create_batch([])
      assert String.contains?(msg, "Cannot create an empty batch")
    end

    test "bundles calls and calculates gas savings accurately" do
      calls = [
        %{target: "0x1111111111111111111111111111111111111111", call_data: "0x01", allow_failure: false},
        %{target: "0x2222222222222222222222222222222222222222", call_data: "0x02", allow_failure: true},
        %{target: "0x3333333333333333333333333333333333333333", call_data: "0x03", allow_failure: false}
      ]

      {:ok, summary} = Batcher.create_batch(calls)

      assert summary.calls_count == 3
      assert summary.gas_saved > 0
      assert summary.savings_percentage > 15.0
      assert summary.multicall_address == "0xcA11bde05977b3631167028862bE2a173976CA11"
      assert length(summary.calls) == 3
    end
  end

  describe "should_flush?/3" do
    test "returns true when batch reaches minimum size" do
      queue = [%{a: 1}, %{a: 2}, %{a: 3}]
      assert Batcher.should_flush?(queue, 3, 500_000) == true
      assert Batcher.should_flush?(queue, 5, 500_000) == false
    end

    test "returns true when gas threshold exceeded" do
      queue = [%{a: 1}, %{a: 2}]
      # 2 tx * 21000 = 42000
      assert Batcher.should_flush?(queue, 10, 40_000) == true
    end
  end

  describe "encode_aggregate3/1" do
    test "structures aggregate3 call properly" do
      calls = [
        %{target: "0xabc", call_data: "0x123", allow_failure: true, value: 0}
      ]

      encoded = Batcher.encode_aggregate3(calls)
      assert encoded.to == "0xcA11bde05977b3631167028862bE2a173976CA11"
      assert encoded.function == "aggregate3((address,bool,bytes)[])"
      assert length(encoded.calls) == 1
    end
  end
end
