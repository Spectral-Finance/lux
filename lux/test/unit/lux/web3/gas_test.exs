defmodule Lux.Web3.GasTest do
  use UnitCase, async: true

  alias Lux.Web3.Gas

  @sender "0x1111111111111111111111111111111111111111"
  @recipient "0x2222222222222222222222222222222222222222"

  defp history do
    %{
      "baseFeePerGas" => ["0x64", "0x70", "0x7e"],
      "reward" => [["0x1", "0x3", "0x9"], ["0x2", "0x5", "0xb"]]
    }
  end

  defp pending do
    %{
      "from" => @sender,
      "to" => @recipient,
      "nonce" => "0x7",
      "chainId" => "0x1",
      "type" => "0x2",
      "value" => "0x4",
      "data" => "0x1234",
      "gas" => "0x186a0",
      "maxFeePerGas" => "0x65",
      "maxPriorityFeePerGas" => "0xb"
    }
  end

  test "quotes the next base fee from feeHistory with integer fee headroom" do
    assert {:ok, quote} = Gas.quote(history(), min_priority_fee: 1, blocks: 2)
    assert quote.base_fee_per_gas == 126
    assert quote.max_priority_fee_per_gas == 5
    assert quote.max_fee_per_gas == 163
    assert quote.estimated_fee_per_gas == 131
  end

  test "speed tiers select the requested reward percentile and enforce a tip floor" do
    assert {:ok, slow} = Gas.quote(history(), speed: :slow, min_priority_fee: 1, blocks: 0)
    assert {:ok, fast} = Gas.quote(history(), speed: :fast, min_priority_fee: 1, blocks: 0)
    assert slow.max_priority_fee_per_gas == 2
    assert fast.max_priority_fee_per_gas == 11
    assert {:ok, floor} = Gas.quote(history(), min_priority_fee: 20)
    assert floor.max_priority_fee_per_gas == 20
  end

  test "base fee follows EIP-1559 including minimum upward change and downward rounding" do
    assert {:ok, 112} = Gas.next_base_fee(100, 30_000_000, 30_000_000)
    assert {:ok, 100} = Gas.next_base_fee(100, 15_000_000, 30_000_000)
    assert {:ok, 88} = Gas.next_base_fee(100, 0, 30_000_000)
    assert {:ok, 2} = Gas.next_base_fee(1, 30_000_000, 30_000_000)
    assert {:error, _} = Gas.next_base_fee(100, 31, 30)
    assert {:error, _} = Gas.next_base_fee(100, 0, 1)
  end

  test "rejects missing, malformed and mismatched history rather than inventing prices" do
    for data <- [
          %{},
          %{"baseFeePerGas" => []},
          Map.put(history(), "reward", []),
          Map.put(history(), "reward", [["0x1"]]),
          Map.put(history(), "baseFeePerGas", ["0xno", "0x1", "0x2"])
        ] do
      assert {:error, _} = Gas.quote(data)
    end

    assert {:error, _} = Gas.quote(history(), speed: :unknown)
    assert {:error, _} = Gas.quote(history(), blocks: -1)
    assert {:error, _} = Gas.quote(history(), min_priority_fee: -1)
  end

  test "speed-up preserves intent and nonce while rounding both fee caps upward" do
    assert {:ok, tx} = Gas.replace(pending(), 200, :speed_up)
    assert tx["nonce"] == "0x7"
    assert tx["to"] == @recipient
    assert tx["data"] == "0x1234"
    assert tx["value"] == "0x4"
    assert tx["maxPriorityFeePerGas"] == "0xd"
    assert tx["maxFeePerGas"] == "0xd5"
  end

  test "cancel is a zero-value self transfer without the original access list or calldata" do
    original = Map.put(pending(), "accessList", [%{"address" => @recipient, "storageKeys" => []}])
    assert {:ok, tx} = Gas.replace(original, 50, :cancel)
    assert tx["nonce"] == original["nonce"]
    assert tx["chainId"] == "0x1"
    assert tx["to"] == @sender
    assert tx["value"] == "0x0"
    assert tx["data"] == "0x"
    refute Map.has_key?(tx, "accessList")
    refute Map.has_key?(tx, "gas")
  end

  test "replacement rejects legacy fees, invalid amounts and unknown actions" do
    assert {:error, _} = Gas.replace(Map.put(pending(), "gasPrice", "0x1"), 10, :speed_up)
    assert {:error, _} = Gas.replace(Map.delete(pending(), "nonce"), 10, :speed_up)
    assert {:error, _} = Gas.replace(pending(), -1, :speed_up)
    assert {:error, _} = Gas.replace(pending(), 10, :other)
    assert {:error, _} = Gas.replace(pending(), 10, :speed_up, bump_percent: 0)
  end

  test "cost report separates expected cost from the fee cap and preserves big integers" do
    assert {:ok, report} = Gas.cost(21_000, 24_000, 100, 150, 2, 7)
    assert report.expected_fee_wei == 2_142_000
    assert report.maximum_fee_wei == 3_600_000
    assert report.required_balance_wei == 3_600_007
    assert report.effective_fee_per_gas == 102
    assert {:ok, capped} = Gas.cost(1, 1, 100, 101, 2, 0)
    assert capped.expected_fee_wei == 101
    assert {:error, _} = Gas.cost(21_000, 20_000, 100, 150, 2, 0)
    assert {:error, _} = Gas.cost(1, 1, 100, 99, 2, 0)
  end

  test "gas token refunds require an explicit pre-London adapter and positive net savings" do
    assert {:error, :gas_tokens_disabled_after_london} =
             Gas.gas_token_savings(%{london: true}, fn -> flunk("must not call adapter") end)

    assert {:ok, %{use_token: false, net_savings_wei: -10}} =
             Gas.gas_token_savings(%{london: false}, fn ->
               {:ok, %{refund_wei: 100, purchase_wei: 90, execution_wei: 20}}
             end)

    assert {:ok, %{use_token: true, net_savings_wei: 70}} =
             Gas.gas_token_savings(%{london: false}, fn ->
               {:ok, %{refund_wei: 100, purchase_wei: 10, execution_wei: 20}}
             end)

    assert {:error, _} = Gas.gas_token_savings(%{}, fn -> :ok end)
  end

  test "quantity parsing is strict and does not use floating point" do
    big = 10 ** 30 + 1
    assert {:ok, ^big} = Gas.quantity(Gas.hex(big))

    for value <- [-1, 1.0, "0x", "0x-1", "0x1junk", "12", nil, %{}] do
      assert {:error, _} = Gas.quantity(value)
    end
  end
end
