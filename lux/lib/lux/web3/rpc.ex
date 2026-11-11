defmodule Lux.Web3.RPC do
  @moduledoc """
  Explicit-endpoint JSON-RPC transport for transaction management.

  Pass `rpc_url: "..."` and optional `req_options: [...]` (for authentication
  headers or a test plug). Requests never retry or follow redirects: an
  ambiguous transaction submission must be reconciled by its hash.
  """

  @doc "Makes one JSON-RPC request and preserves node errors, including revert data."
  @spec request(String.t(), list(), keyword()) :: {:ok, term()} | {:error, term()}
  def request(method, params, opts) do
    case Keyword.get(opts, :rpc_url) do
      url when is_binary(url) and byte_size(url) > 0 ->
        id = System.unique_integer([:positive])

        request_opts =
          opts
          |> Keyword.get(:req_options, [])
          |> Keyword.merge(
            url: url,
            json: %{jsonrpc: "2.0", id: id, method: method, params: params},
            retry: false,
            redirect: false,
            receive_timeout: Keyword.get(opts, :timeout, 15_000)
          )

        request_opts |> Req.post() |> response(id)

      _ ->
        {:error, :rpc_url_required}
    end
  end

  defp response(
         {:ok, %{status: 200, body: %{"jsonrpc" => "2.0", "id" => id, "error" => error}}},
         id
       ),
       do: {:error, {:rpc, error}}

  defp response(
         {:ok, %{status: 200, body: %{"jsonrpc" => "2.0", "id" => id, "result" => result}}},
         id
       ),
       do: {:ok, result}

  defp response({:ok, %{status: status}}, _id) when status != 200,
    do: {:error, {:http_status, status}}

  defp response({:error, error}, _id), do: {:error, {:transport, error}}
  defp response(_, _id), do: {:error, :invalid_rpc_response}
end
