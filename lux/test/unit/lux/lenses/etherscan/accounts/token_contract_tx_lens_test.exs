defmodule Lux.Lenses.Etherscan.TokenContractTxLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TokenContractTx

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1 with contractaddress parameter" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
        chainid: 1,
        startblock: 0,
        endblock: 27_025_780,
        page: 1,
        offset: 100,
        sort: "asc"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "tokentx"
        assert query["contractaddress"] == "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"
        assert query["startblock"] == "0"
        assert query["endblock"] == "27025780"
        assert query["page"] == "1"
        assert query["offset"] == "100"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample token transfers
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "12345678",
              "timeStamp" => "1622222222",
              "hash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
              "nonce" => "123",
              "blockHash" => "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "from" => "0x4e83362442b8d1bec281594cea3050c8eb01311c",
              "contractAddress" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
              "to" => "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
              "value" => "1000000000000000000",
              "tokenName" => "Maker",
              "tokenSymbol" => "MKR",
              "tokenDecimal" => "18",
              "transactionIndex" => "123",
              "gas" => "100000",
              "gasPrice" => "50000000000",
              "gasUsed" => "80000",
              "cumulativeGasUsed" => "1000000",
              "input" => "0x",
              "confirmations" => "1000"
            }
          ]
        })
      end)

      # Call the lens
      result = TokenContractTx.focus(params)

      # Verify the result
      assert {:ok, %{result: [transfer]}} = result
      assert transfer["hash"] == "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
      assert transfer["contractAddress"] == "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"
      assert transfer["tokenName"] == "Maker"
      assert transfer["tokenSymbol"] == "MKR"
    end

    test "handles empty transfer list" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty transfer list
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "No transactions found",
          "result" => "No token transfers found"
        })
      end)

      # Call the lens
      result = TokenContractTx.focus(params)

      # Verify the result
      assert {:error, %{message: "No transactions found", result: "No token transfers found"}} = result
    end
  end

  describe "error handling" do
    test "handles error responses" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "NOTOK",
          "result" => "Error! Invalid address format"
        })
      end)

      # Call the lens
      result = TokenContractTx.focus(params)

      # Verify the result
      assert {:error, %{message: "NOTOK", result: "Error! Invalid address format"}} = result
    end

    test "handles API errors" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
        chainid: 1
      }

      # Mock the API response to return an error
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response instead of a timeout
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "NOTOK",
          "result" => "Error! API request limit reached"
        })
      end)

      # Call the lens
      result = TokenContractTx.focus(params)

      # Verify the result
      assert {:error, %{message: "NOTOK", result: "Error! API request limit reached"}} = result
    end
  end
end 