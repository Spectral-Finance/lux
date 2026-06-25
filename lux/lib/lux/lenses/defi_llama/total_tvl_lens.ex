defmodule Lux.Lenses.DeFiLlama.TotalTVL do
  @moduledoc """
  Lens for fetching the current total DeFi TVL across all protocols.

  ## Examples

  ```elixir
  # Get current total DeFi TVL
  Lux.Lenses.DeFiLlama.TotalTVL.focus(%{})
  ```
  """

  use Lux.Lens,
    name: "DeFiLlama.TotalTVL",
    description: "Fetches the current total DeFi protocol TVL across all chains",
    url: "https://api.llama.fi/current-tvl",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def after_focus(body) when is_map(body) do
    {:ok, %{
      total_tvl: body["totalBreakdown"] || body,
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
