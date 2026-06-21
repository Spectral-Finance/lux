defmodule Lux.Prisms.Web3.WalletSignTx do
  @moduledoc """
  A prism to queue, sign, and broadcast a Web3 transaction using a managed wallet.
  """
  use Lux.Prism,
    name: "Web3 Wallet Sign and Broadcast",
    description: "Queues a transaction for a wallet and processes the next in queue.",
    input_schema: %{
      type: :object,
      properties: %{
        name: %{
          type: :string,
          description: "Internal name/alias for the wallet."
        },
        rpc_url: %{
          type: :string,
          description: "HTTP RPC URL for broadcasting."
        },
        to: %{
          type: :string,
          description: "Recipient address."
        },
        value: %{
          type: :string,
          description: "Hex amount of ETH/tokens to send."
        },
        data: %{
          type: :string,
          description: "Hex data payload."
        },
        gas_limit: %{
          type: :string,
          description: "Hex gas limit."
        },
        gas_price: %{
          type: :string,
          description: "Hex gas price."
        },
        nonce: %{
          type: :string,
          description: "Hex nonce."
        }
      },
      required: ["name", "rpc_url", "to", "value"]
    }

  alias Lux.Integrations.Web3.WalletManager

  def handler(params, _context) do
    tx_data = %{
      to: params.to,
      value: params.value,
      data: Map.get(params, :data, "0x"),
      gas_limit: Map.get(params, :gas_limit),
      gas_price: Map.get(params, :gas_price),
      nonce: Map.get(params, :nonce)
    }
    
    # Prune nils
    tx_data = Enum.reject(tx_data, fn {_k, v} -> is_nil(v) end) |> Enum.into(%{})
    
    # 1. Enqueue
    :ok = WalletManager.queue_transaction(params.name, tx_data)
    
    # 2. Process next
    case WalletManager.process_next_transaction(params.name, params.rpc_url) do
      {:ok, tx_hash} when is_binary(tx_hash) -> 
        {:ok, %{status: "broadcasted", tx_hash: tx_hash}}
      {:ok, :empty} -> 
        {:error, "Queue is empty"}
      {:error, err} -> 
        {:error, "Broadcast failed: #{inspect(err)}"}
    end
  end
end
