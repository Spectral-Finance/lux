defmodule Lux.Lenses.Etherscan.GetLogsLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.GetLogs

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call for address with block range" do
      # Set up the test parameters
      params = %{
        address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        fromBlock: 12_878_196,
        toBlock: 12_878_196,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "logs"
        assert query["action"] == "getLogs"
        assert query["address"] == "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
        assert query["fromBlock"] == "12878196"
        assert query["toBlock"] == "12878196"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "address" => "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
              "topics" => [
                "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                "0x0000000000000000000000000000000000000000000000000000000000000000",
                "0x000000000000000000000000a79e63e78eec28741e711f89a672a4c40876ebf3"
              ],
              "data" => "0x",
              "blockNumber" => "12878196",
              "timeStamp" => "1628736144",
              "gasPrice" => "94000000000",
              "gasUsed" => "65715",
              "logIndex" => "142",
              "transactionHash" => "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649",
              "transactionIndex" => "93"
            }
          ]
        })
      end)

      # Call the lens
      result = GetLogs.focus(params)

      # Verify the result
      assert {:ok, %{result: logs}} = result
      assert length(logs) == 1

      # Verify log data
      log = Enum.at(logs, 0)
      assert log.address == "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
      assert length(log.topics) == 3
      assert Enum.at(log.topics, 0) == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert log.block_number == "12878196"
      assert log.transaction_hash == "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649"
    end

    test "makes correct API call for address with pagination" do
      # Set up the test parameters
      params = %{
        address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        fromBlock: 12_878_196,
        toBlock: 12_878_196,
        page: 1,
        offset: 10,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["page"] == "1"
        assert query["offset"] == "10"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "address" => "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
              "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
              "data" => "0x",
              "blockNumber" => "12878196",
              "timeStamp" => "1628736144",
              "gasPrice" => "94000000000",
              "gasUsed" => "65715",
              "logIndex" => "142",
              "transactionHash" => "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649",
              "transactionIndex" => "93"
            }
          ]
        })
      end)

      # Call the lens
      result = GetLogs.focus(params)

      # Verify the result
      assert {:ok, %{result: logs}} = result
      assert length(logs) == 1
    end

    test "makes correct API call for topics filtering" do
      # Set up the test parameters
      params = %{
        fromBlock: 12_878_196,
        toBlock: 12_879_196,
        topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        topic0_1_opr: "and",
        topic1: "0x0000000000000000000000000000000000000000000000000000000000000000",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["topic0"] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        assert query["topic0_1_opr"] == "and"
        assert query["topic1"] == "0x0000000000000000000000000000000000000000000000000000000000000000"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "address" => "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
              "topics" => [
                "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                "0x0000000000000000000000000000000000000000000000000000000000000000"
              ],
              "data" => "0x",
              "blockNumber" => "12878196",
              "timeStamp" => "1628736144",
              "gasPrice" => "94000000000",
              "gasUsed" => "65715",
              "logIndex" => "142",
              "transactionHash" => "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649",
              "transactionIndex" => "93"
            }
          ]
        })
      end)

      # Call the lens
      result = GetLogs.focus(params)

      # Verify the result
      assert {:ok, %{result: logs}} = result
      assert length(logs) == 1
    end

    test "makes correct API call for address with topics filtering" do
      # Set up the test parameters
      params = %{
        address: "0x59728544b08ab483533076417fbbb2fd0b17ce3a",
        fromBlock: 15_073_139,
        toBlock: 15_074_139,
        topic0: "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d",
        topic0_1_opr: "and",
        topic1: "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["address"] == "0x59728544b08ab483533076417fbbb2fd0b17ce3a"
        assert query["topic0"] == "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d"
        assert query["topic0_1_opr"] == "and"
        assert query["topic1"] == "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "address" => "0x59728544b08ab483533076417fbbb2fd0b17ce3a",
              "topics" => [
                "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d",
                "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b"
              ],
              "data" => "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000186a0",
              "blockNumber" => "15073140",
              "timeStamp" => "1650984144",
              "gasPrice" => "35000000000",
              "gasUsed" => "46715",
              "logIndex" => "123",
              "transactionHash" => "0x7d598e2e4b3b91864e1e699c4ab4bfaa6c0a4b5f6d3c5fcb8cb5cd49d2bfabed",
              "transactionIndex" => "45"
            }
          ]
        })
      end)

      # Call the lens
      result = GetLogs.focus(params)

      # Verify the result
      assert {:ok, %{result: logs}} = result
      assert length(logs) == 1

      # Verify log data
      log = Enum.at(logs, 0)
      assert log.address == "0x59728544b08ab483533076417fbbb2fd0b17ce3a"
      assert length(log.topics) == 2
      assert Enum.at(log.topics, 0) == "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d"
      assert log.block_number == "15073140"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid data
      params = %{
        address: "0xinvalid",
        fromBlock: 12_878_196,
        toBlock: 12_878_196,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid address format"
        })
      end)

      # Call the lens
      result = GetLogs.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles empty results" do
      # Set up the test parameters
      params = %{
        address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        fromBlock: 12_878_196,
        toBlock: 12_878_196,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty result
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      # Call the lens
      result = GetLogs.focus(params)

      # Verify the result
      assert {:ok, %{result: logs}} = result
      assert logs == []
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        fromBlock: 12_878_196,
        toBlock: 12_878_196,
        chainid: 1
      }

      # Call the function
      result = GetLogs.before_focus(params)

      # Verify the result
      assert result.module == "logs"
      assert result.action == "getLogs"
      assert result.address == "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
      assert result.fromBlock == 12_878_196
      assert result.toBlock == 12_878_196
      assert result.chainid == 1
    end

    test "prepares parameters correctly with topics" do
      # Set up the test parameters
      params = %{
        fromBlock: 12_878_196,
        toBlock: 12_879_196,
        topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        topic0_1_opr: "and",
        topic1: "0x0000000000000000000000000000000000000000000000000000000000000000",
        chainid: 1
      }

      # Call the function
      result = GetLogs.before_focus(params)

      # Verify the result
      assert result.module == "logs"
      assert result.action == "getLogs"
      assert result.fromBlock == 12_878_196
      assert result.toBlock == 12_879_196
      assert result.topic0 == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert result.topic0_1_opr == "and"
      assert result.topic1 == "0x0000000000000000000000000000000000000000000000000000000000000000"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "address" => "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
            "topics" => [
              "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
              "0x0000000000000000000000000000000000000000000000000000000000000000",
              "0x000000000000000000000000a79e63e78eec28741e711f89a672a4c40876ebf3"
            ],
            "data" => "0x",
            "blockNumber" => "12878196",
            "timeStamp" => "1628736144",
            "gasPrice" => "94000000000",
            "gasUsed" => "65715",
            "logIndex" => "142",
            "transactionHash" => "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649",
            "transactionIndex" => "93"
          }
        ]
      }

      # Call the function
      result = GetLogs.after_focus(response)

      # Verify the result
      assert {:ok, %{result: logs}} = result
      assert length(logs) == 1

      # Verify log data
      log = Enum.at(logs, 0)
      assert log.address == "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
      assert length(log.topics) == 3
      assert Enum.at(log.topics, 0) == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert log.block_number == "12878196"
      assert log.transaction_hash == "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649"
    end

    test "processes empty result" do
      # Create a mock response with empty result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => []
      }

      # Call the function
      result = GetLogs.after_focus(response)

      # Verify the result
      assert {:ok, %{result: logs}} = result
      assert logs == []
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = GetLogs.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end
