defmodule Lux.Prisms.Curve.ExecuteSwap do
  @moduledoc """
  A prism for executing token swaps on a Curve Finance Pool.
  """

  use Lux.Prism,
    name: "Curve Execute Swap",
    description: "Executes a token swap on a Curve StableSwap pool",
    input_schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Address of the Curve pool contract",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        i: %{
          type: :integer,
          description: "Index value for the coin to send"
        },
        j: %{
          type: :integer,
          description: "Index value of the coin to receive"
        },
        dx: %{
          type: :string,
          description: "Amount of i being exchanged"
        },
        min_dy: %{
          type: :string,
          description: "Minimum amount of j to receive"
        }
      },
      required: ["pool_address", "i", "j", "dx", "min_dy"]
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

  alias Lux.Integrations.Curve.Pool
  require Logger

  @impl true
  def handler(params, _agent) do
    dx = String.to_integer(params.dx)
    min_dy = String.to_integer(params.min_dy)

    # Note: Requires Ethers config setup with a valid wallet and RPC
    case Pool.exchange(
      params.i,
      params.j,
      dx,
      min_dy,
      to: params.pool_address
    ) |> Ethers.send() do
      {:ok, tx_hash} ->
        Logger.info("Successfully executed Curve swap: #{tx_hash}")
        {:ok, %{transaction_hash: tx_hash}}
        
      {:error, reason} ->
        Logger.error("Failed to execute Curve swap: #{inspect(reason)}")
        {:error, "Transaction failed: #{inspect(reason)}"}
    end
  end
end
