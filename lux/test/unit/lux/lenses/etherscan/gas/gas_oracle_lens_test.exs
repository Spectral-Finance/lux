defmodule Lux.Lenses.Etherscan.GasOracleLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.GasOracle

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
        assert query["module"] == "gastracker"
        assert query["action"] == "gasoracle"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "LastBlock" => "16916759",
            "SafeGasPrice" => "20",
            "ProposeGasPrice" => "22",
            "FastGasPrice" => "25",
            "suggestBaseFee" => "19.123456789",
            "gasUsedRatio" => "0.374502284698551,0.5519324043028,0.999999999999999"
          }
        })
      end)

      # Call the lens
      result = GasOracle.focus(params)

      # Verify the result
      assert {:ok, %{result: gas_oracle, gas_oracle: gas_oracle}} = result
      assert gas_oracle.safe_gas_price == 20.0
      assert gas_oracle.propose_gas_price == 22.0
      assert gas_oracle.fast_gas_price == 25.0
      assert gas_oracle.suggest_base_fee == 19.123456789
      assert gas_oracle.gas_used_ratio == "0.374502284698551,0.5519324043028,0.999999999999999"
      assert gas_oracle.last_block == 16_916_759
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "gastracker"
        assert query["action"] == "gasoracle"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "LastBlock" => "16916759",
            "SafeGasPrice" => "20",
            "ProposeGasPrice" => "22",
            "FastGasPrice" => "25",
            "suggestBaseFee" => "19.123456789",
            "gasUsedRatio" => "0.374502284698551,0.5519324043028,0.999999999999999"
          }
        })
      end)

      # Call the lens
      result = GasOracle.focus(params)

      # Verify the result
      assert {:ok, %{result: gas_oracle}} = result
      assert gas_oracle.safe_gas_price == 20.0
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
      result = GasOracle.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a Pro API key error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "This endpoint requires a Pro subscription"
        })
      end)

      # Call the lens
      result = GasOracle.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        chainid: 1
      }

      # Call the function
      result = GasOracle.before_focus(params)

      # Verify the result
      assert result.module == "gastracker"
      assert result.action == "gasoracle"
      assert result.chainid == 1
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Call the function
      result = GasOracle.before_focus(params)

      # Verify the result
      assert result.module == "gastracker"
      assert result.action == "gasoracle"
    end
  end

  describe "after_focus/1" do
    test "processes successful response and converts types" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "LastBlock" => "16916759",
          "SafeGasPrice" => "20",
          "ProposeGasPrice" => "22",
          "FastGasPrice" => "25",
          "suggestBaseFee" => "19.123456789",
          "gasUsedRatio" => "0.374502284698551,0.5519324043028,0.999999999999999"
        }
      }

      # Call the function
      result = GasOracle.after_focus(response)

      # Verify the result
      assert {:ok, %{result: gas_oracle, gas_oracle: gas_oracle}} = result
      assert gas_oracle.safe_gas_price == 20.0
      assert gas_oracle.propose_gas_price == 22.0
      assert gas_oracle.fast_gas_price == 25.0
      assert gas_oracle.suggest_base_fee == 19.123456789
      assert gas_oracle.gas_used_ratio == "0.374502284698551,0.5519324043028,0.999999999999999"
      assert gas_oracle.last_block == 16_916_759
    end

    test "handles non-numeric values" do
      # Create a mock response with non-numeric values
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "LastBlock" => "unavailable",
          "SafeGasPrice" => "unavailable",
          "ProposeGasPrice" => "unavailable",
          "FastGasPrice" => "unavailable",
          "suggestBaseFee" => "unavailable",
          "gasUsedRatio" => "unavailable"
        }
      }

      # Call the function
      result = GasOracle.after_focus(response)

      # Verify the result
      assert {:ok, %{result: gas_oracle}} = result
      assert gas_oracle.safe_gas_price == "unavailable"
      assert gas_oracle.propose_gas_price == "unavailable"
      assert gas_oracle.fast_gas_price == "unavailable"
      assert gas_oracle.suggest_base_fee == "unavailable"
      assert gas_oracle.gas_used_ratio == "unavailable"
      assert gas_oracle.last_block == "unavailable"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid chain ID"
      }

      # Call the function
      result = GasOracle.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end
  end
end
