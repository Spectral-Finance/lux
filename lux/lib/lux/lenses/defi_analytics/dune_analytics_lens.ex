defmodule Lux.Lenses.DeFiAnalytics.DuneAnalyticsLens do
  @moduledoc """
  A lens for fetching query results from Dune Analytics.

  Executes or retrieves results from Dune Analytics queries using their API.
  Supports both fetching pre-existing results and triggering new query executions.

  ## Configuration

  Requires a Dune API key (free tier available at dune.com):
  - Config: `config :lux, :dune_api_key, "your_key"`
  - Env var: `DUNE_API_KEY=your_key`

  ## Example

      iex> Lux.Lenses.DeFiAnalytics.DuneAnalyticsLens.focus(%{
      ...>   query_id: 1527369,
      ...>   max_rows: 10
      ...> })
      {:ok, %{
        query_id: 1527369,
        execution_id: "01HQRB...",
        rows: [
          %{"protocol" => "Uniswap V3", "volume_usd" => 1234567890},
          ...
        ],
        row_count: 10,
        total_row_count: 847,
        columns: ["protocol", "volume_usd", "date"],
        status: "success"
      }}
  """

  use Lux.Lens,
    name: "Dune Analytics Query",
    description: "Fetches query results from Dune Analytics for on-chain data analysis",
    schema: %{
      type: :object,
      properties: %{
        query_id: %{
          type: :integer,
          description: "Dune Analytics query ID (visible in the URL: dune.com/queries/{id})"
        },
        max_rows: %{
          type: :integer,
          description: "Maximum number of rows to return (default: 100)",
          default: 100,
          minimum: 1,
          maximum: 1000
        },
        execute_fresh: %{
          type: :boolean,
          description: "Force a fresh query execution instead of using cached results (default: false)",
          default: false
        },
        query_parameters: %{
          type: :object,
          description: "Query parameters for parameterized Dune queries"
        }
      },
      required: ["query_id"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @impl true
  def focus(%{query_id: query_id} = input, _agent) do
    max_rows = Map.get(input, :max_rows, 100)
    execute_fresh = Map.get(input, :execute_fresh, false)
    query_params = Map.get(input, :query_parameters, %{})

    Logger.info("Dune Analytics lens: query_id=#{query_id} fresh=#{execute_fresh}")

    with {:ok, api_key} <- get_api_key() do
      result =
        python variables: %{
                 api_key: api_key,
                 query_id: query_id,
                 max_rows: max_rows,
                 execute_fresh: execute_fresh,
                 query_parameters: query_params
               } do
          ~PY"""
          import urllib.request
          import urllib.parse
          import json
          import time

          BASE_URL = "https://api.dune.com/api/v1"

          def fetch(url, method="GET", body=None, api_key=None, timeout=30):
              headers = {
                  "User-Agent": "LuxDeFiAnalytics/1.0",
                  "X-DUNE-API-KEY": api_key,
                  "Content-Type": "application/json"
              }
              data = json.dumps(body).encode() if body else None
              req = urllib.request.Request(url, data=data, headers=headers, method=method)
              with urllib.request.urlopen(req, timeout=timeout) as r:
                  return json.loads(r.read().decode())

          def wait_for_execution(execution_id, api_key, timeout=120):
              start = time.time()
              while time.time() - start < timeout:
                  state = fetch(f"{BASE_URL}/execution/{execution_id}/status", api_key=api_key)
                  s = state.get("state", "")
                  if s == "QUERY_STATE_COMPLETED":
                      return True
                  elif s in ("QUERY_STATE_FAILED", "QUERY_STATE_CANCELLED"):
                      raise Exception(f"Query failed with state: {s}")
                  time.sleep(3)
              raise Exception("Query execution timed out")

          try:
              execution_id = None

              if execute_fresh:
                  # Start new execution
                  body = {}
                  if query_parameters:
                      params_list = []
                      for k, v in query_parameters.items():
                          if isinstance(v, (int, float)):
                              params_list.append({"type": "number", "name": k, "value": v})
                          else:
                              params_list.append({"type": "text", "name": k, "value": str(v)})
                      body["query_parameters"] = params_list

                  exec_resp = fetch(
                      f"{BASE_URL}/query/{query_id}/execute",
                      method="POST",
                      body=body,
                      api_key=api_key
                  )
                  execution_id = exec_resp.get("execution_id")
                  wait_for_execution(execution_id, api_key)

              # Get results (latest execution or specific)
              results_url = f"{BASE_URL}/query/{query_id}/results"
              if execution_id:
                  results_url = f"{BASE_URL}/execution/{execution_id}/results"

              results_url += f"?limit={max_rows}"
              results = fetch(results_url, api_key=api_key)

              result_data = results.get("result", {})
              rows = result_data.get("rows", [])
              metadata = result_data.get("metadata", {})

              {
                  "query_id": query_id,
                  "execution_id": execution_id or results.get("execution_id", ""),
                  "rows": rows,
                  "row_count": len(rows),
                  "total_row_count": metadata.get("total_row_count", len(rows)),
                  "columns": metadata.get("column_names", list(rows[0].keys()) if rows else []),
                  "column_types": metadata.get("column_types", []),
                  "execution_started_at": results.get("execution_started_at", ""),
                  "execution_ended_at": results.get("execution_ended_at", ""),
                  "status": "success"
              }
          except Exception as e:
              {"error": str(e)}
          """
        end

      if Map.has_key?(result, "error") do
        {:error, result["error"]}
      else
        {:ok, result |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def focus(_input, _agent), do: {:error, "query_id is required"}

  defp get_api_key do
    case Config.get(:dune_api_key) do
      nil ->
        case System.get_env("DUNE_API_KEY") do
          nil -> {:error, "Missing configuration: DUNE_API_KEY"}
          key -> {:ok, key}
        end
      key -> {:ok, key}
    end
  rescue
    _ ->
      case System.get_env("DUNE_API_KEY") do
        nil -> {:error, "Missing configuration: DUNE_API_KEY"}
        key -> {:ok, key}
      end
  end
end
