defmodule Lux.Integrations.Web3.Chain.RpcClient do
  @moduledoc """
  JSON-RPC client for EVM chains with automatic retries and error handling.
  """

  @max_retries 3
  @retry_delay_ms 500

  @doc """
  Make a JSON-RPC call.

  ## Options
  - `:rpc_url` — RPC endpoint URL (required)
  - `:plug` — Test plug for Req.Test
  """
  def call(method, params \\ [], opts \\ []) do
    rpc_url = opts[:rpc_url] || raise "RPC URL required"

    body = %{
      jsonrpc: "2.0",
      id: System.unique_integer([:positive]),
      method: method,
      params: params
    }

    req_opts = [
      url: rpc_url,
      method: :post,
      json: body,
      retry: false
    ]

    req_opts = if opts[:plug], do: Keyword.put(req_opts, :plug, opts[:plug]), else: req_opts

    do_call(req_opts, 0)
  end

  @doc "Batch multiple RPC calls."
  def batch(calls, opts \\ []) do
    rpc_url = opts[:rpc_url] || raise "RPC URL required"

    body = Enum.with_index(calls, 1) |> Enum.map(fn {{method, params}, id} ->
      %{jsonrpc: "2.0", id: id, method: method, params: params}
    end)

    req_opts = [url: rpc_url, method: :post, json: body, retry: false]
    req_opts = if opts[:plug], do: Keyword.put(req_opts, :plug, opts[:plug]), else: req_opts

    case Req.request(req_opts) do
      {:ok, %{status: 200, body: results}} when is_list(results) ->
        parsed = Enum.map(results, fn
          %{"result" => result} -> {:ok, result}
          %{"error" => error} -> {:error, error}
        end)
        {:ok, parsed}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_call(req_opts, attempt) do
    case Req.request(req_opts) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:error, error}

      {:ok, %{status: 429}} when attempt < @max_retries ->
        Process.sleep(@retry_delay_ms * (attempt + 1))
        do_call(req_opts, attempt + 1)

      {:ok, %{status: status}} when status >= 500 and attempt < @max_retries ->
        Process.sleep(@retry_delay_ms * (attempt + 1))
        do_call(req_opts, attempt + 1)

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, _reason} when attempt < @max_retries ->
        Process.sleep(@retry_delay_ms * (attempt + 1))
        do_call(req_opts, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
