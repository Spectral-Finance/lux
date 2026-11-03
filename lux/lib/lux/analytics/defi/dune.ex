defmodule Lux.Analytics.Defi.Dune do
  @moduledoc """
  Dune Analytics API connector for executing queries, tracking execution states, and retrieving SQL results.
  """

  @base_url "https://api.dune.com/api/v1"

  @doc """
  Builds query execution URL for Dune query ID.
  """
  @spec execute_query_url(pos_integer()) :: String.t()
  def execute_query_url(query_id), do: "#{@base_url}/query/#{query_id}/execute"

  @doc """
  Builds execution status URL for an execution ID.
  """
  @spec execution_status_url(String.t()) :: String.t()
  def execution_status_url(execution_id), do: "#{@base_url}/execution/#{execution_id}/status"

  @doc """
  Builds execution results URL for an execution ID.
  """
  @spec execution_results_url(String.t()) :: String.t()
  def execution_results_url(execution_id), do: "#{@base_url}/execution/#{execution_id}/results"

  @doc """
  Formats authentication headers for Dune Analytics API calls.
  """
  @spec auth_headers(String.t()) :: [{String.t(), String.t()}]
  def auth_headers(api_key) when is_binary(api_key) do
    [
      {"x-dune-api-key", api_key},
      {"Content-Type", "application/json"},
      {"User-Agent", "Lux-Dune-Connector/1.0"}
    ]
  end

  @doc """
  Prepares execution request body with query parameters.
  """
  @spec build_execute_payload(map()) :: map()
  def build_execute_payload(params \\ %{}) do
    query_parameters = Map.get(params, :query_parameters) || Map.get(params, "query_parameters", %{})
    %{"query_parameters" => query_parameters}
  end

  @doc """
  Parses Dune query execution result payload into rows and metadata.
  """
  @spec parse_results(map()) :: {:ok, map()} | {:error, term()}
  def parse_results(%{"state" => "QUERY_STATE_COMPLETED", "result" => result}) do
    rows = result["rows"] || []
    metadata = result["metadata"] || %{}

    {:ok,
     %{
       state: :completed,
       rows: rows,
       row_count: length(rows),
       column_names: metadata["column_names"] || [],
       execution_time_millis: result["execution_time_millis"] || 0
     }}
  end

  def parse_results(%{"state" => "QUERY_STATE_EXECUTING"}) do
    {:ok, %{state: :executing, rows: [], row_count: 0}}
  end

  def parse_results(%{"state" => "QUERY_STATE_PENDING"}) do
    {:ok, %{state: :pending, rows: [], row_count: 0}}
  end

  def parse_results(%{"state" => "QUERY_STATE_FAILED", "error" => err}) do
    {:error, %{state: :failed, error: err}}
  end

  def parse_results(other), do: {:error, %{state: :unknown, data: other}}
end
