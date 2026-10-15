defmodule Lux.Web3.MultiChainAggregatorTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.Web3.MultiChainAggregatorPrism
  alias Lux.Web3.Aggregator
  alias Lux.Web3.Aggregator.Normalizer.NormalizedBlock
  alias Lux.Web3.Aggregator.Normalizer.NormalizedEvent
  alias Lux.Web3.Aggregator.RPCManager

  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  setup do
    Aggregator.reset!()
    Application.put_env(:lux, RPCManager, plug: {Req.Test, RPCManager})
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Multi-chain block & transaction monitoring and real-time streaming" do
    test "syncs, normalizes, indexes, and streams blocks across Ethereum, BSC, and Polygon" do
      :ok = Aggregator.subscribe(self(), :block)

      Req.Test.expect(RPCManager, 3, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_getBlockByNumber"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => decoded["id"],
          "result" => %{
            "number" => "0x100",
            "hash" => "0xblockhash100",
            "parentHash" => "0xblockhash099",
            "timestamp" => "0x65f00000",
            "gasUsed" => "0x5208",
            "gasLimit" => "0x1c9c380",
            "baseFeePerGas" => "0x3b9aca00",
            "transactions" => [
              %{
                "hash" => "0xtxhash1",
                "blockNumber" => "0x100",
                "from" => "0x1111111111111111111111111111111111111111",
                "to" => "0x2222222222222222222222222222222222222222",
                "value" => "0xde0b6b3a7640000",
                "gas" => "0x5208",
                "gasPrice" => "0x4a817c800",
                "nonce" => "0x1",
                "input" => "0x"
              }
            ]
          }
        })
      end)

      {:ok, %{blocks: blocks, errors: errors}} =
        Aggregator.sync_latest_blocks([:ethereum, :bsc, :polygon])

      assert errors == %{}
      assert length(blocks) == 3
      assert Enum.all?(blocks, &match?(%NormalizedBlock{block_number: 256}, &1))

      assert_receive {:lux_multichain_update, :block, %NormalizedBlock{chain: :ethereum}}
      assert_receive {:lux_multichain_update, :block, %NormalizedBlock{chain: :bsc}}
      assert_receive {:lux_multichain_update, :block, %NormalizedBlock{chain: :polygon}}

      txs = Aggregator.query_transactions(chains: [:ethereum, :polygon])
      assert length(txs) == 2
      assert hd(txs).value_wei == 1_000_000_000_000_000_000
    end
  end

  describe "Smart contract event filtering, decoding, and retention" do
    test "collects and decodes ERC-20 Transfer logs across multiple chains" do
      :ok = Aggregator.subscribe(self(), :event)

      Req.Test.expect(RPCManager, 2, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_getLogs"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => decoded["id"],
          "result" => [
            %{
              "address" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
              "blockNumber" => "0x200",
              "transactionHash" => "0xevtx1",
              "logIndex" => "0x0",
              "topics" => [
                @transfer_topic,
                "0x0000000000000000000000001111111111111111111111111111111111111111",
                "0x0000000000000000000000002222222222222222222222222222222222222222"
              ],
              "data" => "0x00000000000000000000000000000000000000000000000000000000000f4240"
            }
          ]
        })
      end)

      {:ok, %{events: events}} =
        Aggregator.collect_events([:ethereum, :arbitrum], %{
          contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
          from_block: 500,
          to_block: 520
        })

      assert length(events) == 2

      [%NormalizedEvent{} = first | _] = events
      assert first.event_name == "Transfer"
      assert first.decoded_params.from == "0x1111111111111111111111111111111111111111"
      assert first.decoded_params.to == "0x2222222222222222222222222222222222222222"
      assert first.decoded_params.value == 1_000_000

      assert_receive {:lux_multichain_update, :event, %NormalizedEvent{event_name: "Transfer"}}

      queried = Aggregator.query_events(event_name: "Transfer", chains: [:arbitrum])
      assert length(queried) == 1

      retention = Aggregator.enforce_retention(max_events: 1)
      assert retention.pruned_events == 1
      assert length(Aggregator.query_events()) == 1
    end

    test "enforces per-chain rate limits and endpoint failover" do
      RPCManager.register_network(%{
        id: :custom_evm,
        chain_id: 9999,
        name: "Custom EVM",
        native_symbol: "CEVM",
        endpoints: ["https://primary-fail.example", "https://backup-ok.example"],
        rate_limit_per_window: 1,
        window_ms: 60_000
      })

      Req.Test.expect(RPCManager, fn conn ->
        Plug.Conn.send_resp(conn, 502, "Bad Gateway")
      end)

      Req.Test.expect(RPCManager, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x10"})
      end)

      assert {:ok, "0x10"} = RPCManager.call(:custom_evm, "eth_blockNumber", [])
      assert {:error, :rate_limited} = RPCManager.call(:custom_evm, "eth_blockNumber", [])
    end

    test "supports agent queries through MultiChainAggregatorPrism" do
      assert {:ok, stats} =
               MultiChainAggregatorPrism.handler(%{"action" => "summary"}, nil)

      assert is_map(stats)
      assert stats.total_blocks == 0
    end
  end
end
