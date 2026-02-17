defmodule Lux.Lenses.Etherscan.MultiChainAggregatorLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Etherscan.Base

  test "adds api key to lens parameters" do
    lens = %{params: %{}}
    expected_params = Map.put(lens.params, :apikey, Lux.Config.etherscan_api_key())
    assert Base.add_api_key(lens).params == expected_params
  end

  test "processes successful API response" do
    response = %{"status" => "1", "result" => "some_result"}
    assert Base.process_response(response) == {:ok, %{result: "some_result"}}
  end

  test "processes error API response" do
    response = %{"error" => %{"message" => "some_error"}}
    assert Base.process_response(response) == {:error, response["error"]}
  end

  test "processes Pro API key error response" do
    response = %{
      "status" => "0",
      "result" => "Pro subscription required"
    }
    expected_result = "This endpoint requires an Etherscan Pro API key."
    assert Base.process_response(response) == {:error, %{message: response["message"], result: expected_result}}
  end

  test "processes unexpected response format" do
    response = %{"unexpected_key" => "some_value"}
    assert Base.process_response(response) == {:error, "Unexpected response format: #{inspect(response)}"}
  end

  test "validates Ethereum address" do
    valid_address = "0x1234567890abcdef1234567890abcdef12345678"
    invalid_address = "invalid_address"

    assert Base.validate_eth_address(valid_address) == {:ok, valid_address}
    assert Base.validate_eth_address(invalid_address) == {:error, "Invalid Ethereum address format: #{invalid_address}"}
  end

  test "validates transaction hash" do
    valid_hash = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    invalid_hash = "invalid_hash"

    assert Base.validate_tx_hash(valid_hash) == {:ok, valid_hash}
    assert Base.validate_tx_hash(invalid_hash) == {:error, "Invalid transaction hash format: #{invalid_hash}"}
  end

  test "validates block number" do
    valid_block_number = 123456
    invalid_block_number = -1

    assert Base.validate_block(valid_block_number) == {:ok, "123456"}
    assert Base.validate_block(invalid_block_number) == {:error, "Invalid block number format: #{invalid_block_number}"}
  end

  test "validates block tag" do
    valid_block_tag = "latest"
    invalid_block_tag = "invalid_tag"

    assert Base.validate_block(valid_block_tag) == {:ok, "latest"}
    assert Base.validate_block(invalid_block_tag) == {:error, "Invalid block tag format: #{invalid_block_tag}"}
  end
end

test "multi-chain query with successful responses" do
    response1 = %{"status" => "1", "result" => "some_result_1"}
    response2 = %{"status" => "1", "result" => "some_result_2"}
    expected_result = {:ok, %{results: ["some_result_1", "some_result_2"]}}
    assert Base.multi_chain_query([response1, response2]) == expected_result
  end

  test "multi-chain query with error responses" do
    response1 = %{"status" => "0", "result" => "Pro subscription required"}
    response2 = %{"error" => %{"message" => "some_error"}}
    expected_result = {:error, %{errors: ["This endpoint requires an Etherscan Pro API key.", "some_error"]}}
    assert Base.multi_chain_query([response1, response2]) == expected_result
  end

  test "multi-chain query with mixed responses" do
    response1 = %{"status" => "1", "result" => "some_result_1"}
    response2 = %{"error" => %{"message" => "some_error"}}
    expected_result = {:ok, %{results: ["some_result_1"], errors: ["some_error"]}}
    assert Base.multi_chain_query([response1, response2]) == expected_result
  end