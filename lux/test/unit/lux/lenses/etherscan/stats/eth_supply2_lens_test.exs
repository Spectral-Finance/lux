defmodule Lux.Lenses.Etherscan.EthSupply2LensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.EthSupply2

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
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "ethsupply2"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "EthSupply" => "123456789012345678901234567",
            "Eth2Staking" => "12345678901234567890",
            "BurntFees" => "9876543210987654321",
            "WithdrawnTotal" => "1234567890123456789"
          }
        })
      end)

      # Call the lens
      result = EthSupply2.focus(params)

      # Verify the result
      assert {:ok, %{result: eth_supply_details, eth_supply_details: eth_supply_details}} = result

      # Check that the values are approximately correct (since large numbers are represented in scientific notation)
      assert_in_delta eth_supply_details.eth_supply, 1.23_456_789e26, 1.0e20
      assert_in_delta eth_supply_details.eth2_staking, 1.23_456_789e19, 1.0e15
      assert_in_delta eth_supply_details.burnt_fees, 9.87_654_321e18, 1.0e15
      assert_in_delta eth_supply_details.withdrawn_eth, 1.23_456_789e18, 1.0e15
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "ethsupply2"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "EthSupply" => "123456789012345678901234567",
            "Eth2Staking" => "12345678901234567890",
            "BurntFees" => "9876543210987654321",
            "WithdrawnTotal" => "1234567890123456789"
          }
        })
      end)

      # Call the lens
      result = EthSupply2.focus(params)

      # Verify the result
      assert {:ok, %{result: eth_supply_details}} = result
      assert_in_delta eth_supply_details.eth_supply, 1.23_456_789e26, 1.0e20
    end

    test "handles error responses" do
      # Set up the test parameters
      params = %{
        chainid: 999_999 # Invalid chain ID
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid chain ID"
        })
      end)

      # Call the lens
      result = EthSupply2.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        chainid: 1
      }

      # Call the function
      result = EthSupply2.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "ethsupply2"
      assert result.chainid == 1
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Call the function
      result = EthSupply2.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "ethsupply2"
    end
  end

  describe "after_focus/1" do
    test "processes successful response and converts to numbers" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "EthSupply" => "123456789012345678901234567",
          "Eth2Staking" => "12345678901234567890",
          "BurntFees" => "9876543210987654321",
          "WithdrawnTotal" => "1234567890123456789"
        }
      }

      # Call the function
      result = EthSupply2.after_focus(response)

      # Verify the result
      assert {:ok, %{result: eth_supply_details, eth_supply_details: eth_supply_details}} = result

      # Check that the values are approximately correct (since large numbers are represented in scientific notation)
      assert_in_delta eth_supply_details.eth_supply, 1.23_456_789e26, 1.0e20
      assert_in_delta eth_supply_details.eth2_staking, 1.23_456_789e19, 1.0e15
      assert_in_delta eth_supply_details.burnt_fees, 9.87_654_321e18, 1.0e15
      assert_in_delta eth_supply_details.withdrawn_eth, 1.23_456_789e18, 1.0e15
    end

    test "processes float values correctly" do
      # Create a mock response with float values
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "EthSupply" => "123456789.123_456_789",
          "Eth2Staking" => "12345.6789",
          "BurntFees" => "9876.54_321",
          "WithdrawnTotal" => "1234.56_789"
        }
      }

      # Call the function
      result = EthSupply2.after_focus(response)

      # Verify the result
      assert {:ok, %{result: eth_supply_details}} = result
      assert eth_supply_details.eth_supply == 123_456_789.123_456_789
      assert eth_supply_details.eth2_staking == 12_345.6789
      assert eth_supply_details.burnt_fees == 9_876.54_321
      assert eth_supply_details.withdrawn_eth == 1_234.56_789
    end

    test "processes non-numeric result" do
      # Create a mock response with non-numeric result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "EthSupply" => "unavailable",
          "Eth2Staking" => "unavailable",
          "BurntFees" => "unavailable",
          "WithdrawnTotal" => "unavailable"
        }
      }

      # Call the function
      result = EthSupply2.after_focus(response)

      # Verify the result
      assert {:ok, %{result: eth_supply_details}} = result
      assert eth_supply_details.eth_supply == "unavailable"
      assert eth_supply_details.eth2_staking == "unavailable"
      assert eth_supply_details.burnt_fees == "unavailable"
      assert eth_supply_details.withdrawn_eth == "unavailable"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid chain ID"
      }

      # Call the function
      result = EthSupply2.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end
  end
end
