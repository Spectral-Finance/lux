defmodule Lux.Prisms.Web3WalletInfrastructurePrism do
  @moduledoc """
  A Prism for autonomous agents to manage multi-chain Web3 wallets,
  sign transactions, estimate gas, track balances, and manage transaction queues.

  ## Examples

      iex> Lux.Prisms.Web3WalletInfrastructurePrism.run(%{
      ...>   action: "provision_wallet",
      ...>   payload: %{label: "DeFi Operator"}
      ...> })
      {:ok, %{action: "provision_wallet", result: %{account: %{address: "0x..."}, status: :active}}}
  """

  use Lux.Prism,
    name: "Web3 Wallet Infrastructure Prism",
    description: "Multi-chain wallet management, EIP-1559/EIP-712 transaction signing, gas estimation, balance tracking, and queue management",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "provision_wallet",
            "derive_account",
            "estimate_gas",
            "build_and_sign_tx",
            "fetch_balances",
            "enqueue_tx",
            "speed_up_fee",
            "query_history"
          ],
          description: "Wallet infrastructure action to execute"
        },
        payload: %{
          type: :object,
          description: "Payload data corresponding to chosen action"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Web3.WalletInfrastructure

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "provision_wallet")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "Web3WalletInfrastructurePrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("provision_wallet", payload) do
    label = Map.get(payload, :label, Map.get(payload, "label", "Primary Agent Wallet"))
    pass = Map.get(payload, :passphrase, Map.get(payload, "passphrase", "default_pass"))
    {:ok, WalletInfrastructure.provision_wallet(label, pass)}
  end

  defp execute_action("derive_account", payload) do
    mnemonic = Map.get(payload, :mnemonic, Map.get(payload, "mnemonic", ""))
    index = Map.get(payload, :index, Map.get(payload, "index", 0))
    {:ok, WalletInfrastructure.derive_account(mnemonic, index)}
  end

  defp execute_action("estimate_gas", payload) do
    chain_id = Map.get(payload, :chain_id, Map.get(payload, "chain_id", 1))
    limit = Map.get(payload, :gas_limit, Map.get(payload, "gas_limit", 21_000))
    {:ok, WalletInfrastructure.estimate_gas(chain_id, limit)}
  end

  defp execute_action("build_and_sign_tx", payload) do
    raw = WalletInfrastructure.build_tx(payload)
    key = Map.get(payload, :private_key, Map.get(payload, "private_key", "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))
    {:ok, WalletInfrastructure.sign_tx(raw, key)}
  end

  defp execute_action("fetch_balances", payload) do
    address = Map.get(payload, :address, Map.get(payload, "address", "0x0000000000000000000000000000000000000000"))
    {:ok, WalletInfrastructure.fetch_balances(address)}
  end

  defp execute_action("enqueue_tx", payload) do
    queue = WalletInfrastructure.init_queue()
    {:ok, _q, item} = WalletInfrastructure.enqueue_tx(queue, payload)
    {:ok, item}
  end

  defp execute_action("speed_up_fee", payload) do
    max_fee = Map.get(payload, :max_fee_per_gas, 30_000_000_000)
    tip = Map.get(payload, :max_priority_fee_per_gas, 1_500_000_000)
    {:ok, WalletInfrastructure.speed_up_fee(max_fee, tip)}
  end

  defp execute_action("query_history", payload) do
    address = Map.get(payload, :address, Map.get(payload, "address", "0x0"))
    history = Map.get(payload, :history, Map.get(payload, "history", []))
    {:ok, %{entries: WalletInfrastructure.query_history(history, address)}}
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end
end
