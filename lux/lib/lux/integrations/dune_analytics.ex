defmodule Lux.Integrations.DuneAnalytics do
  @moduledoc """
  Integration with the Dune Analytics API for on-chain data queries.

  Dune Analytics provides a powerful platform for querying blockchain data
  using SQL-like queries (Lambda for newer queries, SQL for legacy).

  ## Configuration

  Configure your Dune API key in config/runtime.exs.

  ## API Endpoints

  - POST /api/v3/execution/execute_lambda_query/ - Execute Lambda query
  - GET /api/v3/execution/query/{query_id}/results/ - Get query results
  - GET /api/v3/execution/query/{query_id}/statuses/ - Get query status
  - POST /api/v1/query/{query_id}/execute/ - Execute legacy query
  - GET /api/v1/query/{query_id}/results/ - Get query results (legacy)
  - POST /api/v1/query/{query_id}/publish/ - Publish a query
  - GET /api/v3/table/{table_name}/schemas/ - Get table schemas
  - GET /api/v3/table/{table_name}/results/latest/ - Get latest table results
  """

  @base_url "https://api.dune.com/api/v1"
  @execution_base_url "https://api.dune.com/api/v3/execution"

  @doc """
  Returns the Dune Analytics API base URL (legacy v1).
  """
  @spec base_url() :: String.t()
  def base_url, do: @base_url

  @doc """
  Returns the Dune Analytics execution API base URL (v3).
  """
  @spec execution_base_url() :: String.t()
  def execution_base_url, do: @execution_base_url

  @doc """
  Gets the Dune API key from configuration.
  """
  @spec api_key() :: String.t()
  def api_key do
    :lux
    |> Application.get_env(:api_keys, [])
    |> Keyword.get(:dune, System.get_env("DUNE_API_KEY", ""))
  end

  @doc """
  Returns auth headers for Dune API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    api_key = api_key()
    if api_key != "" do
      [{"X-API-Key", api_key}, {"Content-Type", "application/json"}]
    else
      [{"Content-Type", "application/json"}]
    end
  end

  @doc """
  Executes a Lambda query on Dune Analytics.
  """
  @spec execute_lambda_query(map()) :: {:ok, any()} | {:error, any()}
  def execute_lambda_query(params) when is_map(params) do
    url = "#{@execution_base_url}/execute_lambda_query/"
    req_options = [headers: headers(), json: params]
    case Req.new(req_options) |> Req.request(method: :post, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Executes a legacy SQL query on Dune Analytics.
  """
  @spec execute_query(non_neg_integer(), map()) :: {:ok, any()} | {:error, any()}
  def execute_query(query_id, execution_params \ %{})
      when is_integer(query_id) and query_id >= 0 and is_map(execution_params) do
    url = "#{@base_url}/query/#{query_id}/execute"
    req_options = [headers: headers(), json: execution_params]
    case Req.new(req_options) |> Req.request(method: :post, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches the results of a completed query.
  """
  @spec query_results(non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def query_results(query_id) when is_integer(query_id) and query_id >= 0 do
    url = "#{@base_url}/query/#{query_id}/results"
    req_options = [headers: headers()]
    case Req.new(req_options) |> Req.request(method: :get, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the execution status of a query.
  """
  @spec query_status(non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def query_status(query_id) when is_integer(query_id) and query_id >= 0 do
    url = "#{@execution_base_url}/query/#{query_id}/statuses"
    req_options = [headers: headers()]
    case Req.new(req_options) |> Req.request(method: :get, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Polls a query until it completes or times out.
  """
  @spec poll_query_results(non_neg_integer(), keyword()) :: {:ok, any()} | {:error, any()}
  def poll_query_results(query_id, opts \ []) do
    timeout = Keyword.get(opts, :timeout_seconds, 300)
    interval = Keyword.get(opts, :poll_interval_ms, 3000)
    start_time = System.monotonic_time(:millisecond)
    poll_loop(query_id, start_time, timeout, interval)
  end

  defp poll_loop(query_id, start_time, timeout, interval) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = div(current_time - start_time, 1000)
    if elapsed >= timeout do
      {:error, "Query polling timed out after #{timeout}s"}
    else
      case query_status(query_id) do
        {:ok, %{status: 200, body: statuses}} when is_list(statuses) ->
          case statuses do
            [last | _] ->
              case Map.get(last, "status", "") do
                "QUERY_EXECUTION_SUCCEEDED" ->
                  query_results(query_id)
                status when status in ["QUERY_EXECUTION_STARTED", "QUERY_EXECUTION_WAITING_LOCK", "QUEUE_POSITION"] ->
                  :timer.sleep(interval)
                  poll_loop(query_id, start_time, timeout, interval)
                _ ->
                  {:error, "Query failed: #{inspect(statuses)}"}
              end
            [] ->
              :timer.sleep(interval)
              poll_loop(query_id, start_time, timeout, interval)
          end
        _ ->
          :timer.sleep(interval)
          poll_loop(query_id, start_time, timeout, interval)
      end
    end
  end

  @doc """
  Publishes a query to the Dune Analytics public marketplace.
  """
  @spec publish_query(non_neg_integer()) :: {:ok, any()} | {:error, any()}
  def publish_query(query_id) when is_integer(query_id) and query_id >= 0 do
    url = "#{@base_url}/query/#{query_id}/publish"
    req_options = [headers: headers()]
    case Req.new(req_options) |> Req.request(method: :post, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches table schemas from Dune Analytics.
  """
  @spec table_schemas(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def table_schemas(dataset, table) do
    url = "#{@execution_base_url}/table/#{URI.encode(dataset)}/#{URI.encode(table)}/schemas"
    req_options = [headers: headers()]
    case Req.new(req_options) |> Req.request(method: :get, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches the latest results for a materialized table.
  """
  @spec table_latest_results(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def table_latest_results(dataset, table) do
    url = "#{@execution_base_url}/table/#{URI.encode(dataset)}/#{URI.encode(table)}/results/latest"
    req_options = [headers: headers()]
    case Req.new(req_options) |> Req.request(method: :get, url: url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
