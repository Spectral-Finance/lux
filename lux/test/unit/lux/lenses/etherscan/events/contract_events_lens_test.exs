defmodule Lux.Lenses.Etherscan.ContractEventsLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.ContractEvents

  setup do
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])

    :ok
  end

  describe "focus/1" do
    test "makes correct API call for event monitoring" do
      params = %{
        address: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc",
        fromBlock: 12_878_196,
        toBlock: 12_879_196,
        chainid: 1
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "logs"
        assert query["action"] == "getLogs"
        Req.Test.json(conn, %{"status" => "1", "message" => "OK", "result" => [%{ "address" => "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc", "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"], "data" => "0x", "blockNumber" => "12878196", "timeStamp" => "1628736144", "gasPrice" => "94000000000", "gasUsed" => "65715", "logIndex" => "142", "transactionHash" => "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649", "transactionIndex" => "93" }]})
      end)

      result = ContractEvents.focus(params)
      assert {:ok, %{result: events, total_count: 1, webhook_payload: webhook}} = result
      assert length(events) == 1
      event = Enum.at(events, 0)
      assert event["event_signature"] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert event["block_number"] == "12878196"
      assert webhook["count"] == 1
      assert webhook["source"] == "etherscan_logs"
    end

    test "handles empty event results" do
      params = %{address: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc", fromBlock: 12_878_196, toBlock: 12_878_196, chainid: 1}
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"status" => "1", "message" => "OK", "result" => []})
      end)
      result = ContractEvents.focus(params)
      assert {:ok, %{result: [], total_count: 0, webhook_payload: %{}}} = result
    end

    test "handles error responses" do
      params = %{address: "0xinvalid", fromBlock: 12_878_196, toBlock: 12_878_196, chainid: 1}
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"status" => "0", "message" => "Error", "result" => "Invalid address format"})
      end)
      result = ContractEvents.focus(params)
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "supports topic filtering" do
      params = %{address: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc", fromBlock: 12_878_196, toBlock: 12_879_196, topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef", chainid: 1}
      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["topic0"] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        Req.Test.json(conn, %{"status" => "1", "message" => "OK", "result" => []})
      end)
      result = ContractEvents.focus(params)
      assert {:ok, _} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      params = %{address: "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc", fromBlock: 12_878_196, toBlock: 12_879_196}
      result = ContractEvents.before_focus(params)
      assert result.module == "logs"
      assert result.action == "getLogs"
      assert result.address == "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc"
      assert result.fromBlock == 12_878_196
      assert result.toBlock == 12_879_196
    end
  end

  describe "after_focus/1" do
    test "processes successful response with events" do
      response = %{"status" => "1", "message" => "OK", "result" => [%{ "address" => "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc", "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"], "data" => "0x", "blockNumber" => "12878196", "timeStamp" => "1628736144", "gasPrice" => "94000000000", "gasUsed" => "65715", "logIndex" => "142", "transactionHash" => "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649", "transactionIndex" => "93" }]}
      result = ContractEvents.after_focus(response)
      assert {:ok, %{result: events, total_count: 1}} = result
      assert length(events) == 1
      assert Enum.at(events, 0)["event_signature"] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    end

    test "processes empty result" do
      response = %{"status" => "1", "message" => "OK", "result" => []}
      result = ContractEvents.after_focus(response)
      assert {:ok, %{result: [], total_count: 0}} = result
    end

    test "processes error response" do
      response = %{"status" => "0", "message" => "Error", "result" => "Invalid address format"}
      result = ContractEvents.after_focus(response)
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end

  describe "decode/2" do
    test "decodes raw logs without ABI" do
      logs = [%{ "address" => "0xb4e16d0168e52d35cacd2c6185b44281ec28c9dc", "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"], "data" => "0x", "blockNumber" => "12878196" }]
      result = ContractEvents.decode(logs, nil)
      assert length(result) == 1
      assert Enum.at(result, 0)["event_signature"] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    end

    test "decodes raw logs with ABI" do
      logs = [%{ "address" => "0xdac17f958d2ee523a2206206994597c13d831ec7", "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef", "0x000000000000000000000000a79e63e78eec28741e711f89a672a4c40876ebf3", "0x000000000000000000000000b4e16d0168e52d35cacd2c6185b44281ec28c9dc"], "data" => "0x0000000000000000000000000000000000000000000000000000000005f5e100", "blockNumber" => "18000000" }]
      abi = [%{ "anonymous" => false, "inputs" => [%{"indexed" => true, "name" => "from", "type" => "address"}, %{"indexed" => true, "name" => "to", "type" => "address"}, %{"indexed" => false, "name" => "value", "type" => "uint256"}], "name" => "Transfer", "type" => "event" }]
      result = ContractEvents.decode(logs, abi)
      assert length(result) == 1
      decoded = result |> Enum.at(0) |> Map.get("decoded")
      assert decoded["name"] == "Transfer"
      assert decoded["signature"] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    end

    test "returns raw marker for unknown event signatures" do
      logs = [%{ "address" => "0x0000000000000000000000000000000000000001", "topics" => ["0x0000000000000000000000000000000000000000000000000000000000000000"], "data" => "0x" }]
      abi = [%{ "anonymous" => false, "inputs" => [], "name" => "UnknownEvent", "type" => "event" }]
      result = ContractEvents.decode(logs, abi)
      assert length(result) == 1
      decoded = result |> Enum.at(0) |> Map.get("decoded")
      assert decoded["raw"] == true
    end
  end
end
