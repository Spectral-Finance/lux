defmodule Lux.Prisms.Curve.CurveDepositPrism do
  @moduledoc """
  A prism that deposits assets into a Curve Finance pool.

  ## Example

      iex> Lux.Prisms.Curve.CurveDepositPrism.run(%{
      ...>   pool_name: "3crypto",
      ...>   amounts: ["1000000000000000000000", "1000000000000000000000", "1000000000000000000000"]
      ...> })
      {:ok, %{tx_hash: "0x...", pool: "3crypto", amounts: [...]}}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for signing transactions
  """

  use Lux.Prism,
    name: "Curve Deposit",
    description: "Deposits assets into a Curve Finance pool",
    input_schema: %{
      type: :object,
      properties: %{
        pool_name: %{
          type: :string,
          description: "The name of the Curve pool (e.g., 3crypto, fraxswap, yearn, aave)"
        },
        amounts: %{
          type: :array,
          description: "Amounts to deposit for each coin in the pool (in wei)",
          items: %{type: :string}
        },
        min_mint_amount: %{
          type: :string,
          description: "Minimum amount of LP tokens to mint (slippage protection)",
          default: "0"
        },
        account: %{
          type: :string,
          description: "Optional account address (defaults to configured wallet address)"
        }
      },
      required: ["pool_name", "amounts"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string, description: "Transaction hash"},
        pool: %{type: :string, description: "Pool name"},
        amounts: %{type: :array, items: %{type: :string}, description: "Deposited amounts"},
        lp_tokens: %{type: :string, description: "LP tokens received"}
      },
      required: ["tx_hash", "pool", "amounts"]
    },
    examples: [
      "Deposit 1000 USDC, 1000 DAI, 1000 USDT into the 3crypto pool"
    ]

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- get_address(),
         {:ok, rpc_url} <- {:ok, Lux.Integrations.Curve.rpc_url()},
         {:ok, chain_id} <- {:ok, Lux.Integrations.Curve.chain_id()},
         {:ok, result} <- execute_deposit(private_key, address, rpc_url, chain_id, input) do
      {:ok, result}
    else
      {:error, :missing_private_key} ->
        {:error, "Ethereum private key is not configured for Curve transactions"}

      {:error, :missing_rpc_url} ->
        {:error, "Curve RPC URL is not configured"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_private_key do
    case Application.get_env(:ethers, :default_signer_opts, [])[:private_key] do
      nil ->
        case Application.get_env(:lux, :accounts, [])[:hyperliquid_private_key] do
          nil -> {:error, :missing_private_key}
          key when is_binary(key) -> {:ok, key}
        end
      key when is_binary(key) -> {:ok, key}
    end
  rescue
    _ ->
      case Application.get_env(:ethers, :default_signer_opts, [])[:private_key] do
        nil -> {:error, :missing_private_key}
        key when is_binary(key) -> {:ok, key}
      end
  end

  defp get_address do
    case Application.get_env(:lux, :accounts, [])[:hyperliquid_address] do
      nil ->
        case Application.get_env(:lux, :accounts, [])[:wallet_address] do
          nil -> {:ok, ""}
          addr when is_binary(addr) -> {:ok, addr}
        end
      addr when is_binary(addr) -> {:ok, addr}
    end
  end

  defp execute_deposit(private_key, address, rpc_url, chain_id, params) do
    python_code = File.read!(Path.join(__DIR__, "../../../priv/python/curve_deposit.py"))

    python_result =
      python variables: %{
               private_key: private_key,
               address: address,
               rpc_url: rpc_url,
               chain_id: chain_id,
               params: params
             } do
        ~PY"""
        #{python_code}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
      result -> {:ok, %{tx_hash: to_string(result), pool: params["pool_name"], amounts: params["amounts"]}}
    end
  end
end
