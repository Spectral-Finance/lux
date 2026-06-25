defmodule Lux.Lenses.DeFiLlama.Chains do
  @moduledoc """
  Lens for fetching TVL data for all tracked chains.

  ## Examples

  ```elixir
  # Get all chains TVL
  Lux.Lenses.DeFiLlama.Chains.focus(%{})
  ```
  """

  use Lux.Lens,
    name: "DeFiLlama.Chains",
    description: "Fetches TVL data for all tracked blockchain networks",
    url: "https://api.llama.fi/chains",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def after_focus(body) when is_list(body) do
    {:ok, %{
      chains: body,
      count: length(body),
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
