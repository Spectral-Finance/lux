defmodule Lux.Prisms.Web3Auth.MultiSigPrism do
  @moduledoc """
  A prism that verifies an EIP-1271 multi-signature or smart contract signature.
  """
  use Lux.Prism,
    name: "Multi-Signature Verifier",
    description: "Verifies EIP-1271 smart contract signatures",
    input_schema: %{
      type: :object,
      properties: %{
        contract_address: %{type: :string, description: "The smart contract wallet address"},
        message: %{type: :string, description: "The signed message"},
        signature: %{type: :string, description: "The signature bytes"},
        rpc_url: %{type: :string, description: "RPC URL to query"}
      },
      required: ["contract_address", "message", "signature"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean, description: "Whether the signature is valid according to EIP-1271"},
        error: %{type: :string, description: "Error message if failed"}
      },
      required: ["valid"]
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    contract_address = Map.get(input, :contract_address) || Map.get(input, "contract_address")
    message = Map.get(input, :message) || Map.get(input, "message")
    signature = Map.get(input, :signature) || Map.get(input, "signature")
    rpc_url = Map.get(input, :rpc_url) || Map.get(input, "rpc_url") || Lux.Integrations.Web3Auth.default_rpc_url()

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- verify_1271(contract_address, message, signature, rpc_url) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} -> {:error, "Failed to import Web3: #{error}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp verify_1271(contract_address, message, signature, rpc_url) do
    result =
      python variables: %{contract: contract_address, message: message, signature: signature, rpc_url: rpc_url} do
        ~PY"""
        def verify_eip1271(contract, message, signature, rpc):
            from web3 import Web3
            from eth_account.messages import encode_defunct
            try:
                w3 = Web3(Web3.HTTPProvider(rpc))
                signable_message = encode_defunct(text=message)
                # EIP-1271 magic value is 0x1626ba7e
                ABI = [{"constant":True,"inputs":[{"name":"_hash","type":"bytes32"},{"name":"_signature","type":"bytes"}],"name":"isValidSignature","outputs":[{"name":"magicValue","type":"bytes4"}],"payable":False,"stateMutability":"view","type":"function"}]
                contract_obj = w3.eth.contract(address=w3.to_checksum_address(contract), abi=ABI)
                
                from eth_account._utils.signing import hash_of_defunct_message
                msg_hash = hash_of_defunct_message(signable_message)
                
                magic_value = contract_obj.functions.isValidSignature(msg_hash, signature).call()
                if magic_value.hex() == '0x1626ba7e':
                    return {"valid": True}
                else:
                    return {"valid": False, "error": "Invalid magic value"}
            except Exception as e:
                return {"valid": False, "error": str(e)}
        result = verify_eip1271(contract, message, signature, rpc_url)
        result
        """
      end
    {:ok, result}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
