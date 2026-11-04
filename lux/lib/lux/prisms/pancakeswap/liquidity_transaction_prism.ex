defmodule Lux.Prisms.PancakeSwap.LiquidityTransactionPrism do
  @moduledoc """
  Builds unsigned PancakeSwap V2 router transactions to add or remove liquidity.

    * `"add"` - `addLiquidity` for `token_a`/`token_b`. Token approvals for the router
      are included when the wallet's allowance is too low.
    * `"remove"` - `removeLiquidity`. The LP token (pair) is looked up through the factory
      unless `lp_token` is given, and the router is approved to spend `liquidity`.

  Minimum amounts are derived from the desired/expected amounts with `slippage_bps`
  (default 50 = 0.5%), rounded down using integer math. All amounts are wei values passed
  as integers or decimal strings. The prism never signs or broadcasts anything.

  ## Example

      iex> Lux.Prisms.PancakeSwap.LiquidityTransactionPrism.run(%{
      ...>   chain: "bsc",
      ...>   action: "add",
      ...>   owner: "0x00000000000000000000000000000000000000aa",
      ...>   token_a: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
      ...>   token_b: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   amount_a_desired: "1000000000000000000",
      ...>   amount_b_desired: "500000000000000000"
      ...> })
      {:ok, %{action: "add", steps: [%{name: "approve", ...}, %{name: "add_liquidity", ...}]}}
  """

  use Lux.Prism,
    name: "PancakeSwap Liquidity Transaction",
    description: "Builds unsigned add/remove liquidity transactions for PancakeSwap V2 pairs",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, description: "Chain name or id (default: bsc)", default: "bsc"},
        action: %{type: :string, enum: ["add", "remove"]},
        owner: %{
          type: :string,
          description: "Wallet address; receives the tokens unless recipient is set",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        recipient: %{
          type: :string,
          description: "Address receiving LP tokens or withdrawn tokens"
        },
        token_a: %{type: :string, description: "First token address"},
        token_b: %{type: :string, description: "Second token address"},
        amount_a_desired: %{type: [:string, :integer], description: "add: token A amount (wei)"},
        amount_b_desired: %{type: [:string, :integer], description: "add: token B amount (wei)"},
        liquidity: %{type: [:string, :integer], description: "remove: LP amount to burn (wei)"},
        expected_amount_a: %{
          type: [:string, :integer],
          description: "remove: expected token A out"
        },
        expected_amount_b: %{
          type: [:string, :integer],
          description: "remove: expected token B out"
        },
        lp_token: %{type: :string, description: "remove: pair address (looked up if omitted)"},
        slippage_bps: %{type: :integer, minimum: 0, maximum: 10_000, default: 50},
        deadline: %{type: :integer, description: "Unix deadline (default: now + 20 minutes)"},
        router: %{type: :string, description: "Override the router address"},
        factory: %{type: :string, description: "Override the factory address"},
        rpc_url: %{type: :string, description: "Override the JSON-RPC endpoint"}
      },
      required: ["action", "owner", "token_a", "token_b"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string},
        chain_id: %{type: :integer},
        action: %{type: :string},
        slippage_bps: %{type: :integer},
        deadline: %{type: :integer},
        steps: %{type: :array}
      },
      required: ["chain", "action", "steps"]
    }

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client
  alias Lux.Integrations.PancakeSwap.Transactions

  @zero_address "0x0000000000000000000000000000000000000000"

  def handler(input, _ctx) do
    action = PancakeSwap.field(input, :action)

    with {:ok, action} <- validate_action(action),
         {:ok, chain} <- PancakeSwap.fetch_chain(PancakeSwap.field(input, :chain, "bsc")),
         {:ok, tokens} <- validate_addresses(input),
         {:ok, slippage_bps} <-
           PancakeSwap.parse_slippage(PancakeSwap.field(input, :slippage_bps)),
         {:ok, router} <-
           PancakeSwap.address(chain, :router_v2, PancakeSwap.field(input, :router)),
         context = %{
           chain: chain,
           router: router,
           tokens: tokens,
           slippage_bps: slippage_bps,
           deadline: PancakeSwap.deadline(input),
           opts: PancakeSwap.rpc_opts(input)
         },
         {:ok, steps} <- Transactions.safe(fn -> build_steps(action, context, input) end) do
      {:ok,
       %{
         chain: chain.name,
         chain_id: chain.id,
         action: action,
         slippage_bps: slippage_bps,
         deadline: context.deadline,
         steps: steps
       }}
    else
      {:error, reason} -> {:error, PancakeSwap.format_error(reason)}
    end
  end

  defp validate_action(action) when action in ["add", "remove"], do: {:ok, action}

  defp validate_action(action),
    do: {:error, "Unknown action: #{inspect(action)}. Use \"add\" or \"remove\""}

  defp validate_addresses(input) do
    [:owner, :token_a, :token_b]
    |> Enum.reduce_while({:ok, %{}}, fn key, {:ok, acc} ->
      value = PancakeSwap.field(input, key)

      if PancakeSwap.valid_address?(value) do
        {:cont, {:ok, Map.put(acc, key, value)}}
      else
        {:halt, {:error, "#{key} must be a valid 0x-prefixed Ethereum address"}}
      end
    end)
    |> check_distinct()
  end

  defp check_distinct({:ok, %{token_a: a, token_b: b} = tokens}) do
    if String.downcase(a) == String.downcase(b) do
      {:error, "token_a and token_b must be different tokens"}
    else
      {:ok, tokens}
    end
  end

  defp check_distinct(error), do: error

  defp build_steps("add", context, input) do
    %{chain: chain, router: router, tokens: tokens, slippage_bps: bps} = context

    with {:ok, amount_a} <- amount(input, :amount_a_desired),
         {:ok, amount_b} <- amount(input, :amount_b_desired),
         {:ok, recipient} <- recipient(input, tokens.owner),
         {:ok, approve_a} <-
           Transactions.approval_steps(
             chain,
             tokens.token_a,
             tokens.owner,
             router,
             amount_a,
             context.opts
           ),
         {:ok, approve_b} <-
           Transactions.approval_steps(
             chain,
             tokens.token_b,
             tokens.owner,
             router,
             amount_b,
             context.opts
           ) do
      add =
        Transactions.step(
          "add_liquidity",
          chain,
          router,
          "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
          [
            tokens.token_a,
            tokens.token_b,
            amount_a,
            amount_b,
            PancakeSwap.apply_slippage(amount_a, bps),
            PancakeSwap.apply_slippage(amount_b, bps),
            recipient,
            context.deadline
          ]
        )

      {:ok, approve_a ++ approve_b ++ [add]}
    end
  end

  defp build_steps("remove", context, input) do
    %{chain: chain, router: router, tokens: tokens, slippage_bps: bps} = context

    with {:ok, liquidity} <- amount(input, :liquidity),
         {:ok, expected_a} <- amount(input, :expected_amount_a),
         {:ok, expected_b} <- amount(input, :expected_amount_b),
         {:ok, recipient} <- recipient(input, tokens.owner),
         {:ok, lp_token} <- lp_token(context, input),
         {:ok, approvals} <-
           Transactions.approval_steps(
             chain,
             lp_token,
             tokens.owner,
             router,
             liquidity,
             context.opts
           ) do
      remove =
        Transactions.step(
          "remove_liquidity",
          chain,
          router,
          "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)",
          [
            tokens.token_a,
            tokens.token_b,
            liquidity,
            PancakeSwap.apply_slippage(expected_a, bps),
            PancakeSwap.apply_slippage(expected_b, bps),
            recipient,
            context.deadline
          ]
        )

      {:ok, approvals ++ [remove]}
    end
  end

  defp amount(input, key) do
    case PancakeSwap.parse_positive_amount(PancakeSwap.field(input, key)) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, "#{key} must be a positive integer (wei)"}
    end
  end

  defp recipient(input, owner) do
    case PancakeSwap.field(input, :recipient) do
      nil ->
        {:ok, owner}

      address ->
        if PancakeSwap.valid_address?(address),
          do: {:ok, address},
          else: {:error, "recipient must be a valid 0x-prefixed Ethereum address"}
    end
  end

  defp lp_token(context, input) do
    case PancakeSwap.field(input, :lp_token) do
      nil -> lookup_pair(context, input)
      address -> PancakeSwap.address(context.chain, :lp_token, address)
    end
  end

  defp lookup_pair(%{chain: chain, tokens: tokens, opts: opts}, input) do
    with {:ok, factory} <-
           PancakeSwap.address(chain, :factory_v2, PancakeSwap.field(input, :factory)),
         {:ok, [pair]} <-
           Client.eth_call(
             chain,
             factory,
             "getPair(address,address)",
             [tokens.token_a, tokens.token_b],
             ["address"],
             opts
           ) do
      if pair == @zero_address do
        {:error, "No PancakeSwap V2 pair exists for these tokens on #{chain.name}"}
      else
        {:ok, pair}
      end
    else
      {:error, reason} -> {:error, "Failed to look up pair: #{PancakeSwap.format_error(reason)}"}
    end
  end
end
