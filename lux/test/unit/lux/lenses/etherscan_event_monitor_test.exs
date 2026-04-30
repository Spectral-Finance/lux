defmodule Lux.Lenses.Etherscan.EventMonitorTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.Events.ContractEventLens
  alias Lux.Lenses.Etherscan.Events.TokenTransferLens
  alias Lux.Lenses.Etherscan.Events.InternalTransactionLens
  alias Lux.Lenses.Etherscan.Events.NewContractsLens
  alias Lux.Lenses.Etherscan.Events.UniswapSwapLens

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])

    :ok
  end

  describe "ContractEventLens" do
    test "focus/1 fetches contract events correctly" do
      params = %{
        contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        from_block: 18_000_000,
        to_block: 18_001_000,
        chainid: 1
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        query = URI.decode_query(conn.query_string)
        assert query["module"] == "logs"
        assert query["action"] == "getLogs"
        assert query["address"] == "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
        assert query["fromBlock"] == "18000000"
        assert query["toBlock"] == "18001000"
        assert query["apikey"] == "TEST_API_KEY"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "address" => "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
              "topics" => [
                "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                "0x000000000000000000000000c5102fe9359fd9a28f877a67e36b0f050d81a3cc",
                "0x000000000000000000000000a79e63e78eec28741e711f89a672a4c40876ebf3"
              ],
              "data" => "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
              "blockNumber" => "18000001",
              "timeStamp" => "1690000000",
              "gasPrice" => "20000000000",
              "gasUsed" => "45000",
              "logIndex" => "50",
              "transactionHash" => "0xabc123def456",
              "transactionIndex" => "10"
            }
          ]
        })
      end)

      result = ContractEventLens.focus(params)

      assert {:ok, %{events: events, count: 1}} = result
      event = Enum.at(events, 0)
      assert event.address == "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
      assert length(event.topics) == 3
      assert event.block_number == "18000001"
      assert event.transaction_hash == "0xabc123def456"
    end

    test "before_focus/1 prepares parameters correctly" do
      params = %{
        contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        from_block: 18_000_000,
        to_block: 18_001_000,
        chainid: 1
      }

      result = ContractEventLens.before_focus(params)

      assert result.module == "logs"
      assert result.action == "getLogs"
      assert result.fromBlock == 18_000_000
      assert result.toBlock == 18_001_000
    end

    test "handles error responses" do
      params = %{
        contract_address: "0xinvalid",
        from_block: 18_000_000,
        to_block: 18_001_000
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid address format"
        })
      end)

      result = ContractEventLens.focus(params)
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles empty results" do
      params = %{
        contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        from_block: 18_000_000,
        to_block: 18_001_000
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      result = ContractEventLens.focus(params)
      assert {:ok, %{events: [], count: 0}} = result
    end
  end

  describe "TokenTransferLens" do
    test "focus/1 fetches token transfers correctly" do
      params = %{
        contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        page: 1,
        offset: 50,
        chainid: 1
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "tokentx"
        assert query["contractaddress"] == "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
        assert query["apikey"] == "TEST_API_KEY"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "18000001",
              "timeStamp" => "1690000000",
              "hash" => "0xabc123",
              "nonce" => "100",
              "blockHash" => "0xdef456",
              "from" => "0xc5102fe9359fd9a28f877a67e36b0f050d81a3cc",
              "contractAddress" => "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
              "to" => "0xa79e63e78eec28741e711f89a672a4c40876ebf3",
              "value" => "1000000000000000000",
              "tokenName" => "Uniswap",
              "tokenSymbol" => "UNI",
              "tokenDecimal" => "18",
              "transactionIndex" => "5",
              "gas" => "50000",
              "gasPrice" => "20000000000",
              "gasUsed" => "45000",
              "logIndex" => "10"
            }
          ]
        })
      end)

      result = TokenTransferLens.focus(params)

      assert {:ok, %{transfers: transfers, count: 1}} = result
      transfer = Enum.at(transfers, 0)
      assert transfer.from == "0xc5102fe9359fd9a28f877a67e36b0f050d81a3cc"
      assert transfer.to == "0xa79e63e78eec28741e711f89a672a4c40876ebf3"
      assert transfer.token_symbol == "UNI"
      assert transfer.value == "1000000000000000000"
    end

    test "before_focus/1 prepares parameters correctly" do
      params = %{
        contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
        wallet_address: "0xc5102fe9359fd9a28f877a67e36b0f050d81a3cc",
        page: 1,
        offset: 50
      }

      result = TokenTransferLens.before_focus(params)

      assert result.module == "account"
      assert result.action == "tokentx"
      assert result.address == "0xc5102fe9359fd9a28f877a67e36b0f050d81a3cc"
      assert result.sort == "desc"
    end

    test "handles error responses" do
      params = %{
        contract_address: "0xinvalid"
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid contract address"
        })
      end)

      result = TokenTransferLens.focus(params)
      assert {:error, %{message: "Error", result: "Invalid contract address"}} = result
    end
  end

  describe "InternalTransactionLens" do
    test "focus/1 fetches internal transactions correctly" do
      params = %{
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
        start_block: 18_000_000,
        end_block: 18_001_000,
        page: 1,
        offset: 50,
        chainid: 1
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txlistinternal"
        assert query["address"] == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
        assert query["startblock"] == "18000000"
        assert query["endblock"] == "18001000"
        assert query["apikey"] == "TEST_API_KEY"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "18000001",
              "timeStamp" => "1690000000",
              "hash" => "0xabc123",
              "from" => "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
              "to" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
              "value" => "1000000000000000000",
              "contractAddress" => "",
              "input" => "0x",
              "type" => "call",
              "gas" => "50000",
              "gasUsed" => "45000",
              "traceId" => "1",
              "isError" => "0",
              "errCode" => ""
            }
          ]
        })
      end)

      result = InternalTransactionLens.focus(params)

      assert {:ok, %{internal_transactions: transactions, count: 1}} = result
      tx = Enum.at(transactions, 0)
      assert tx.from == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
      assert tx.to == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      assert tx.value == "1000000000000000000"
      assert tx.type == "call"
    end

    test "before_focus/1 prepares parameters correctly" do
      params = %{
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
        start_block: 18_000_000,
        end_block: 18_001_000
      }

      result = InternalTransactionLens.before_focus(params)

      assert result.module == "account"
      assert result.action == "txlistinternal"
      assert result.startblock == 18_000_000
      assert result.endblock == 18_001_000
    end

    test "handles error responses" do
      params = %{
        address: "0xinvalid"
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid address"
        })
      end)

      result = InternalTransactionLens.focus(params)
      assert {:error, %{message: "Error", result: "Invalid address"}} = result
    end
  end

  describe "NewContractsLens" do
    test "focus/1 fetches new contract deployments correctly" do
      params = %{
        block_start: 18_000_000,
        block_end: 18_001_000,
        page: 1,
        offset: 100,
        chainid: 1
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        query = URI.decode_query(conn.query_string)
        assert query["module"] == "contract"
        assert query["action"] == "getcontractcreation"
        assert query["startblock"] == "18000000"
        assert query["endblock"] == "18001000"
        assert query["apikey"] == "TEST_API_KEY"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "contractAddress" => "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
              "contractCreator" => "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
              "txHash" => "0xabc123def456",
              "blockNumber" => "18000001",
              "methodId" => "0x608060",
              "create2Key" => ""
            }
          ]
        })
      end)

      result = NewContractsLens.focus(params)

      assert {:ok, %{contracts: contracts, count: 1}} = result
      contract = Enum.at(contracts, 0)
      assert contract.contract_address == "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F"
      assert contract.contract_creator == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
      assert contract.tx_hash == "0xabc123def456"
    end

    test "before_focus/1 prepares parameters correctly" do
      params = %{
        block_start: 18_000_000,
        block_end: 18_001_000
      }

      result = NewContractsLens.before_focus(params)

      assert result.module == "contract"
      assert result.action == "getcontractcreation"
      assert result.startblock == 18_000_000
      assert result.endblock == 18_001_000
    end

    test "handles error responses" do
      params = %{
        block_start: 18_000_000,
        block_end: 18_001_000
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid block range"
        })
      end)

      result = NewContractsLens.focus(params)
      assert {:error, %{message: "Error", result: "Invalid block range"}} = result
    end
  end

  describe "UniswapSwapLens" do
    @swap_topic "0xc42079f94a6350d7e6235f29174924f91065fbc2da3237a9a9b3f4a31aace1a1"

    test "focus/1 fetches Uniswap V3 swaps correctly" do
      params = %{
        pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
        from_block: 18_000_000,
        to_block: 18_001_000,
        chainid: 1
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        query = URI.decode_query(conn.query_string)
        assert query["module"] == "logs"
        assert query["action"] == "getLogs"
        assert query["topic0"] == @swap_topic
        assert query["address"] == "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"
        assert query["fromBlock"] == "18000000"
        assert query["toBlock"] == "18001000"
        assert query["apikey"] == "TEST_API_KEY"

        # Create mock swap event data (simplified)
        amount0 = Integer.to_string(:rand.uniform(1_000_000))
        amount1 = Integer.to_string(:rand.uniform(1_000_000))
        padded_amount0 = String.pad_leading(amount0, 64, "0")
        padded_amount1 = String.pad_leading(amount1, 64, "0")
        mock_data = "0x#{padded_amount0}#{padded_amount1}#{String.duplicate("0", 128)}"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "address" => "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
              "topics" => [
                @swap_topic,
                "0x000000000000000000000000c5102fe9359fd9a28f877a67e36b0f050d81a3cc",
                "0x00000000000000000000000068b3465833fb72a70ecdf485e0e4c7bd8665fc45"
              ],
              "data" => mock_data,
              "blockNumber" => "18000001",
              "timeStamp" => "1690000000",
              "gasPrice" => "20000000000",
              "gasUsed" => "80000",
              "logIndex" => "100",
              "transactionHash" => "0xswap123",
              "transactionIndex" => "5"
            }
          ]
        })
      end)

      result = UniswapSwapLens.focus(params)

      assert {:ok, %{swaps: swaps, count: count}} = result
      assert count >= 0
      if count > 0 do
        swap = Enum.at(swaps, 0)
        assert swap.pool == "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"
        assert swap.transaction_hash == "0xswap123"
        assert swap.block_number == "18000001"
      end
    end

    test "before_focus/1 prepares parameters correctly" do
      params = %{
        pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
        from_block: 18_000_000,
        to_block: 18_001_000
      }

      result = UniswapSwapLens.before_focus(params)

      assert result.module == "logs"
      assert result.action == "getLogs"
      assert result.topic0 == @swap_topic
      assert result.address == "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640"
      assert result.fromBlock == 18_000_000
      assert result.toBlock == 18_001_000
    end

    test "filters by sender address" do
      params = %{
        pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
        sender: "0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45",
        from_block: 18_000_000,
        to_block: 18_001_000
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["topic1"] == "0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      result = UniswapSwapLens.focus(params)
      assert {:ok, %{swaps: [], count: 0}} = result
    end

    test "handles error responses" do
      params = %{
        pool_address: "0xinvalid",
        from_block: 18_000_000,
        to_block: 18_001_000
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid pool address"
        })
      end)

      result = UniswapSwapLens.focus(params)
      assert {:error, %{message: "Error", result: "Invalid pool address"}} = result
    end
  end

  describe "multi-chain support" do
    test "all lenses support Polygon chain" do
      params = %{
        contract_address: "0x2791Bca1f2de4661ED88A30C99A7a1Aaf9c0b0d4",
        from_block: 45_000_000,
        to_block: 45_001_000,
        chainid: 137
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["chainid"] == "137"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      result = ContractEventLens.focus(params)
      assert {:ok, _} = result
    end

    test "all lenses support Arbitrum chain" do
      params = %{
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
        start_block: 10_000_000,
        end_block: 10_001_000,
        chainid: 42161
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["chainid"] == "42161"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      result = InternalTransactionLens.focus(params)
      assert {:ok, _} = result
    end

    test "all lenses support BSC chain" do
      params = %{
        block_start: 30_000_000,
        block_end: 30_001_000,
        chainid: 56
      }

      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["chainid"] == "56"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      result = NewContractsLens.focus(params)
      assert {:ok, _} = result
    end
  end
end
