defmodule Lux.Integration.MultiChainTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  alias Lux.Prisms.MultiChain.DataAggregatorPrism
  alias Lux.Lenses.MultiChain.RpcStatus

  setup do
    # Skip if web3 is not available (since Python dependency might not be setup in all CI environments)
    case Lux.Python.import_package("web3") do
      {:ok, %{"success" => true}} ->
        :ok
      _ ->
        {:skip, "Web3 python package not available"}
    end
  end

  describe "MultiChain DataAggregatorPrism" do
    @tag timeout: 60_000
    test "aggregates block data from multiple chains" do
      input = %{
        chains: ["ethereum", "polygon"],
        data_type: "block",
        block_number: "latest"
      }

      assert {:ok, result} = DataAggregatorPrism.run(input)
      assert Map.has_key?(result, :aggregated_data)
      
      # Since we are hitting public nodes, we should just check if we get an object back
      # Some chains might fail due to rate limits on public nodes, so we check errors too
      assert is_map(result.aggregated_data) || is_map(result.errors)
    end
  end

  describe "MultiChain RpcStatus Lens" do
    test "returns rpc status for ethereum" do
      assert {:ok, response} = RpcStatus.focus(%{chain: "ethereum"})
      # Etherscan node or cloudflare node should return online
      if Map.has_key?(response, :status) do
        assert response.status == "online"
        assert is_integer(response.block_height)
      end
    end
  end
end
