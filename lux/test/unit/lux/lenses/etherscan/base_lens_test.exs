defmodule Lux.Lenses.Etherscan.BaseLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.Base

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "add_api_key/1" do
    test "adds the API key to the lens parameters" do
      # Create a mock lens
      lens = %{
        params: %{module: "account", action: "balance"},
        headers: [{"content-type", "application/json"}]
      }

      # Call the function
      result = Base.add_api_key(lens)

      # Assert that the API key was added to the params
      assert result.params.apikey == "TEST_API_KEY"
      assert Map.has_key?(result.params, :module)
      assert Map.has_key?(result.params, :action)
    end
  end

  describe "process_response/1" do
    test "processes a successful response" do
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "123456789"
      }

      assert {:ok, %{result: "123456789"}} = Base.process_response(response)
    end

    test "processes an error response" do
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      assert {:error, %{message: "Error", result: "Invalid address format"}} = Base.process_response(response)
    end

    test "handles Pro API key errors" do
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "This endpoint requires a Pro subscription"
      }

      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = Base.process_response(response)
    end

    test "handles error object" do
      response = %{
        "error" => "API rate limit exceeded"
      }

      assert {:error, "API rate limit exceeded"} = Base.process_response(response)
    end

    test "handles unexpected response format" do
      response = %{
        "unexpected" => "format"
      }

      assert {:error, "Unexpected response format: " <> _} = Base.process_response(response)
    end
  end

  describe "validate_eth_address/1" do
    test "validates a valid Ethereum address" do
      address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      assert {:ok, ^address} = Base.validate_eth_address(address)
    end

    test "rejects an invalid Ethereum address" do
      address = "0xinvalid"
      assert {:error, "Invalid Ethereum address format: " <> _} = Base.validate_eth_address(address)
    end
  end

  describe "validate_tx_hash/1" do
    test "validates a valid transaction hash" do
      hash = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      assert {:ok, ^hash} = Base.validate_tx_hash(hash)
    end

    test "rejects an invalid transaction hash" do
      hash = "0xinvalid"
      assert {:error, "Invalid transaction hash format: " <> _} = Base.validate_tx_hash(hash)
    end
  end

  describe "validate_block/1" do
    test "validates a valid block number as integer" do
      assert {:ok, "123"} = Base.validate_block(123)
    end

    test "validates a valid block number as string" do
      assert {:ok, "123"} = Base.validate_block("123")
    end

    test "validates a valid block tag" do
      assert {:ok, "latest"} = Base.validate_block("latest")
      assert {:ok, "pending"} = Base.validate_block("pending")
      assert {:ok, "earliest"} = Base.validate_block("earliest")
    end

    test "rejects an invalid block format" do
      assert {:error, "Invalid block format: " <> _} = Base.validate_block("invalid")
      assert {:error, "Invalid block format: " <> _} = Base.validate_block(:invalid)
    end
  end

  describe "check_pro_endpoint/2" do
    test "allows non-pro endpoints" do
      assert {:ok, true} = Base.check_pro_endpoint("account", "balance")
    end

    test "checks pro endpoints with regular API key" do
      assert {:error, "This endpoint requires an Etherscan Pro API key."} = Base.check_pro_endpoint("account", "balancehistory")
    end

    test "allows pro endpoints with pro API key" do
      # Set up pro API key
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: true
      ])

      assert {:ok, true} = Base.check_pro_endpoint("account", "balancehistory")
    end
  end
end
