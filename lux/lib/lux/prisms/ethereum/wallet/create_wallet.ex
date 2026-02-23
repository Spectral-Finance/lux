defmodule Lux.Prisms.Ethereum.Wallet.CreateWallet do
  @moduledoc """
  A prism for creating new Ethereum wallets with HD derivation support.

  Generates a new wallet with:
  - A cryptographically secure mnemonic phrase (BIP-39)
  - An Ethereum address derived at the specified HD path (BIP-44)
  - The private key for signing transactions

  ## Examples

      iex> CreateWallet.handler(%{}, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        address: "0x...",
        private_key: "0x...",
        mnemonic: "word1 word2 ... word12",
        hd_path: "m/44'/60'/0'/0/0"
      }}

      iex> CreateWallet.handler(%{account_index: 2}, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        address: "0x...",
        private_key: "0x...",
        mnemonic: "...",
        hd_path: "m/44'/60'/0'/0/2"
      }}
  """

  use Lux.Prism,
    name: "Create Ethereum Wallet",
    description: "Generates a new HD Ethereum wallet with BIP-39 mnemonic and BIP-44 derivation",
    input_schema: %{
      type: :object,
      properties: %{
        account_index: %{
          type: :integer,
          description: "HD wallet account index (default: 0)",
          minimum: 0,
          default: 0
        },
        num_words: %{
          type: :integer,
          description: "Number of mnemonic words (12 or 24)",
          enum: [12, 24],
          default: 12
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Checksummed Ethereum address"
        },
        private_key: %{
          type: :string,
          description: "Private key (hex with 0x prefix)"
        },
        mnemonic: %{
          type: :string,
          description: "BIP-39 mnemonic phrase — keep secret!"
        },
        hd_path: %{
          type: :string,
          description: "BIP-44 derivation path used"
        }
      },
      required: ["address", "private_key", "mnemonic", "hd_path"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  def handler(input, agent) do
    account_index = Map.get(input, :account_index, 0)
    num_words = Map.get(input, :num_words, 12)
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"

    Logger.info("Agent #{agent_name} creating new Ethereum wallet at index #{account_index}")

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("eth_account"),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("mnemonic"),
         {:ok, result} <- generate_wallet(account_index, num_words) do
      Logger.info("Agent #{agent_name} created wallet at #{result["address"]}")
      {:ok, %{
        address: result["address"],
        private_key: result["private_key"],
        mnemonic: result["mnemonic"],
        hd_path: result["hd_path"]
      }}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Failed to import required package: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_wallet(account_index, num_words) do
    result =
      python variables: %{account_index: account_index, num_words: num_words} do
        ~PY"""
        from mnemonic import Mnemonic
        from eth_account import Account

        Account.enable_unaudited_hdwallet_features()

        # Generate mnemonic
        strength = 128 if num_words == 12 else 256
        mnemo = Mnemonic("english")
        mnemonic_phrase = mnemo.generate(strength=strength)

        # Derive account at BIP-44 path
        hd_path = f"m/44'/60'/0'/0/{account_index}"
        acct = Account.from_mnemonic(mnemonic_phrase, account_path=hd_path)

        {
            "address": acct.address,
            "private_key": "0x" + acct.key.hex(),
            "mnemonic": mnemonic_phrase,
            "hd_path": hd_path
        }
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, result}
    end
  end
end
