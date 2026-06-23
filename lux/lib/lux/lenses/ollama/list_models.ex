defmodule Lux.Lenses.Ollama.ListModels do
  @moduledoc """
  A lens for listing available models on an Ollama instance.
  This lens provides a simple interface for fetching models with:
  - No required parameters
  - Direct Ollama API error propagation
  - Clean response structure

  ## Examples
      iex> ListModels.focus(%{})
      {:ok, [
        %{
          name: "llama3:latest",
          size: 4661224676,
          modified_at: "2024-03-28T12:00:00Z",
          digest: "abc123..."
        }
      ]}
  """

  use Lux.Lens,
    name: "List Ollama Models",
    description: "Lists all available models on the Ollama instance",
    url: "http://localhost:11434/api/tags",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: nil,
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @doc """
  Transforms the Ollama API response into a simpler format.
  """
  @impl true
  def after_focus(%{"models" => models}) when is_list(models) do
    transformed =
      Enum.map(models, fn model ->
        %{
          name: model["name"],
          size: model["size"],
          modified_at: model["modified_at"],
          digest: model["digest"],
          details: model["details"]
        }
      end)

    {:ok, transformed}
  end

  def after_focus(%{"error" => message}) do
    {:error, message}
  end

  def after_focus(response) do
    {:error, %{"message" => "Unexpected response format: #{inspect(response)}"}}
  end
end
