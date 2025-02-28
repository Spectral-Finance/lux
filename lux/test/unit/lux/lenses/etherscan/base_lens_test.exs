defmodule Lux.Lenses.Etherscan.BaseLensTest do
  use ExUnit.Case, async: true
  
  alias Lux.Lenses.Etherscan.BaseLens
  
  describe "process_response/1" do
    test "processes successful response" do
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [%{"key" => "value"}]
      }
      
      assert {:ok, %{result: [%{"key" => "value"}]}} = BaseLens.process_response(response)
    end
    
    test "processes error response" do
      response = %{
        "status" => "0",
        "message" => "Error message",
        "result" => []
      }
      
      assert {:error, %{message: "Error message", result: []}} = BaseLens.process_response(response)
    end
    
    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}
      
      assert {:error, _} = BaseLens.process_response(response)
    end
  end
  
  describe "validate_eth_address/1" do
    test "validates correct Ethereum address" do
      address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      
      assert {:ok, ^address} = BaseLens.validate_eth_address(address)
    end
    
    test "rejects invalid Ethereum address" do
      address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44"
      
      assert {:error, _} = BaseLens.validate_eth_address(address)
    end
  end
  
  describe "validate_tx_hash/1" do
    test "validates correct transaction hash" do
      hash = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      
      assert {:ok, ^hash} = BaseLens.validate_tx_hash(hash)
    end
    
    test "rejects invalid transaction hash" do
      hash = "0x1234567890abcdef"
      
      assert {:error, _} = BaseLens.validate_tx_hash(hash)
    end
  end
  
  describe "validate_block/1" do
    test "validates block number as string" do
      block = "12345"
      
      assert {:ok, ^block} = BaseLens.validate_block(block)
    end
    
    test "validates block number as integer" do
      block = 12345
      
      assert {:ok, "12345"} = BaseLens.validate_block(block)
    end
    
    test "validates block tag" do
      for tag <- ["latest", "pending", "earliest"] do
        assert {:ok, ^tag} = BaseLens.validate_block(tag)
      end
    end
    
    test "rejects invalid block format" do
      block = "invalid"
      
      assert {:error, _} = BaseLens.validate_block(block)
    end
    
    test "rejects negative block number" do
      block = -1
      
      assert {:error, _} = BaseLens.validate_block(block)
    end
  end
end 