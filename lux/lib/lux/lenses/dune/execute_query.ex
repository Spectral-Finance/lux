defmodule Lux.Lenses.Dune.ExecuteQuery do
  @moduledoc """
  A lens for executing a custom query on Dune Analytics.
  """

  @behaviour Lux.Lens

  def view do
    Lux.Lens.new(
      name: "Execute Dune Query",
      module_name: "Lux.Lenses.Dune.ExecuteQuery",
      description: "Executes a Dune Analytics query by ID",
      method: :post,
      headers: Lux.Integrations.Dune.headers(),
      auth: Lux.Integrations.Dune.auth(),
      schema: %{
        type: :object,
        properties: %{
          query_id: %{
            type: :integer,
            description: "The ID of the Dune query to execute"
          },
          query_parameters: %{
            type: :object,
            description: "Optional parameters for the query"
          }
        },
        required: ["query_id"]
      },
      after_focus: &__MODULE__.after_focus/1
    )
  end

  def focus(input \\ %{}, opts \\ []) do
    query_id = Map.get(input, :query_id) || Map.get(input, "query_id")
    params = Map.drop(input, [:query_id, "query_id"])
    url = "\#{Lux.Integrations.Dune.base_url()}/query/\#{query_id}/execute"

    view()
    |> Map.put(:url, url)
    |> Map.put(:params, params)
    |> Lux.Integrations.Dune.authenticate()
    |> Lux.Lens.focus(opts)
  end

  def after_focus(%{"execution_id" => execution_id} = response) do
    {:ok, %{execution_id: execution_id, raw_response: response}}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(error) do
    {:error, error}
  end
end
