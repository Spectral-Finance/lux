defmodule Lux.Prisms.Web3Auth.SIWEPrism do
  @moduledoc """
  A prism that verifies an EIP-4361 (Sign-In with Ethereum) message and signature.

  ## Examples

      iex> Lux.Prisms.Web3Auth.SIWEPrism.run(%{
      ...>   message: "example.com wants you to sign in...",
      ...>   signature: "0x..."
      ...> })
      {:ok, %{
        valid: true,
        address: "0xd3cda913deb6f67967b99d67acdfa1712c293601",
        domain: "example.com"
      }}
  """

  use Lux.Prism,
    name: "SIWE Verifier",
    description: "Verifies EIP-4361 Sign-In with Ethereum messages and signatures",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :string,
          description: "The EIP-4361 message string"
        },
        signature: %{
          type: :string,
          description: "The signature of the message"
        }
      },
      required: ["message", "signature"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{
          type: :boolean,
          description: "Whether the signature is valid"
        },
        address: %{
          type: :string,
          description: "The address recovered from the signature"
        },
        domain: %{
          type: :string,
          description: "The domain specified in the SIWE message"
        },
        error: %{
          type: :string,
          description: "Error message if validation failed"
        }
      },
      required: ["valid"]
    }

  import Lux.Python
  require Lux.Python

  def handler(%{message: message, signature: signature}, _ctx) do
    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- verify_siwe(message, signature) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import Web3: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_siwe(message, signature) do
    result =
      python variables: %{message: message, signature: signature} do
        ~PY"""
        def verify_eip4361(message, signature):
            from web3 import Web3
            from eth_account.messages import encode_defunct
            import re
            
            try:
                w3 = Web3()
                
                # Basic SIWE regex parsing to extract domain and address
                # Format: "domain wants you to sign in with your Ethereum account:\naddress..."
                domain_match = re.search(r"^([^ ]+) wants you to sign in", message)
                address_match = re.search(r"Ethereum account:\n(0x[a-fA-F0-9]{40})", message)
                
                if not domain_match or not address_match:
                    return {
                        "valid": False,
                        "error": "Invalid EIP-4361 message format"
                    }
                    
                domain = domain_match.group(1)
                expected_address = address_match.group(1)
                
                # Verify signature
                signable_message = encode_defunct(text=message)
                recovered_address = w3.eth.account.recover_message(signable_message, signature=signature)
                
                if recovered_address.lower() == expected_address.lower():
                    return {
                        "valid": True,
                        "address": expected_address,
                        "domain": domain
                    }
                else:
                    return {
                        "valid": False,
                        "address": recovered_address,
                        "domain": domain,
                        "error": "Signature does not match expected address"
                    }
            except Exception as e:
                return {
                    "valid": False,
                    "error": f"Failed to verify signature: {str(e)}"
                }

        result = verify_eip4361(message, signature)
        result
        """
      end

    if Map.get(result, "valid") == false and Map.has_key?(result, "error") do
      {:ok, result}
    else
      {:ok, result}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
