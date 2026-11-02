defmodule Lux.Prisms.Web3.Auth.VerifySignaturePrism do
  @moduledoc """
  Verifies Web3 cryptographic signatures supporting personal_sign, EIP-712, ERC-1271, and threshold multisig.
  """

  use Lux.Prism,
    name: "Verify Web3 Signature",
    description: "Validates cryptographic signatures for personal_sign, EIP-712, ERC-1271, and multi-sig",
    input_schema: %{
      type: :object,
      properties: %{
        type: %{
          type: :string,
          enum: ["personal_sign", "eip712", "erc1271", "multisig"],
          default: "personal_sign",
          description: "Type of signature verification to execute"
        },
        address: %{type: :string, description: "Expected signer address or contract address"},
        message: %{type: :string, description: "Raw message for personal_sign"},
        signature: %{type: :string, description: "Hex signature string (0x...)"},
        typed_data: %{type: :object, description: "EIP-712 structured data map"},
        hash: %{type: :string, description: "32-byte message hash (for ERC-1271 or multisig)"},
        signatures: %{type: :array, items: %{type: :string}, description: "List of signatures for multisig"},
        owners: %{type: :array, items: %{type: :string}, description: "Authorized owners for multisig"},
        threshold: %{type: :integer, description: "Threshold of signatures required for multisig"}
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean},
        signature_type: %{type: :string},
        address: %{type: :string}
      },
      required: ["valid", "signature_type", "address"]
    }

  alias Lux.Web3.Auth.SignatureVerifier

  def handler(input, _ctx) do
    raw_type = Map.get(input, :type) || Map.get(input, "type", "personal_sign")
    sig_type = parse_type(raw_type)
    address = Map.get(input, :address) || Map.get(input, "address")

    result =
      case sig_type do
        :personal_sign ->
          message = Map.get(input, :message) || Map.get(input, "message", "")
          signature = Map.get(input, :signature) || Map.get(input, "signature", "")
          SignatureVerifier.verify_personal_sign(message, signature, address)

        :eip712 ->
          typed_data = Map.get(input, :typed_data) || Map.get(input, "typed_data", %{})
          signature = Map.get(input, :signature) || Map.get(input, "signature", "")
          SignatureVerifier.verify_eip712(typed_data, signature, address)

        :erc1271 ->
          hash = Map.get(input, :hash) || Map.get(input, "hash", "")
          signature = Map.get(input, :signature) || Map.get(input, "signature", "")
          SignatureVerifier.verify_erc1271(address, hash, signature)

        :multisig ->
          moh = Map.get(input, :hash) || Map.get(input, "hash") || Map.get(input, :message) || Map.get(input, "message", "")
          signatures = Map.get(input, :signatures) || Map.get(input, "signatures", [])
          threshold = Map.get(input, :threshold) || Map.get(input, "threshold", 1)
          owners = Map.get(input, :owners) || Map.get(input, "owners", [address])
          SignatureVerifier.verify_multisig(moh, signatures, threshold, owners)
      end

    case result do
      {:ok, is_valid} ->
        {:ok,
         %{
           valid: is_valid,
           signature_type: to_string(sig_type),
           address: address
         }}

      {:error, reason} ->
        {:error, "Signature verification failed: #{inspect(reason)}"}
    end
  end

  defp parse_type(val) when is_atom(val), do: val

  defp parse_type(val) when is_binary(val) do
    case String.downcase(val) do
      "eip712" -> :eip712
      "erc1271" -> :erc1271
      "multisig" -> :multisig
      _ -> :personal_sign
    end
  end

  defp parse_type(_), do: :personal_sign
end
