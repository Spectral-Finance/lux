defmodule Lux.MultiChain.AggregatorTest do
  use UnitAPICase, async: false

  alias Lux.MultiChain.Aggregator
  alias Lux.MultiChain.Cache

  setup do
    Cache.init()
    Cache.clear_all()

    Application.put_env(:lux, :multi_chain, %{
      rpc_endpoints: %{
        ethereum: ["http://localhost:8545"],
        polygon: ["http://localhost:8546"],
        bsc: ["http://localhost:8547"]
      }
    })

    Req.Test.verify_on_exit!()
    :ok
  end

  describe "get_latest_blocks/1" do
    test "fetches blocks from multiple chains in parallel" do
      # Each chain makes one request
      for _chain <- [:ethereum, :polygon] do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => %{
              "number" => "0x112A880",
              "hash" => "0xblock_hash",
              "parentHash" => "0xparent",
              "timestamp" => "0x64F5A4C0",
              "miner" => "0xminer",
              "gasUsed" => "0xE4E1C0",
              "gasLimit" => "0x1C9C380",
              "baseFeePerGas" => "0x4A817C800",
              "transactions" => []
            }
          })
        end)
      end

      assert {:ok, blocks} = Aggregator.get_latest_blocks([:ethereum, :polygon])
      assert length(blocks) == 2
      assert Enum.all?(blocks, &(&1.__struct__ == Lux.MultiChain.DataModel.Block))
    end
  end

  describe "get_block/2" do
    test "fetches a specific block" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => %{
            "number" => "0x112A880",
            "hash" => "0xblock_hash_specific",
            "parentHash" => "0xparent",
            "timestamp" => "0x64F5A4C0",
            "miner" => "0xminer",
            "gasUsed" => "0xE4E1C0",
            "gasLimit" => "0x1C9C380"
          }
        })
      end)

      assert {:ok, block} = Aggregator.get_block(:ethereum, 18_000_000)
      assert block.hash == "0xblock_hash_specific"
    end

    test "returns error when block not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => nil})
      end)

      assert {:error, "Block not found"} = Aggregator.get_block(:ethereum, 99_999_999_999)
    end
  end

  describe "get_balances/2" do
    test "fetches balances across multiple chains" do
      for _chain <- [:ethereum, :polygon] do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0xDE0B6B3A7640000"
          })
        end)
      end

      assert {:ok, balances} =
               Aggregator.get_balances(
                 "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
                 [:ethereum, :polygon]
               )

      assert length(balances) == 2
      assert Enum.all?(balances, &(&1.__struct__ == Lux.MultiChain.DataModel.TokenBalance))

      for balance <- balances do
        assert balance.balance_formatted == 1.0
      end
    end
  end

  describe "get_balance/2" do
    test "fetches balance for a single chain" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => "0x1BC16D674EC80000"
        })
      end)

      assert {:ok, balance} =
               Aggregator.get_balance(:ethereum, "0x742d35Cc6634C0532925a3b844Bc454e4438f44e")

      assert balance.chain == :ethereum
      assert balance.balance_formatted == 2.0
    end
  end

  describe "get_transaction/2" do
    test "fetches a transaction by hash" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => %{
            "hash" => "0xtx_hash",
            "blockNumber" => "0x112A880",
            "from" => "0xSender",
            "to" => "0xReceiver",
            "value" => "0xDE0B6B3A7640000",
            "gas" => "0x5208",
            "gasPrice" => "0x4A817C800",
            "nonce" => "0x2A",
            "input" => "0x"
          }
        })
      end)

      assert {:ok, tx} = Aggregator.get_transaction(:ethereum, "0xtx_hash")
      assert tx.hash == "0xtx_hash"
      assert tx.chain == :ethereum
      assert tx.from == "0xsender"
    end

    test "returns error when transaction not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => nil})
      end)

      assert {:error, "Transaction not found"} =
               Aggregator.get_transaction(:ethereum, "0xnonexistent")
    end
  end

  describe "get_events/2" do
    test "fetches events matching a filter" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => [
            %{
              "address" => "0xContract",
              "topics" => ["0xtopic0", "0xtopic1"],
              "data" => "0xdata",
              "blockNumber" => "0x112A880",
              "transactionHash" => "0xtx",
              "logIndex" => "0x5"
            },
            %{
              "address" => "0xContract",
              "topics" => ["0xtopic0"],
              "data" => "0xdata2",
              "blockNumber" => "0x112A881",
              "transactionHash" => "0xtx2",
              "logIndex" => "0x0"
            }
          ]
        })
      end)

      assert {:ok, events} =
               Aggregator.get_events(:ethereum, %{
                 address: "0xContract",
                 topics: ["0xtopic0"],
                 from_block: 18_000_000,
                 to_block: 18_000_100
               })

      assert length(events) == 2
      assert Enum.all?(events, &(&1.__struct__ == Lux.MultiChain.DataModel.Event))
    end

    test "returns empty list when no events found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => []})
      end)

      assert {:ok, []} = Aggregator.get_events(:ethereum, %{address: "0xAddr"})
    end
  end

  describe "get_gas_prices/1" do
    test "fetches gas prices from multiple chains" do
      for _chain <- [:ethereum, :polygon] do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0x4A817C800"
          })
        end)
      end

      assert {:ok, prices} = Aggregator.get_gas_prices([:ethereum, :polygon])
      assert length(prices) == 2
      assert Enum.all?(prices, &(&1.__struct__ == Lux.MultiChain.DataModel.GasPrice))
    end
  end

  describe "chain_summary/2" do
    test "returns summaries for multiple chains" do
      # Each chain needs 2 calls: block + gas price
      for _i <- 1..4 do
        Req.Test.expect(Lux.Lens, fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)

          case decoded["method"] do
            "eth_getBlockByNumber" ->
              Req.Test.json(conn, %{
                "jsonrpc" => "2.0",
                "id" => 1,
                "result" => %{
                  "number" => "0x112A880",
                  "hash" => "0xhash",
                  "parentHash" => "0xparent",
                  "timestamp" => "0x64F5A4C0",
                  "miner" => "0xminer",
                  "gasUsed" => "0xE4E1C0",
                  "gasLimit" => "0x1C9C380"
                }
              })

            "eth_gasPrice" ->
              Req.Test.json(conn, %{
                "jsonrpc" => "2.0",
                "id" => 1,
                "result" => "0x4A817C800"
              })

            _ ->
              Req.Test.json(conn, %{
                "jsonrpc" => "2.0",
                "id" => 1,
                "result" => "0x0"
              })
          end
        end)
      end

      assert {:ok, summaries} = Aggregator.chain_summary([:ethereum, :polygon])
      assert length(summaries) >= 1

      for summary <- summaries do
        assert Map.has_key?(summary, :chain)
        assert Map.has_key?(summary, :latest_block)
        assert Map.has_key?(summary, :gas_price_gwei)
      end
    end
  end
end
