defmodule Lux.Lenses.Etherscan.TokenBalanceLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TokenBalance

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
        contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
        address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
        tag: "latest",
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
        assert query["action"] == "tokenbalance"
        assert query["contractaddress"] == "0x57d90b64a1a57749b0f932f1a3395792e12e7055"
        assert query["address"] == "0xe04f27eb70e025b78871a2ad7eabe85e61212761"
        assert query["tag"] == "latest"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "135499"
        })
      end)

      # Call the lens
      result = TokenBalance.focus(params)

      # Verify the result
      assert {:ok, %{result: "135499", token_balance: "135499"}} = result
    end

    test "makes correct API call with default tag parameter" do
      # Set up the test parameters without tag
      params = %{
        contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
        address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["tag"] == "latest"  # Default value

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "135499"
        })
      end)

      # Call the lens
      result = TokenBalance.focus(params)

      # Verify the result
      assert {:ok, %{result: "135499", token_balance: "135499"}} = result
    end

    test "handles error responses" do
      # Set up the test parameters with invalid addresses
      params = %{
        contractaddress: "0xinvalid",
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
      result = TokenBalance.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
        address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
        tag: "latest",
        chainid: 1
      }

      # Call the function
      result = TokenBalance.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "tokenbalance"
      assert result.contractaddress == "0x57d90b64a1a57749b0f932f1a3395792e12e7055"
      assert result.address == "0xe04f27eb70e025b78871a2ad7eabe85e61212761"
      assert result.tag == "latest"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "135499"
      }

      # Call the function
      result = TokenBalance.after_focus(response)

      # Verify the result
      assert {:ok, %{result: "135499", token_balance: "135499"}} = result
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = TokenBalance.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end
