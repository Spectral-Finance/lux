defmodule Lux.Prisms.Web3Auth.RolePrism do
  @moduledoc """
  A prism that checks if an address has a specific role using a smart contract.
  Assumes an AccessControl (OpenZeppelin) interface `hasRole(bytes32,address)`.
  """
  use Lux.Prism,
    name: "Role Verifier",
    description: "Verifies if an address has a specific role on a contract",
    input_schema: %{
      type: :object,
      properties: %{
        contract_address: %{type: :string, description: "The smart contract address"},
        account: %{type: :string, description: "The address to check"},
        role: %{type: :string, description: "The role identifier (e.g., 'ADMIN', or bytes32)"},
        rpc_url: %{type: :string, description: "RPC URL to query"}
      },
      required: ["contract_address", "account", "role"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        has_role: %{type: :boolean, description: "Whether the address has the role"},
        error: %{type: :string, description: "Error message if failed"}
      },
      required: ["has_role"]
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    contract_address = Map.get(input, :contract_address) || Map.get(input, "contract_address")
    account = Map.get(input, :account) || Map.get(input, "account")
    role = Map.get(input, :role) || Map.get(input, "role")
    rpc_url = Map.get(input, :rpc_url) || Map.get(input, "rpc_url") || Lux.Integrations.Web3Auth.default_rpc_url()

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- check_role(contract_address, account, role, rpc_url) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} -> {:error, "Failed to import Web3: #{error}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_role(contract_address, account, role, rpc_url) do
    result =
      python variables: %{contract: contract_address, account: account, role: role, rpc_url: rpc_url} do
        ~PY"""
        def check(contract, account, role, rpc):
            from web3 import Web3
            try:
                w3 = Web3(Web3.HTTPProvider(rpc))
                ABI = [{"inputs":[{"internalType":"bytes32","name":"role","type":"bytes32"},{"internalType":"address","name":"account","type":"address"}],"name":"hasRole","outputs":[{"internalType":"bool","name":"","type":"bool"}],"stateMutability":"view","type":"function"}]
                contract_obj = w3.eth.contract(address=w3.to_checksum_address(contract), abi=ABI)
                
                # If role is not a hex string of 32 bytes, hash it
                if role.startswith("0x") and len(role) == 66:
                    role_bytes = w3.to_bytes(hexstr=role)
                else:
                    role_bytes = Web3.keccak(text=role)
                    
                has_role = contract_obj.functions.hasRole(role_bytes, w3.to_checksum_address(account)).call()
                return {"has_role": has_role}
            except Exception as e:
                return {"has_role": False, "error": str(e)}
        result = check(contract, account, role, rpc_url)
        result
        """
      end
    {:ok, result}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
