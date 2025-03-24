defmodule Lux.Lenses.Etherscan.BeaconWithdrawalLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.BeaconWithdrawal

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        address: "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
        chainid: 1,
        startblock: 17_000_000,
        endblock: 18_000_000,
        page: 1,
        offset: 10,
        sort: "desc"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txsBeaconWithdrawal"
        assert query["address"] == "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f"
        assert query["startblock"] == "17000000"
        assert query["endblock"] == "18000000"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["sort"] == "desc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "17500000",
              "timeStamp" => "1680000000",
              "hash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
              "withdrawalIndex" => "123456",
              "validatorIndex" => "789012",
              "address" => "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
              "amount" => "32000000000"
            },
            %{
              "blockNumber" => "17400000",
              "timeStamp" => "1679000000",
              "hash" => "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
              "withdrawalIndex" => "123455",
              "validatorIndex" => "789011",
              "address" => "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
              "amount" => "1000000000"
            }
          ]
        })
      end)

      # Call the lens
      result = BeaconWithdrawal.focus(params)

      # Verify the result
      assert {:ok, %{result: withdrawals}} = result
      assert length(withdrawals) == 2
      assert Enum.at(withdrawals, 0)["blockNumber"] == "17500000"
      assert Enum.at(withdrawals, 0)["amount"] == "32000000000"
      assert Enum.at(withdrawals, 1)["blockNumber"] == "17400000"
      assert Enum.at(withdrawals, 1)["amount"] == "1000000000"
    end

    test "handles empty withdrawals list" do
      # Set up the test parameters
      params = %{
        address: "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty withdrawals list
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "No transactions found",
          "result" => "No withdrawals found"
        })
      end)

      # Call the lens
      result = BeaconWithdrawal.focus(params)

      # Verify the result
      assert {:error, %{message: "No transactions found", result: "No withdrawals found"}} = result
    end

    test "handles error responses" do
      # Set up the test parameters
      params = %{
        address: "0xinvalid",
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
      result = BeaconWithdrawal.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        address: "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
        chainid: 1,
        startblock: 17_000_000,
        endblock: 18_000_000,
        page: 1,
        offset: 10,
        sort: "desc"
      }

      # Call the function
      result = BeaconWithdrawal.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "txsBeaconWithdrawal"
      assert result.address == "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f"
      assert result.chainid == 1
      assert result.startblock == 17_000_000
      assert result.endblock == 18_000_000
      assert result.page == 1
      assert result.offset == 10
      assert result.sort == "desc"
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
            "blockNumber" => "17500000",
            "timeStamp" => "1680000000",
            "hash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            "withdrawalIndex" => "123456",
            "validatorIndex" => "789012",
            "address" => "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f",
            "amount" => "32000000000"
          }
        ]
      }

      # Call the function
      result = BeaconWithdrawal.after_focus(response)

      # Verify the result
      assert {:ok, %{result: [withdrawal]}} = result
      assert withdrawal["blockNumber"] == "17500000"
      assert withdrawal["amount"] == "32000000000"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = BeaconWithdrawal.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end
