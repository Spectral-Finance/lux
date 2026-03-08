defmodule Lux.Prisms.Web3.CreateWallet do
  @moduledoc """
  Prism for creating or importing Ethereum wallets.
  """

  use Lux.Prism,
    name: "Web3 Create Wallet",
    description: "Create a new Ethereum wallet or import from private key",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["create", "import"], description: "Create new or import existing"},
        chain_id: %{type: :integer, description: "Chain ID (default: 1 for Ethereum)"},
        private_key: %{type: :string, description: "Private key hex for import action"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string},
        chain_id: %{type: :integer}
      }
    }

  alias Lux.Integrations.Web3.Wallet

  @impl true
  def handler(params, _opts) do
    action = params[:action] || params["action"]
    chain_id = params[:chain_id] || params["chain_id"] || 1

    case action do
      "create" ->
        case Wallet.create(chain_id: chain_id) do
          {:ok, wallet} ->
            {:ok, %{
              address: wallet.address,
              chain_id: wallet.chain_id,
              private_key: Wallet.private_key_hex(wallet)
            }}

          error ->
            error
        end

      "import" ->
        pk = params[:private_key] || params["private_key"]

        if is_nil(pk) do
          {:error, "private_key required for import"}
        else
          case Wallet.from_private_key(pk, chain_id: chain_id) do
            {:ok, wallet} ->
              {:ok, %{address: wallet.address, chain_id: wallet.chain_id}}

            error ->
              error
          end
        end

      _ ->
        {:error, "Invalid action: #{action}"}
    end
  end
end
