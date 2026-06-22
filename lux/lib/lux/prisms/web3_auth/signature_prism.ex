defmodule Lux.Prisms.Web3Auth.SignaturePrism do
  @moduledoc """
  A prism that verifies an EIP-191 or generic Ethereum signature.
  """
  use Lux.Prism,
    name: "Signature Verifier",
    description: "Verifies generic Ethereum signatures",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :string, description: "The signed message"},
        signature: %{type: :string, description: "The signature"},
        expected_address: %{type: :string, description: "The expected signer address"}
      },
      required: ["message", "signature", "expected_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean, description: "Whether the signature is valid"},
        recovered_address: %{type: :string, description: "The address recovered"},
        error: %{type: :string, description: "Error message if failed"}
      },
      required: ["valid"]
    }

  import Lux.Python
  require Lux.Python

  def handler(%{message: message, signature: signature, expected_address: expected_address}, _ctx) do
    with {:ok, %{"success" => true}} <- Lux.Python.import_package("web3"),
         {:ok, result} <- verify_sig(message, signature, expected_address) do
      {:ok, atomize_keys(result)}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import Web3: #{error}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_sig(message, signature, expected_address) do
    result =
      python variables: %{message: message, signature: signature, expected_address: expected_address} do
        ~PY"""
        def verify_generic(message, signature, expected):
            from web3 import Web3
            from eth_account.messages import encode_defunct
            try:
                w3 = Web3()
                signable_message = encode_defunct(text=message)
                recovered = w3.eth.account.recover_message(signable_message, signature=signature)
                valid = recovered.lower() == expected.lower()
                if valid:
                    return {
                        "valid": True,
                        "recovered_address": recovered
                    }
                else:
                    return {
                        "valid": False,
                        "recovered_address": recovered,
                        "error": "Signature mismatch"
                    }
            except Exception as e:
                return {"valid": False, "error": str(e)}

        result = verify_generic(message, signature, expected_address)
        result
        """
      end
    {:ok, result}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end
end
