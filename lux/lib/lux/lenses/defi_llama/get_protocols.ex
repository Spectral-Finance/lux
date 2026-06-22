defmodule Lux.Lenses.DefiLlama.GetProtocols do
  @moduledoc """
  A lens for fetching protocol metrics from DeFiLlama.
  """
  use Lux.Lens,
    name: "Get DeFiLlama Protocols",
    description: "Fetches all protocols on DeFiLlama with their current TVL and metadata",
    url: "\#{Lux.Integrations.DefiLlama.base_url()}/protocols",
    method: :get,
    headers: Lux.Integrations.DefiLlama.headers(),
    auth: Lux.Integrations.DefiLlama.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(response) do
    case response do
      [first | _] = data when is_map(first) ->
        {:ok, data}

      %{"message" => msg} ->
        {:error, msg}

      error ->
        {:error, error}
    end
  end
end
