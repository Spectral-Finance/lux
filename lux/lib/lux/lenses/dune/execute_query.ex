defmodule Lux.Lenses.Dune.ExecuteQuery do
  @moduledoc """
  Lens for executing a custom query on Dune Analytics (v1 API).

  Starts query execution and then polls for results until completion.

  ## Examples

      iex> Lux.Lenses.Dune.ExecuteQuery.focus(%{query_id: 3_237_721})
      {:ok, %{execution_id: "01J...", state: "QUERY_STATE_COMPLETED", rows: [...]}}

      iex> Lux.Lenses.Dune.ExecuteQuery.focus(%{query_id: 9999999})
      {:error, "Query not found"}
  """

  use Lux.Lens,
    name: "Dune Execute Query API",
    description: "Executes a Dune Analytics query by ID and retrieves results.",
    url: "https://api.dune.com/api/v1/query/0/execute",
    method: :post,
    headers: [{"content-type", "application/json"}, {"accept", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Dune.authenticate/1
    },
    schema: %{
      type: :object,
      properties: %{
        query_id: %{
          type: :integer,
          description: "The ID of the Dune query to execute"
        },
        query_parameters: %{
          type: :object,
          description: "Optional parameters to pass to the query"
        }
      },
      required: ["query_id"]
    }

  @max_poll_attempts 30
  @poll_interval_ms 2_000

  @doc """
  Overrides focus to interpolate query_id into the URL path and
  optionally poll for results.
  """
  def focus(input \\ %{}, opts \\ []) do
    query_id = Map.get(input, :query_id) || Map.get(input, "query_id")

    unless query_id do
      {:error, "Missing required parameter: query_id"}
    else
      query_params = Map.get(input, :query_parameters) || Map.get(input, "query_parameters") || %{}

      execute_url = "https://api.dune.com/api/v1/query/#{query_id}/execute"

      lens =
        __MODULE__.view()
        |> Map.put(:url, execute_url)
        |> Map.update!(:params, &Map.merge(&1, %{query_parameters: query_params}))
        |> Lux.Lens.authenticate()

      case Lux.Lens.focus(lens, opts) do
        {:ok, %{execution_id: execution_id, state: state}} ->
          if Keyword.get(opts, :poll_results, false) do
            poll_for_results(execution_id, 0)
          else
            {:ok, %{execution_id: execution_id, state: state}}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  # Polls Dune for execution results with exponential backoff.
  defp poll_for_results(execution_id, attempt) when attempt < @max_poll_attempts do
    Process.sleep(@poll_interval_ms)

    results_url = "https://api.dune.com/api/v1/execution/#{execution_id}/results"

    lens =
      __MODULE__.view()
      |> Map.put(:url, results_url)
      |> Map.put(:method, :get)
      |> Map.put(:params, %{})
      |> Lux.Lens.authenticate()

    case Lux.Lens.focus(lens, []) do
      {:ok, %{"state" => "QUERY_STATE_COMPLETED", "result" => result}} ->
        rows = get_in(result, ["rows"]) || []
        {:ok, %{execution_id: execution_id, state: "QUERY_STATE_COMPLETED", rows: rows}}

      {:ok, %{"state" => state}} when state in ~w(QUERY_STATE_PENDING QUERY_STATE_EXECUTING) ->
        poll_for_results(execution_id, attempt + 1)

      {:ok, %{"state" => "QUERY_STATE_FAILED", "error" => error}} ->
        {:error, "Query execution failed: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp poll_for_results(_execution_id, _attempt) do
    {:error, "Query execution timed out after #{@max_poll_attempts} polling attempts"}
  end

  @doc """
  Transforms the API response from the execute endpoint.
  """
  @impl true
  def after_focus(%{"execution_id" => execution_id, "state" => state}) do
    {:ok, %{execution_id: execution_id, state: state}}
  end

  @impl true
  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response from Dune: #{inspect(response)}"}
  end
end
