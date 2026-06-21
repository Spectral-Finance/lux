defmodule Lux.Prisms.PancakeSwap.ExecuteSwap do
  @moduledoc """
  A prism for executing token swaps on PancakeSwap V2.
  """

  use Lux.Prism,
    name: "PancakeSwap Execute Swap",
    description: "Executes a token swap on PancakeSwap",
    input_schema: %{
      type: :object,
      properties: %{
        amount_in: %{
          type: :string,
          description: "Amount of input token (in wei)"
        },
        amount_out_min: %{
          type: :string,
          description: "Minimum amount of output token (in wei)"
        },
        path: %{
          type: :array,
          items: %{type: :string},
          description: "Path of token addresses (e.g. [TokenA, TokenB])"
        },
        to: %{
          type: :string,
          description: "Recipient address"
        },
        deadline: %{
          type: :integer,
          description: "Unix timestamp deadline for the transaction"
        }
      },
      required: ["amount_in", "amount_out_min", "path", "to", "deadline"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        transaction_hash: %{
          type: :string,
          description: "Transaction hash"
        }
      },
      required: ["transaction_hash"]
    }

  alias Lux.Integrations.PancakeSwap.Router
  require Logger

  # PancakeSwap V2 Router on BSC
  @router_address "0x10ED43C718714eb63d5aA57B78B54704E256024E"

  @impl true
  def handler(params, _agent) do
    amount_in = String.to_integer(params.amount_in)
    amount_out_min = String.to_integer(params.amount_out_min)

    # Note: Requires Ethers config setup with a valid wallet and RPC
    case Router.swap_exact_tokens_for_tokens(
      amount_in,
      amount_out_min,
      params.path,
      params.to,
      params.deadline,
      to: @router_address
    ) |> Ethers.send() do
      {:ok, tx_hash} ->
        Logger.info("Successfully executed PancakeSwap swap: #{tx_hash}")
        {:ok, %{transaction_hash: tx_hash}}
        
      {:error, reason} ->
        Logger.error("Failed to execute swap: #{inspect(reason)}")
        {:error, "Transaction failed: #{inspect(reason)}"}
    end
  end
end
