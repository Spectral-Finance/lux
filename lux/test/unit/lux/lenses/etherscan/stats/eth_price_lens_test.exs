defmodule Lux.Lenses.Etherscan.EthPriceLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.EthPrice

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
        assert query["action"] == "ethprice"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "ethbtc" => "0.05123",
            "ethbtc_timestamp" => "1677123456",
            "ethusd" => "1850.45",
            "ethusd_timestamp" => "1677123456"
          }
        })
      end)

      # Call the lens
      result = EthPrice.focus(params)

      # Verify the result
      assert {:ok, %{result: eth_price, eth_price: eth_price}} = result
      assert eth_price.eth_btc == 0.05123
      assert eth_price.eth_btc_timestamp == 1_677_123_456
      assert eth_price.eth_usd == 1850.45
      assert eth_price.eth_usd_timestamp == 1_677_123_456
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "ethprice"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "ethbtc" => "0.05123",
            "ethbtc_timestamp" => "1677123456",
            "ethusd" => "1850.45",
            "ethusd_timestamp" => "1677123456"
          }
        })
      end)

      # Call the lens
      result = EthPrice.focus(params)

      # Verify the result
      assert {:ok, %{result: eth_price}} = result
      assert eth_price.eth_btc == 0.05123
      assert eth_price.eth_usd == 1850.45
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
      result = EthPrice.focus(params)

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
      result = EthPrice.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "ethprice"
      assert result.chainid == 1
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Call the function
      result = EthPrice.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "ethprice"
    end
  end

  describe "after_focus/1" do
    test "processes successful response and converts to numbers" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "ethbtc" => "0.05123",
          "ethbtc_timestamp" => "1677123456",
          "ethusd" => "1850.45",
          "ethusd_timestamp" => "1677123456"
        }
      }

      # Call the function
      result = EthPrice.after_focus(response)

      # Verify the result
      assert {:ok, %{result: eth_price, eth_price: eth_price}} = result
      assert eth_price.eth_btc == 0.05123
      assert eth_price.eth_btc_timestamp == 1_677_123_456
      assert eth_price.eth_usd == 1850.45
      assert eth_price.eth_usd_timestamp == 1_677_123_456
    end

    test "processes non-numeric result" do
      # Create a mock response with non-numeric result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "ethbtc" => "unavailable",
          "ethbtc_timestamp" => "unavailable",
          "ethusd" => "unavailable",
          "ethusd_timestamp" => "unavailable"
        }
      }

      # Call the function
      result = EthPrice.after_focus(response)

      # Verify the result
      assert {:ok, %{result: eth_price}} = result
      assert eth_price.eth_btc == "unavailable"
      assert eth_price.eth_btc_timestamp == "unavailable"
      assert eth_price.eth_usd == "unavailable"
      assert eth_price.eth_usd_timestamp == "unavailable"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid chain ID"
      }

      # Call the function
      result = EthPrice.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end
  end
end
