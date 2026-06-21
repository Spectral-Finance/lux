defmodule Lux.Integrations.SushiSwap.Factory do
  @moduledoc """
  Ethers contract definition for SushiSwap V2 Factory.
  """

  use Ethers.Contract, abi: [
    %{
      "inputs" => [
        %{"internalType" => "address", "name" => "tokenA", "type" => "address"},
        %{"internalType" => "address", "name" => "tokenB", "type" => "address"}
      ],
      "name" => "getPair",
      "outputs" => [%{"internalType" => "address", "name" => "pair", "type" => "address"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]
end
