defmodule Lux.Prisms.Web3.Auth.VerifySignaturePrism do
  @moduledoc """
  A prism for verifying Ethereum signatures.

  Supports verification of:
  - EIP-191 personal_sign messages
  - EIP-712 typed data signatures

  ## Examples

      iex> VerifySignaturePrism.handler(%{
      ...>   message: "Hello, world!",
      ...>   signature: "0x...",
      ...>   address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
      ...>   type: "personal_sign"
      ...> }, %{})
      {:ok, %{valid: true, recovered_address: "0x71c7..."}}
  """

  use Lux.Prism,
    name: "Verify Ethereum Signature",
    description: "Verifies an Ethereum signature (personal_sign or EIP-712)",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :string,
          description: "The message or typed data hash that was signed"
        },
        signature: %{
          type: :string,
          description: "The hex-encoded signature"
        },
        address: %{
          type: :string,
          description: "The expected signer's Ethereum address"
        },
        type: %{
          type: :string,
          description: "Signature type: 'personal_sign' (default) or 'typed_data'",
          enum: ["personal_sign", "typed_data"]
        }
      },
      required: ["message", "signature", "address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        valid: %{type: :boolean, description: "Whether the signature is valid"},
        recovered_address: %{type: :string, description: "The recovered signer address"}
      },
      required: ["valid"]
    }

  alias Lux.Web3.Auth.SignatureVerifier

  require Logger

  @impl true
  def handler(%{message: message, signature: signature, address: address} = input, _ctx) do
    sig_type = Map.get(input, :type, "personal_sign")

    Logger.info("Verifying #{sig_type} signature for #{address}")

    result =
      case sig_type do
        "typed_data" ->
          SignatureVerifier.verify_typed_data(message, signature, address)

        _personal_sign ->
          SignatureVerifier.verify_signature(message, signature, address)
      end

    case result do
      {:ok, valid} ->
        recovered =
          case SignatureVerifier.recover_address(message, signature) do
            {:ok, addr} -> addr
            _ -> nil
          end

        {:ok, %{valid: valid, recovered_address: recovered}}

      {:error, reason} ->
        {:ok, %{valid: false, error: reason}}
    end
  end

  def handler(_params, _ctx) do
    {:error, "Missing required parameters: message, signature, address"}
  end
end
