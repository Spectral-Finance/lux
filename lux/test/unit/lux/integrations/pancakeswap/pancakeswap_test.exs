defmodule Lux.Integrations.PancakeSwapTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap

  describe "chain/1" do
    test "finds chains by name, id and numeric string" do
      assert {:ok, %{id: 56, name: "bsc"}} = PancakeSwap.chain("bsc")
      assert {:ok, %{id: 56}} = PancakeSwap.chain("BSC")
      assert {:ok, %{id: 56}} = PancakeSwap.chain(56)
      assert {:ok, %{id: 56}} = PancakeSwap.chain("56")
      assert {:ok, %{id: 56}} = PancakeSwap.chain(:bsc)
      assert {:ok, %{name: "base"}} = PancakeSwap.chain(8453)
    end

    test "rejects unknown chains" do
      assert PancakeSwap.chain("solana") == {:error, :unsupported_chain}
      assert PancakeSwap.chain(999_999) == {:error, :unsupported_chain}
      assert PancakeSwap.chain(nil) == {:error, :unsupported_chain}
    end

    test "fetch_chain/1 explains the supported chains" do
      assert {:error, message} = PancakeSwap.fetch_chain("solana")
      assert message =~ "Unsupported chain"
      assert message =~ "bsc"
    end

    test "supported_chains/0 is sorted" do
      assert PancakeSwap.supported_chains() == ["arbitrum", "base", "bsc", "ethereum"]
    end
  end

  describe "address/3" do
    test "returns configured addresses" do
      {:ok, bsc} = PancakeSwap.chain("bsc")
      assert {:ok, "0x" <> _} = PancakeSwap.address(bsc, :masterchef_v2)
    end

    test "reports contracts that are not configured for a chain" do
      {:ok, base} = PancakeSwap.chain("base")
      assert {:error, message} = PancakeSwap.address(base, :masterchef_v2)
      assert message =~ "not configured for base"
    end

    test "prefers a valid override and rejects an invalid one" do
      {:ok, base} = PancakeSwap.chain("base")
      override = "0x00000000000000000000000000000000000000aa"

      assert PancakeSwap.address(base, :masterchef_v2, override) == {:ok, override}
      assert {:error, _} = PancakeSwap.address(base, :masterchef_v2, "nope")
      assert {:error, _} = PancakeSwap.address(base, :masterchef_v2, 5)
    end
  end

  describe "amount helpers" do
    test "parse_amount/1 accepts integers and digit strings" do
      assert PancakeSwap.parse_amount(0) == {:ok, 0}

      assert PancakeSwap.parse_amount("123456789012345678901234567890") ==
               {:ok, 123_456_789_012_345_678_901_234_567_890}

      assert PancakeSwap.parse_amount(-1) == :error
      assert PancakeSwap.parse_amount("1.5") == :error
      assert PancakeSwap.parse_amount("-1") == :error
      assert PancakeSwap.parse_amount(nil) == :error
    end

    test "parse_positive_amount/1 rejects zero" do
      assert PancakeSwap.parse_positive_amount("0") == :error
      assert PancakeSwap.parse_positive_amount(5) == {:ok, 5}
    end

    test "apply_slippage/2 rounds down" do
      assert PancakeSwap.apply_slippage(1000, 50) == 995
      assert PancakeSwap.apply_slippage(500, 50) == 497
      assert PancakeSwap.apply_slippage(1000, 0) == 1000
      assert PancakeSwap.apply_slippage(1000, 10_000) == 0
    end

    test "parse_slippage/1 defaults and validates" do
      assert PancakeSwap.parse_slippage(nil) == {:ok, 50}
      assert PancakeSwap.parse_slippage(100) == {:ok, 100}
      assert {:error, _} = PancakeSwap.parse_slippage(10_001)
      assert {:error, _} = PancakeSwap.parse_slippage(-1)
      assert {:error, _} = PancakeSwap.parse_slippage("5")
    end
  end

  describe "deadline/1" do
    test "uses an explicit deadline" do
      assert PancakeSwap.deadline(%{deadline: 1_900_000_000}) == 1_900_000_000
    end

    test "adds twenty minutes to :now" do
      assert PancakeSwap.deadline(%{now: 1_000}) == 2_200
    end

    test "defaults to the current time plus twenty minutes" do
      before = System.os_time(:second)
      deadline = PancakeSwap.deadline(%{})
      assert deadline >= before + 1_200
      assert deadline <= System.os_time(:second) + 1_200
    end
  end

  describe "field/3 and format_error/1" do
    test "field/3 reads atom and string keys" do
      assert PancakeSwap.field(%{a: 1}, :a) == 1
      assert PancakeSwap.field(%{"a" => 2}, :a) == 2
      assert PancakeSwap.field(%{}, :a, :default) == :default
      assert PancakeSwap.field(%{a: false}, :a, true) == false
    end

    test "format_error/1 stringifies client errors" do
      assert PancakeSwap.format_error("boom") == "boom"

      assert PancakeSwap.format_error({:rpc_error, -32_000, "reverted"}) ==
               "RPC error -32000: reverted"

      assert PancakeSwap.format_error({:http_error, 500, %{"m" => 1}}) =~ "HTTP 500"
      assert PancakeSwap.format_error(:empty_result) == ":empty_result"
    end
  end
end
