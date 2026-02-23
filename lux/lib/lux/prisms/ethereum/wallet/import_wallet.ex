defmodule Lux.Prisms.Ethereum.Wallet.ImportWallet do
  @moduledoc """
  A prism for importing existing Ethereum wallets from a private key or mnemonic.

  Supports:
  - Import from private key (hex string with or without 0x prefix)
  - Import from BIP-39 mnemonic phrase with custom HD derivation path

  ## Examples

      iex> ImportWallet.handler(%{
      ...>   source: "private_key",
      ...>   value: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", source: "private_key"}}

      iex> ImportWallet.handler(%{
      ...>   source: "mnemonic",
      ...>   value: "test test test test test test test test test test test junk",
      ...>   account_index: 0
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{address: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", source: "mnemonic"}}
  """

  use Lux.Prism,
    name: "Import Ethereum Wallet",
    description: "Imports an Ethereum wallet from a private key or mnemonic phrase",
    input_schema: %{
      type: :object,
      properties: %{
        source: %{
          type: :string,
          description: "Import source type",
          enum: ["private_key", "mnemonic"]
        },
        value: %{
          type: :string,
          description: "The private key (hex) or mnemonic phrase to import"
        },
        account_index: %{
          type: :integer,
          description: "HD wallet account index when importing from mnemonic (default: 0)",
          minimum: 0,
          default: 0
        }
      },
      required: ["source", "value"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Checksummed Ethereum address of the imported wallet"
        },
        source: %{
          type: :string,
          description: "The import source used"
        }
      },
      required: ["address", "source"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  def handler(input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"

    with {:ok, source} <- validate_source(input),
         {:ok, value} <- validate_value(input),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("eth_account"),
         {:ok, result} <- derive_address(source, value, Map.get(input, :account_index, 0)) do
      Logger.info("Agent #{agent_name} imported wallet #{result["address"]} from #{source}")
      {:ok, %{address: result["address"], source: source}}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Failed to import eth_account: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_source(%{source: source}) when source in ["private_key", "mnemonic"],
    do: {:ok, source}
  defp validate_source(_), do: {:error, "source must be 'private_key' or 'mnemonic'"}

  defp validate_value(%{value: value}) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}
  defp validate_value(_), do: {:error, "value is required and must be non-empty"}

  defp derive_address(source, value, account_index) do
    result =
      python variables: %{source: source, value: value, account_index: account_index} do
        ~PY"""
        from eth_account import Account

        Account.enable_unaudited_hdwallet_features()

        try:
            if source == "private_key":
                # Normalize: add 0x prefix if missing
                pk = value if value.startswith("0x") else "0x" + value
                acct = Account.from_key(pk)
            else:
                # From mnemonic
                hd_path = f"m/44'/60'/0'/0/{account_index}"
                acct = Account.from_mnemonic(value, account_path=hd_path)

            {"address": acct.address, "source": source}
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result}
    end
  end
end
