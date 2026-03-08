defmodule Lux.Prisms.Web3.SignTransaction do
  @moduledoc """
  Prism for building and signing Ethereum transactions (EIP-1559).
  """

  use Lux.Prism,
    name: "Web3 Sign Transaction",
    description: "Build and sign an EIP-1559 Ethereum transaction",
    input_schema: %{
      type: :object,
      properties: %{
        private_key: %{type: :string, description: "Signer's private key hex"},
        to: %{type: :string, description: "Recipient address"},
        value: %{type: :integer, description: "Value in wei"},
        data: %{type: :string, description: "Transaction data (hex)"},
        nonce: %{type: :integer, description: "Transaction nonce"},
        chain_id: %{type: :integer, description: "Chain ID"},
        gas_limit: %{type: :integer, description: "Gas limit"},
        max_fee_per_gas: %{type: :integer, description: "Max fee per gas (wei)"},
        max_priority_fee_per_gas: %{type: :integer, description: "Max priority fee (wei)"}
      },
      required: ["private_key", "to"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        signed_tx: %{type: :string, description: "Signed raw transaction hex"},
        from: %{type: :string, description: "Signer address"},
        to: %{type: :string},
        value: %{type: :integer}
      }
    }

  alias Lux.Integrations.Web3.Wallet

  @impl true
  def handler(params, _opts) do
    pk = params[:private_key] || params["private_key"]

    case Wallet.from_private_key(pk) do
      {:ok, wallet} ->
        tx = Wallet.build_transaction(%{
          to: params[:to] || params["to"],
          value: params[:value] || params["value"] || 0,
          data: params[:data] || params["data"] || "",
          nonce: params[:nonce] || params["nonce"] || 0,
          chain_id: params[:chain_id] || params["chain_id"] || wallet.chain_id,
          gas_limit: params[:gas_limit] || params["gas_limit"] || 21_000,
          max_fee_per_gas: params[:max_fee_per_gas] || params["max_fee_per_gas"] || 30_000_000_000,
          max_priority_fee_per_gas: params[:max_priority_fee_per_gas] || params["max_priority_fee_per_gas"] || 1_500_000_000
        })

        case Wallet.sign_transaction(wallet, tx) do
          {:ok, signed_tx} ->
            {:ok, %{
              signed_tx: signed_tx,
              from: wallet.address,
              to: tx.to,
              value: tx.value
            }}

          error ->
            error
        end

      error ->
        error
    end
  end
end
