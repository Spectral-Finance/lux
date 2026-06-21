defmodule Lux.Lenses.Curve.GetSwapQuote do
  @moduledoc """
  A lens for retrieving Curve Finance swap quotes.
  """

  use Lux.Lens,
    name: "Curve Swap Quote",
    description: "Fetches expected output amount for a swap in a Curve pool",
    schema: %{
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
        }
      },
      required: ["pool_address", "i", "j", "dx"]
    }

  alias Lux.Integrations.Curve.Pool

  @impl true
  def handler(params, _agent) do
    dx = String.to_integer(params.dx)
    
    case Pool.get_dy(params.i, params.j, dx, to: params.pool_address) do
      {:ok, amount_out} ->
        {:ok, %{expected_output: to_string(amount_out)}}
        
      {:error, reason} ->
        {:error, "Failed to fetch swap quote: #{inspect(reason)}"}
    end
  end
end
