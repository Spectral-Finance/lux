defmodule Lux.Prisms.Web3.WalletImport do
  @moduledoc """
  A prism to import or derive a Web3 wallet.
  """
  use Lux.Prism,
    name: "Web3 Wallet Import",
    description: "Imports a raw private key or derives an HD wallet for transaction signing.",
    input_schema: %{
      type: :object,
      properties: %{
        name: %{
          type: :string,
          description: "Internal name/alias for the wallet."
        },
        private_key: %{
          type: :string,
          description: "Raw private key (if importing directly)."
        },
        mnemonic: %{
          type: :string,
          description: "BIP39 Mnemonic (if deriving HD wallet)."
        },
        path: %{
          type: :string,
          description: "HD derivation path (e.g., m/44'/60'/0'/0/0)."
        }
      },
      required: ["name"]
    }

  alias Lux.Integrations.Web3.WalletManager

  def handler(params, _context) do
    name = params.name
    
    cond do
      Map.has_key?(params, :private_key) ->
        case WalletManager.import_wallet(name, params.private_key) do
          {:ok, address} -> {:ok, %{status: "imported", address: address}}
          error -> {:error, "Failed to import: #{inspect(error)}"}
        end
        
      Map.has_key?(params, :mnemonic) ->
        path = Map.get(params, :path, "m/44'/60'/0'/0/0")
        case WalletManager.derive_hd_account(name, params.mnemonic, path) do
          {:ok, address} -> {:ok, %{status: "derived", address: address}}
          error -> {:error, "Failed to derive: #{inspect(error)}"}
        end
        
      true ->
        {:error, "Must provide either private_key or mnemonic."}
    end
  end
end
