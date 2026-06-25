defmodule Lux.Lenses.DeFiLlama.ProtocolsList do
  @moduledoc """
  Lens for fetching a list of all tracked DeFi protocols.

  ## Examples

  ```elixir
  # Get all protocols
  Lux.Lenses.DeFiLlama.ProtocolsList.focus(%{})
  ```
  """

  use Lux.Lens,
    name: "DeFiLlama.ProtocolsList",
    description: "Lists all tracked DeFi protocols with TVL and metadata",
    url: "https://api.llama.fi/protocols",
    method: :get,
    headers: [{"accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def after_focus(body) when is_list(body) do
    {:ok, %{
      protocols: body,
      count: length(body),
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
