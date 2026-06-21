defmodule Lux.Prisms.SushiSwap.ExecuteSwap do
  @moduledoc """
  A prism for executing token swaps on SushiSwap V2.
  """

  use Lux.Prism,
    name: "SushiSwap Execute Swap",
    description: "Executes a token swap on SushiSwap",
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

  alias Lux.Integrations.SushiSwap.Router
  require Logger

  # SushiSwap V2 Router on Ethereum
  @router_address "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F"

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
        Logger.info("Successfully executed SushiSwap swap: #{tx_hash}")
        {:ok, %{transaction_hash: tx_hash}}
        
      {:error, reason} ->
        Logger.error("Failed to execute swap: #{inspect(reason)}")
        {:error, "Transaction failed: #{inspect(reason)}"}
    end
  end
end
