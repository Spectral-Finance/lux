defmodule Lux.Prisms.Curve.CurveGaugeStakePrism do
  @moduledoc """
  A prism that stakes LP tokens in Curve Finance gauges for CRV rewards.

  ## Example

      iex> Lux.Prisms.Curve.CurveGaugeStakePrism.run(%{
      ...>   pool_name: "3crypto",
      ...>   amount: "1000000000000000000000"
      ...> })
      {:ok, %{tx_hash: "0x...", pool: "3crypto", amount_staked: "..."}}
  """

  use Lux.Prism,
    name: "Curve Gauge Stake",
    description: "Stakes LP tokens in Curve gauge for CRV rewards",
    input_schema: %{
      type: :object,
      properties: %{
        pool_name: %{type: :string, description: "The name of the Curve pool"},
        amount: %{type: :string, description: "Amount of LP tokens to stake (in wei)"},
        account: %{type: :string, description: "Optional account address"}
      },
      required: ["pool_name", "amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string, description: "Transaction hash"},
        pool: %{type: :string, description: "Pool name"},
        amount_staked: %{type: :string, description: "Amount of LP tokens staked"},
        gauge_address: %{type: :string, description: "Gauge contract address"}
      },
      required: ["tx_hash", "pool", "amount_staked"]
    },
    examples: ["Stake 1000 LP tokens in the 3crypto gauge for CRV rewards"]

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- get_address(),
         {:ok, rpc_url} <- {:ok, Lux.Integrations.Curve.rpc_url()},
         {:ok, chain_id} <- {:ok, Lux.Integrations.Curve.chain_id()},
         {:ok, result} <- execute_stake(private_key, address, rpc_url, chain_id, input) do
      {:ok, result}
    else
      {:error, :missing_private_key} -> {:error, "Ethereum private key is not configured for Curve transactions"}
      {:error, :missing_rpc_url} -> {:error, "Curve RPC URL is not configured"}
      {:error, reason} -> {:error, reason}
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

  defp execute_stake(private_key, address, rpc_url, chain_id, params) do
    python_code = File.read!(Path.join(__DIR__, "../../../priv/python/curve_gauge_stake.py"))

    python_result =
      python variables: %{private_key: private_key, address: address, rpc_url: rpc_url, chain_id: chain_id, params: params} do
        ~PY"""
        #{python_code}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
      result -> {:ok, %{tx_hash: to_string(result), pool: params["pool_name"], amount_staked: params["amount"]}}
    end
  end
end
