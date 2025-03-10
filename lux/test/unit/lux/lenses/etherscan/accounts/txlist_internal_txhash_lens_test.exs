defmodule Lux.Lenses.Etherscan.TxListInternalTxhashLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TxListInternalTxhash

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1 with txhash parameter" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
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
        assert query["txhash"] == "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample internal transactions
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "2702578",
              "timeStamp" => "1472278636",
              "hash" => "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
              "from" => "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3",
              "to" => "0x9eab4b0fc468a7f5d46228bf5a76cb52370d068d",
              "value" => "50000000000000000",
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
      result = TxListInternalTxhash.focus(params)

      # Verify the result
      assert {:ok, %{result: [transaction]}} = result
      assert transaction["hash"] == "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"
      assert transaction["from"] == "0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3"
      assert transaction["value"] == "50000000000000000"
    end

    test "handles empty transaction list" do
      # Set up the test parameters
      params = %{
        txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
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
      result = TxListInternalTxhash.focus(params)

      # Verify the result
      assert {:error, %{message: "No transactions found", result: "No internal transactions found"}} = result
    end
  end

  describe "error handling" do
    test "handles error responses" do
      # Set up the test parameters
      params = %{
        txhash: "0xinvalid",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid txhash format"
        })
      end)

      # Call the lens
      result = TxListInternalTxhash.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid txhash format"}} = result
    end

    test "handles API errors" do
      # Set up the test parameters
      params = %{
        txhash: "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170",
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
      result = TxListInternalTxhash.focus(params)

      # Verify the result
      assert {:error, %{message: "NOTOK", result: "Error! API request limit reached"}} = result
    end
  end
end 