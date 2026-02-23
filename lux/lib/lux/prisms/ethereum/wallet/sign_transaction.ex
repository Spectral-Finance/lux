defmodule Lux.Prisms.Ethereum.Wallet.SignTransaction do
  @moduledoc """
  A prism for signing Ethereum transactions offline.

  Signs a transaction using a provided private key, producing a serialized
  signed transaction ready for broadcasting.

  Supports EIP-1559 (type 2) transactions with maxFeePerGas / maxPriorityFeePerGas,
  and legacy (type 0) transactions with gasPrice.

  ## Examples

      iex> SignTransaction.handler(%{
      ...>   private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ...>   to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      ...>   value_wei: "1000000000000000000",
      ...>   gas: 21000,
      ...>   max_fee_per_gas: "20000000000",
      ...>   max_priority_fee_per_gas: "1000000000",
      ...>   nonce: 0,
      ...>   chain_id: 1
      ...> }, %{agent: %{name: "TestAgent"}})
      {:ok, %{
        raw_transaction: "0x02...",
        transaction_hash: "0x...",
        from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
      }}
  """

  use Lux.Prism,
    name: "Sign Ethereum Transaction",
    description: "Signs an Ethereum transaction offline using a private key",
    input_schema: %{
      type: :object,
      properties: %{
        private_key: %{
          type: :string,
          description: "Private key (hex with 0x prefix)"
        },
        to: %{
          type: :string,
          description: "Recipient address (checksummed hex)"
        },
        value_wei: %{
          type: :string,
          description: "Value to send in Wei (as string to avoid precision loss)",
          default: "0"
        },
        gas: %{
          type: :integer,
          description: "Gas limit for the transaction",
          default: 21000
        },
        nonce: %{
          type: :integer,
          description: "Transaction nonce"
        },
        chain_id: %{
          type: :integer,
          description: "EVM chain ID (1=mainnet, 8453=base, 137=polygon, etc.)",
          default: 1
        },
        max_fee_per_gas: %{
          type: :string,
          description: "EIP-1559 max fee per gas in Wei (string). Mutually exclusive with gas_price."
        },
        max_priority_fee_per_gas: %{
          type: :string,
          description: "EIP-1559 priority fee per gas in Wei (string)"
        },
        gas_price: %{
          type: :string,
          description: "Legacy gas price in Wei (string). Used if max_fee_per_gas not provided."
        },
        data: %{
          type: :string,
          description: "Transaction calldata as hex string (default: '0x')",
          default: "0x"
        }
      },
      required: ["private_key", "to", "nonce"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        raw_transaction: %{
          type: :string,
          description: "RLP-encoded signed transaction hex ready for broadcasting"
        },
        transaction_hash: %{
          type: :string,
          description: "Keccak256 hash of the signed transaction"
        },
        from: %{
          type: :string,
          description: "Sender address derived from the private key"
        }
      },
      required: ["raw_transaction", "transaction_hash", "from"]
    }

  import Lux.Python
  require Lux.Python
  require Logger

  def handler(input, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"

    with {:ok, private_key} <- validate_required(input, :private_key),
         {:ok, to} <- validate_required(input, :to),
         {:ok, nonce} <- validate_nonce(input),
         {:ok, %{"success" => true}} <- Lux.Python.import_package("eth_account"),
         {:ok, result} <- sign_tx(private_key, to, nonce, input) do
      Logger.info("Agent #{agent_name} signed tx #{result["transaction_hash"]} from #{result["from"]}")
      {:ok, %{
        raw_transaction: result["raw_transaction"],
        transaction_hash: result["transaction_hash"],
        from: result["from"]
      }}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Failed to import eth_account: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_required(input, key) do
    case Map.fetch(input, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "#{key} is required"}
    end
  end

  defp validate_nonce(%{nonce: nonce}) when is_integer(nonce) and nonce >= 0, do: {:ok, nonce}
  defp validate_nonce(_), do: {:error, "nonce must be a non-negative integer"}

  defp sign_tx(private_key, to, nonce, input) do
    result =
      python variables: %{
        private_key: private_key,
        to: to,
        nonce: nonce,
        value_wei: Map.get(input, :value_wei, "0"),
        gas: Map.get(input, :gas, 21_000),
        chain_id: Map.get(input, :chain_id, 1),
        max_fee_per_gas: Map.get(input, :max_fee_per_gas),
        max_priority_fee_per_gas: Map.get(input, :max_priority_fee_per_gas),
        gas_price: Map.get(input, :gas_price),
        data: Map.get(input, :data, "0x")
      } do
        ~PY"""
        from eth_account import Account
        from eth_account.datastructures import SignedTransaction

        try:
            pk = private_key if private_key.startswith("0x") else "0x" + private_key
            acct = Account.from_key(pk)

            tx = {
                "to": to,
                "nonce": nonce,
                "value": int(value_wei),
                "gas": gas,
                "chainId": chain_id,
                "data": data if data else "0x",
            }

            if max_fee_per_gas:
                # EIP-1559 transaction (type 2)
                tx["maxFeePerGas"] = int(max_fee_per_gas)
                tx["maxPriorityFeePerGas"] = int(max_priority_fee_per_gas) if max_priority_fee_per_gas else int(max_fee_per_gas) // 10
                tx["type"] = 2
            elif gas_price:
                # Legacy transaction (type 0)
                tx["gasPrice"] = int(gas_price)
            else:
                # Default to 20 gwei legacy
                tx["gasPrice"] = 20_000_000_000

            signed = Account.sign_transaction(tx, pk)

            {
                "raw_transaction": signed.rawTransaction.hex() if not signed.rawTransaction.hex().startswith("0x") else signed.rawTransaction.hex(),
                "transaction_hash": signed.hash.hex(),
                "from": acct.address
            }
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
