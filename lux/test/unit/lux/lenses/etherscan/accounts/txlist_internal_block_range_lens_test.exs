defmodule Lux.Lenses.Etherscan.TxListInternalBlockRangeLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TxListInternalBlockRange

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1 with block range parameters" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        startblock: 13_481_773,
        endblock: 13_491_773,
        page: 1,
        offset: 10,
        sort: "asc",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txlistinternal"
        assert query["startblock"] == "13481773"
        assert query["endblock"] == "13491773"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample internal transactions
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "13481780",
              "timeStamp" => "1632218636",
              "hash" => "0x8a1a9989bda84f80143181a68bc137ecefa64d0d4ebde45dd94fc0cf49e70cb6",
              "from" => "0x7a250d5630b4cf539739df2c5dacb4c659f2488d",
              "to" => "0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f",
              "value" => "0",
              "contractAddress" => "",
              "input" => "",
              "type" => "call",
              "gas" => "2300",
              "gasUsed" => "0",
              "traceId" => "0",
              "isError" => "0",
              "errCode" => ""
            }
          ]
        })
      end)

      # Call the lens
      result = TxListInternalBlockRange.focus(params)

      # Verify the result
      assert {:ok, %{result: [transaction]}} = result
      assert transaction["blockNumber"] == "13481780"
      assert transaction["hash"] == "0x8a1a9989bda84f80143181a68bc137ecefa64d0d4ebde45dd94fc0cf49e70cb6"
      assert transaction["from"] == "0x7a250d5630b4cf539739df2c5dacb4c659f2488d"
    end

    test "handles empty transaction list" do
      # Set up the test parameters
      params = %{
        startblock: 13_481_773,
        endblock: 13_491_773,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty transaction list
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "No transactions found",
          "result" => "No internal transactions found"
        })
      end)

      # Call the lens
      result = TxListInternalBlockRange.focus(params)

      # Verify the result
      assert {:error, %{message: "No transactions found", result: "No internal transactions found"}} = result
    end
  end

  describe "error handling" do
    test "handles error responses" do
      # Set up the test parameters
      params = %{
        startblock: -1,
        endblock: 13_491_773,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid block range"
        })
      end)

      # Call the lens
      result = TxListInternalBlockRange.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid block range"}} = result
    end

    test "handles API errors" do
      # Set up the test parameters
      params = %{
        startblock: 13_481_773,
        endblock: 13_491_773,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "NOTOK",
          "result" => "Error! API request limit reached"
        })
      end)

      # Call the lens
      result = TxListInternalBlockRange.focus(params)

      # Verify the result
      assert {:error, %{message: "NOTOK", result: "Error! API request limit reached"}} = result
    end
  end
end 