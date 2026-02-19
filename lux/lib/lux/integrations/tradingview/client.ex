defmodule Lux.Integrations.TradingView.Client do
  @moduledoc """
  HTTP client for TradingView's scanner API.

  Handles POST requests to the TradingView scanner endpoint to retrieve
  technical analysis data, indicator values, and chart data.

  ## Usage

      alias Lux.Integrations.TradingView.Client

      # Fetch technical analysis for Tesla
      Client.scan("america", %{
        symbols: %{tickers: ["NASDAQ:TSLA"], query: %{types: []}},
        columns: ["Recommend.All", "Recommend.MA", "Recommend.Other"]
      })
  """

  require Logger

  alias Lux.Integrations.TradingView

  @type scan_result :: {:ok, map()} | {:error, term()}

  @doc """
  Makes a scan request to the TradingView scanner API.

  ## Parameters

    * `screener` - Market screener (e.g., "america", "crypto", "forex")
    * `body` - Request body containing symbols and columns
    * `opts` - Additional options

  ## Returns

    * `{:ok, response}` - Successful response with data
    * `{:error, reason}` - Error response
  """
  @spec scan(String.t(), map(), keyword()) :: scan_result()
  def scan(screener, body, opts \\ []) do
    url = TradingView.scanner_url(screener)

    Logger.debug("TradingView Client scan: #{url} with body: #{inspect(body)}")

    req_opts =
      [url: url, headers: TradingView.headers(), max_retries: 2]
      |> Keyword.merge(Application.get_env(:lux, :req_options, []))
      |> Keyword.merge(opts)

    req_opts
    |> Req.new()
    |> Req.request(method: :post, json: body)
    |> handle_response()
  end

  @doc """
  Builds a scanner request body for the given symbols and columns.

  ## Parameters

    * `tickers` - List of ticker strings in "EXCHANGE:SYMBOL" format
    * `columns` - List of column names to retrieve
    * `interval` - Time interval (default: "1d")

  ## Returns

    A map suitable for passing to `scan/3`.
  """
  @spec build_scan_body([String.t()], [String.t()], String.t()) :: map()
  def build_scan_body(tickers, columns, interval \\ "1d") do
    interval_columns = Enum.map(columns, &TradingView.column_with_interval(&1, interval))

    %{
      symbols: %{
        tickers: tickers,
        query: %{types: []}
      },
      columns: interval_columns
    }
  end

  @doc """
  Parses the scanner response, mapping column names to their values.

  ## Parameters

    * `response` - Raw scanner API response
    * `columns` - Column names in the order they were requested
    * `opts` - Options:
      * `:strip_intervals` - Whether to strip interval suffixes from column names (default: true)

  ## Returns

    A map with ticker symbols as keys and column-value maps as values.
  """
  @spec parse_scan_response(map(), [String.t()], keyword()) :: map()
  def parse_scan_response(response, columns, opts \\ [])

  def parse_scan_response(%{"data" => data}, columns, opts) when is_list(data) do
    strip = Keyword.get(opts, :strip_intervals, true)

    Map.new(data, fn %{"s" => symbol, "d" => values} ->
      column_values =
        columns
        |> Enum.zip(values)
        |> Map.new(fn {col, val} ->
          key = if strip, do: strip_interval(col), else: col
          {key, val}
        end)

      {symbol, column_values}
    end)
  end

  def parse_scan_response(_, _, _), do: %{}

  # Strips the interval suffix from a column name (e.g., "RSI|60" -> "RSI")
  defp strip_interval(column) do
    column
    |> String.split("|")
    |> List.first()
  end

  defp handle_response({:ok, %{status: 200, body: body}}) do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("TradingView API error: status=#{status}, body=#{inspect(body)}")
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, %Req.TransportError{reason: reason}}) do
    Logger.error("TradingView transport error: #{inspect(reason)}")
    {:error, inspect(reason)}
  end

  defp handle_response({:error, error}) do
    Logger.error("TradingView request error: #{inspect(error)}")
    {:error, inspect(error)}
  end
end
