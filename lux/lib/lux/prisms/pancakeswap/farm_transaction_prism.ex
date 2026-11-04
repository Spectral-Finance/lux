defmodule Lux.Prisms.PancakeSwap.FarmTransactionPrism do
  @moduledoc """
  Builds unsigned MasterChef V2 transactions for farming operations.

  Actions:

    * `"stake"` - deposit LP tokens. An `approve` step is added first when the wallet's
      LP allowance for the MasterChef is below `amount`.
    * `"unstake"` - withdraw LP tokens (pending CAKE is harvested by the contract).
    * `"harvest"` - collect pending CAKE rewards (`deposit(pid, 0)`).
    * `"emergency_withdraw"` - withdraw the whole stake and forfeit pending rewards.

  The prism never signs or sends anything: it returns `steps`, an ordered list of
  `%{name, chain_id, to, data, value}` maps to be signed and broadcast by the caller.

  ## Example

      iex> Lux.Prisms.PancakeSwap.FarmTransactionPrism.run(%{
      ...>   chain: "bsc",
      ...>   action: "stake",
      ...>   pool_id: 2,
      ...>   owner: "0x00000000000000000000000000000000000000aa",
      ...>   amount: "1000000000000000000"
      ...> })
      {:ok,
       %{
         chain: "bsc",
         chain_id: 56,
         action: "stake",
         pool_id: 2,
         steps: [%{name: "approve", ...}, %{name: "deposit", ...}]
       }}
  """

  use Lux.Prism,
    name: "PancakeSwap Farm Transaction",
    description: "Builds unsigned stake, unstake, harvest and emergency withdraw transactions",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, description: "Chain name or id (default: bsc)", default: "bsc"},
        action: %{
          type: :string,
          enum: ["stake", "unstake", "harvest", "emergency_withdraw"],
          description: "Farm operation to build"
        },
        pool_id: %{type: :integer, minimum: 0, description: "MasterChef pool id (pid)"},
        owner: %{
          type: :string,
          description: "Wallet address (required for stake, used for the allowance check)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        amount: %{
          type: [:string, :integer],
          description: "LP amount in wei (required for stake and unstake)"
        },
        lp_token: %{type: :string, description: "LP token address (read from chain if omitted)"},
        masterchef: %{type: :string, description: "Override the MasterChef contract address"},
        rpc_url: %{type: :string, description: "Override the JSON-RPC endpoint"}
      },
      required: ["action", "pool_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string},
        chain_id: %{type: :integer},
        action: %{type: :string},
        pool_id: %{type: :integer},
        steps: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              chain_id: %{type: :integer},
              to: %{type: :string},
              data: %{type: :string},
              value: %{type: :string}
            }
          }
        }
      },
      required: ["chain", "action", "pool_id", "steps"]
    }

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client
  alias Lux.Integrations.PancakeSwap.Transactions

  @actions ["stake", "unstake", "harvest", "emergency_withdraw"]

  def handler(input, _ctx) do
    action = PancakeSwap.field(input, :action)
    pool_id = PancakeSwap.field(input, :pool_id)

    with :ok <- validate_action(action),
         :ok <- validate_pool_id(pool_id),
         {:ok, chain} <- PancakeSwap.fetch_chain(PancakeSwap.field(input, :chain, "bsc")),
         {:ok, masterchef} <-
           PancakeSwap.address(chain, :masterchef_v2, PancakeSwap.field(input, :masterchef)),
         {:ok, steps} <-
           Transactions.safe(fn -> build_steps(action, chain, masterchef, pool_id, input) end) do
      {:ok,
       %{chain: chain.name, chain_id: chain.id, action: action, pool_id: pool_id, steps: steps}}
    else
      {:error, reason} -> {:error, PancakeSwap.format_error(reason)}
    end
  end

  defp validate_action(action) when action in @actions, do: :ok

  defp validate_action(action),
    do: {:error, "Unknown action: #{inspect(action)}. Use one of: #{Enum.join(@actions, ", ")}"}

  defp validate_pool_id(pool_id) when is_integer(pool_id) and pool_id >= 0, do: :ok
  defp validate_pool_id(_), do: {:error, "pool_id must be a non-negative integer"}

  defp build_steps("stake", chain, masterchef, pool_id, input) do
    opts = PancakeSwap.rpc_opts(input)
    owner = PancakeSwap.field(input, :owner)

    with {:ok, amount} <- positive_amount(input),
         :ok <- validate_owner(owner),
         {:ok, lp_token} <- lp_token(chain, masterchef, pool_id, input, opts),
         {:ok, approvals} <-
           Transactions.approval_steps(chain, lp_token, owner, masterchef, amount, opts) do
      deposit =
        Transactions.step("deposit", chain, masterchef, "deposit(uint256,uint256)", [
          pool_id,
          amount
        ])

      {:ok, approvals ++ [deposit]}
    end
  end

  defp build_steps("unstake", chain, masterchef, pool_id, input) do
    with {:ok, amount} <- positive_amount(input) do
      {:ok,
       [
         Transactions.step("withdraw", chain, masterchef, "withdraw(uint256,uint256)", [
           pool_id,
           amount
         ])
       ]}
    end
  end

  defp build_steps("harvest", chain, masterchef, pool_id, _input) do
    {:ok,
     [Transactions.step("harvest", chain, masterchef, "deposit(uint256,uint256)", [pool_id, 0])]}
  end

  defp build_steps("emergency_withdraw", chain, masterchef, pool_id, _input) do
    {:ok,
     [
       Transactions.step(
         "emergency_withdraw",
         chain,
         masterchef,
         "emergencyWithdraw(uint256)",
         [pool_id]
       )
     ]}
  end

  defp positive_amount(input) do
    case PancakeSwap.parse_positive_amount(PancakeSwap.field(input, :amount)) do
      {:ok, amount} -> {:ok, amount}
      :error -> {:error, "amount must be a positive integer (wei)"}
    end
  end

  defp validate_owner(owner) do
    if PancakeSwap.valid_address?(owner),
      do: :ok,
      else: {:error, "owner must be a valid 0x-prefixed Ethereum address"}
  end

  defp lp_token(chain, masterchef, pool_id, input, opts) do
    case PancakeSwap.field(input, :lp_token) do
      nil ->
        case Client.eth_call(
               chain,
               masterchef,
               "lpToken(uint256)",
               [pool_id],
               ["address"],
               opts
             ) do
          {:ok, [lp_token]} ->
            {:ok, lp_token}

          {:error, reason} ->
            {:error, "Failed to read LP token: #{PancakeSwap.format_error(reason)}"}
        end

      lp_token ->
        PancakeSwap.address(chain, :lp_token, lp_token)
    end
  end
end
