defmodule Lux.Lenses.Perplexity.Models do
  @moduledoc """
  Lens for listing available Perplexity AI models.

  ## Example

  ```elixir
  alias Lux.Lenses.Perplexity.Models

  Models.focus(%{})
  ```
  """

  use Lux.Lens,
    name: "Perplexity Models API",
    description: "List available models in Perplexity API",
    url: "https://api.perplexity.ai/models",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Lenses.Perplexity.Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @impl true
  def after_focus(%{"data" => models}) when is_list(models) do
    transformed = Enum.map(models, fn model ->
      %{
        id: model["id"],
        created: model["created"],
        owned_by: model["owned_by"]
      }
    end)
    
    {:ok, %{models: transformed}}
  end

  @impl true
  def after_focus(response) do
    Lux.Lenses.Perplexity.Base.handle_response(response)
  end
end
