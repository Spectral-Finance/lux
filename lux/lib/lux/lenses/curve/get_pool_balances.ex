defmodule Lux.Lenses.Curve.GetPoolBalances do
  @moduledoc """
  A lens for retrieving token balances from a Curve Finance Pool.
  """

  use Lux.Lens,
    name: "Curve Pool Balances",
    description: "Fetches the token balance for a specific index in a Curve pool",
    schema: %{
      type: :object,
      properties: %{
        pool_address: %{
          type: :string,
          description: "Address of the Curve pool contract",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        index: %{
          type: :integer,
          description: "Index of the token in the pool (e.g. 0, 1, 2)"
        }
      },
      required: ["pool_address", "index"]
    }

  alias Lux.Integrations.Curve.Pool

  @impl true
  def handler(params, _agent) do
    case Pool.balances(params.index, to: params.pool_address) do
      {:ok, balance} ->
        {:ok, %{balance: to_string(balance)}}
        
      {:error, reason} ->
        {:error, "Failed to fetch pool balance: #{inspect(reason)}"}
    end
  end
end
