defmodule Lux.Lenses.DuneAnalytics.QueryResults do
  @moduledoc """
  Lens for fetching results from a Dune Analytics query.

  ## Examples

  ```elixir
  # Get results from a completed query
  Lux.Lenses.DuneAnalytics.QueryResults.focus(%{query_id: 12345})
  ```
  """

  alias Lux.Integrations.DuneAnalytics

  use Lux.Lens,
    name: "DuneAnalytics.QueryResults",
    description: "Fetches results from a completed Dune Analytics query",
    url: "https://api.dune.com/api/v1/query/:query_id/results",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.authenticate/1
    },
    schema: %{
      type: :object,
      properties: %{
        query_id: %{
          type: :integer,
          description: "Dune Analytics query ID",
          minimum: 0
        }
      },
      required: ["query_id"]
    }

  def authenticate(lens) do
    headers = lens.headers ++ DuneAnalytics.headers()
    %{lens | headers: headers}
  end

  def after_focus(body) when is_map(body) do
    {:ok, %{
      query_id: Map.get(body, "query_id"),
      execution_id: Map.get(body, "execution_id"),
      result: Map.get(body, "result", %{}),
      metadata: Map.get(body, "metadata", %{}),
      refresh_max: Map.get(body, "refreshMax"),
      state: Map.get(body, "state"),
      timestamp: DateTime.utc_now()
    }}
  end

  def after_focus(body) do
    {:ok, %{raw: body, timestamp: DateTime.utc_now()}}
  end
end
