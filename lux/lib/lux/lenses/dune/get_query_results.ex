defmodule Lux.Lenses.Dune.GetQueryResults do
  @moduledoc """
  A lens for retrieving the results of an executed Dune Analytics query.
  """

  @behaviour Lux.Lens

  def view do
    Lux.Lens.new(
      name: "Get Dune Query Results",
      module_name: "Lux.Lenses.Dune.GetQueryResults",
      description: "Retrieves results for an executed Dune Analytics query by execution ID",
      method: :get,
      headers: Lux.Integrations.Dune.headers(),
      auth: Lux.Integrations.Dune.auth(),
      schema: %{
        type: :object,
        properties: %{
          execution_id: %{
            type: :string,
            description: "The execution ID returned when the query was executed"
          }
        },
        required: ["execution_id"]
      },
      after_focus: &__MODULE__.after_focus/1
    )
  end

  def focus(input \\ %{}, opts \\ []) do
    execution_id = Map.get(input, :execution_id) || Map.get(input, "execution_id")
    params = Map.drop(input, [:execution_id, "execution_id"])
    url = "\#{Lux.Integrations.Dune.base_url()}/execution/\#{execution_id}/results"

    view()
    |> Map.put(:url, url)
    |> Map.put(:params, params)
    |> Lux.Integrations.Dune.authenticate()
    |> Lux.Lens.focus(opts)
  end

  def after_focus(%{"state" => "QUERY_STATE_COMPLETED", "result" => %{"rows" => rows}} = response) do
    {:ok, %{status: "completed", rows: rows, raw_response: response}}
  end

  def after_focus(%{"state" => state} = response) do
    {:ok, %{status: String.downcase(String.replace(state, "QUERY_STATE_", "")), raw_response: response}}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(error) do
    {:error, error}
  end
end
