defmodule Lux.Prisms.Curve.CurveClaimRewardsPrism do
  @moduledoc """
  A prism that claims CRV rewards from Curve Finance gauge staking.

  ## Example

      iex> Lux.Prisms.Curve.CurveClaimRewardsPrism.run(%{
      ...>   pool_name: "3crypto"
      ...> })
      {:ok, %{tx_hash: "0x...", rewards_claimed: %{crv: "...", ...}}}
  """

  use Lux.Prism,
    name: "Curve Claim Rewards",
    description: "Claims CRV rewards from Curve Finance gauge staking",
    input_schema: %{
      type: :object,
      properties: %{
        pool_name: %{type: :string, description: "The name of the Curve pool"},
        account: %{type: :string, description: "Optional account address"}
      },
      required: ["pool_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tx_hash: %{type: :string, description: "Transaction hash"},
        pool: %{type: :string, description: "Pool name"},
        crv_rewards: %{type: :string, description: "CRV rewards claimed"},
        voter_rewards: %{type: :map, description: "Other voter rewards"}
      },
      required: ["tx_hash", "pool"]
    },
    examples: ["Claim CRV rewards from the 3crypto gauge"]

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, private_key} <- get_private_key(),
         {:ok, address} <- get_address(),
         {:ok, rpc_url} <- {:ok, Lux.Integrations.Curve.rpc_url()},
         {:ok, chain_id} <- {:ok, Lux.Integrations.Curve.chain_id()},
         {:ok, result} <- execute_claim(private_key, address, rpc_url, chain_id, input) do
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

  defp execute_claim(private_key, address, rpc_url, chain_id, params) do
    python_code = File.read!(Path.join(__DIR__, "../../../priv/python/curve_claim_rewards.py"))

    python_result =
      python variables: %{private_key: private_key, address: address, rpc_url: rpc_url, chain_id: chain_id, params: params} do
        ~PY"""
        #{python_code}
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
      result -> {:ok, %{tx_hash: to_string(result), pool: params["pool_name"]}}
    end
  end
end
