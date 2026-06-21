defmodule Lux.Integrations.Curve.Pool do
  @moduledoc """
  Ethers contract definition for a Curve Finance StableSwap Pool.
  """

  use Ethers.Contract, abi: [
    %{
      "inputs" => [
        %{"internalType" => "int128", "name" => "i", "type" => "int128"},
        %{"internalType" => "int128", "name" => "j", "type" => "int128"},
        %{"internalType" => "uint256", "name" => "dx", "type" => "uint256"},
        %{"internalType" => "uint256", "name" => "min_dy", "type" => "uint256"}
      ],
      "name" => "exchange",
      "outputs" => [%{"internalType" => "uint256", "name" => "", "type" => "uint256"}],
      "stateMutability" => "nonpayable",
      "type" => "function"
    },
    %{
      "inputs" => [
        %{"internalType" => "int128", "name" => "i", "type" => "int128"},
        %{"internalType" => "int128", "name" => "j", "type" => "int128"},
        %{"internalType" => "uint256", "name" => "dx", "type" => "uint256"}
      ],
      "name" => "get_dy",
      "outputs" => [%{"internalType" => "uint256", "name" => "", "type" => "uint256"}],
      "stateMutability" => "view",
      "type" => "function"
    },
    %{
      "inputs" => [
        %{"internalType" => "uint256", "name" => "i", "type" => "uint256"}
      ],
      "name" => "balances",
      "outputs" => [%{"internalType" => "uint256", "name" => "", "type" => "uint256"}],
      "stateMutability" => "view",
      "type" => "function"
    }
  ]
end
