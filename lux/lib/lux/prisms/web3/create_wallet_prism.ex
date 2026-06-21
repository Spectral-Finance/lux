defmodule Lux.Prisms.Web3.CreateWalletPrism do
  @moduledoc """
  Lux Prism to generate a new Web3 wallet or import an existing private key.
  Supports multiple wallet types (:local, :hd, :hardware, :multisig) with clear
  error boundaries for unimplemented types.
  Encrypts the private key, registers the address for balance monitoring,
  and optionally spins up a dedicated TransactionManager process.
  """

  use Lux.Prism,
    name: "Web3 Create Wallet",
    description: "Generates a new non-custodial wallet or imports an existing one, with multi-type and multi-chain support",
    input_schema: %{
      type: :object,
      properties: %{
        private_key: %{
          type: :string,
          description: "Optional existing private key to import (hex string)"
        },
        wallet_type: %{
          type: :string,
          description: "Wallet type: local, hd, hardware, or multisig (default: local)"
        },
        chain_ids: %{
          type: :array,
          items: %{type: :integer},
          description: "Chain IDs to monitor balances for (default: [1] for Ethereum mainnet)"
        },
        label: %{
          type: :string,
          description: "Optional human-readable label for the wallet"
        },
        start_manager: %{
          type: :boolean,
          description: "Whether to start the TransactionManager immediately (default: true)"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Derived public Ethereum address of the wallet"
        },
        encrypted_private_key: %{
          type: :string,
          description: "The AES-256-GCM encrypted private key payload"
        },
        wallet_type: %{
          type: :string,
          description: "The wallet type that was created"
        },
        chain_ids: %{
          type: :array,
          items: %{type: :integer},
          description: "Chain IDs being monitored"
        }
      },
      required: ["address", "encrypted_private_key", "wallet_type"]
    }

  @impl true
  def handler(input, _ctx) do
    wallet_type = parse_wallet_type(Map.get(input, :wallet_type, "local"))
    chain_ids = Map.get(input, :chain_ids, [1])
    label = Map.get(input, :label)
    start_manager? = Map.get(input, :start_manager, true)

    result =
      case Map.get(input, :private_key) do
        nil ->
          Lux.Web3.Wallet.generate_wallet(type: wallet_type, chain_ids: chain_ids, label: label)

        "0x" <> _ = hex_key ->
          import_wallet(hex_key, wallet_type, chain_ids, label)

        raw_hex ->
          hex_key = "0x" <> raw_hex
          import_wallet(hex_key, wallet_type, chain_ids, label)
      end

    case result do
      {:ok, %{private_key: pk, address: address}} ->
        finalize_wallet(pk, address, wallet_type, chain_ids, start_manager?)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp import_wallet(hex_key, wallet_type, chain_ids, label) do
    case Lux.Web3.WalletTypes.validate_type(wallet_type) do
      :ok ->
        case Lux.Web3.Wallet.derive_address(hex_key) do
          {:ok, address} ->
            {:ok, %{private_key: hex_key, address: address,
                     wallet_record: Lux.Web3.WalletTypes.new(address, wallet_type,
                       chain_ids: chain_ids, label: label)}}
          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp finalize_wallet(pk, address, wallet_type, chain_ids, start_manager?) do
    case Lux.Web3.KeyManager.encrypt(pk) do
      {:ok, encrypted_pk} ->
        # Register for balance monitoring across requested chains
        Lux.Web3.BalanceMonitor.watch(address, chain_ids)

        # Optionally start the transaction manager
        if start_manager? do
          case Lux.Web3.TransactionManager.start_manager(address, encrypted_pk) do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
            {:error, reason} ->
              {:error, "Failed to start transaction manager: #{inspect(reason)}"}
          end
        end

        {:ok, %{
          address: address,
          encrypted_private_key: encrypted_pk,
          wallet_type: Atom.to_string(wallet_type),
          chain_ids: chain_ids
        }}

      {:error, reason} ->
        {:error, "Failed to encrypt private key: #{inspect(reason)}"}
    end
  end

  defp parse_wallet_type("local"), do: :local
  defp parse_wallet_type("hd"), do: :hd
  defp parse_wallet_type("hardware"), do: :hardware
  defp parse_wallet_type("multisig"), do: :multisig
  defp parse_wallet_type(atom) when is_atom(atom), do: atom
  defp parse_wallet_type(other), do: String.to_existing_atom(other)
end
