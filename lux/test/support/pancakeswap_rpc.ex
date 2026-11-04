defmodule Test.Support.PancakeSwapRpc do
  @moduledoc """
  Helpers to mock the PancakeSwap JSON-RPC endpoint in unit tests.

  Responses are keyed by function signature. A value is one of:

    * `{output_types, values}` - ABI encoded and returned as the `eth_call` result
    * `{:error, code, message}` - returned as a JSON-RPC error
    * a 1-arity function receiving the request calldata (hex) and returning one of the above

  `eth_gasPrice` can be stubbed with the key `"eth_gasPrice"` and a hex string value.
  Unknown selectors answer with a JSON-RPC "execution reverted" error.

  The handler runs in the test process, so every `eth_call` is also sent to it as
  `{:rpc_call, to, calldata}`.
  """

  alias Lux.Integrations.PancakeSwap.Codec

  @mock PancakeSwapClientMock

  @doc """
  Stubs the RPC endpoint with the given responses (all hosts).
  """
  def stub(responses) do
    table = compile(responses)
    Req.Test.stub(@mock, fn conn -> reply(conn, table) end)
  end

  @doc """
  Stubs the RPC endpoint with a different response table per request host.

  Hosts that are not listed fail with a transport error.
  """
  def stub_hosts(by_host) do
    tables = Map.new(by_host, fn {host, responses} -> {host, compile(responses)} end)

    Req.Test.stub(@mock, fn conn ->
      case Map.fetch(tables, conn.host) do
        {:ok, table} -> reply(conn, table)
        :error -> Req.Test.transport_error(conn, :econnrefused)
      end
    end)
  end

  @doc """
  Hex calldata for a call, as produced by the prisms.
  """
  def calldata(signature, args) do
    signature |> Codec.encode_call(args) |> Codec.to_hex()
  end

  @doc """
  Sends a JSON response with the given status.
  """
  def json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end

  defp compile(responses) do
    Map.new(responses, fn
      {"eth_gasPrice" = key, value} -> {key, value}
      {signature, value} -> {Codec.to_hex(Codec.selector(signature)), value}
    end)
  end

  defp reply(conn, table) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    request = Jason.decode!(body)

    case request["method"] do
      "eth_call" ->
        [%{"to" => to, "data" => data}, "latest"] = request["params"]
        send(self(), {:rpc_call, to, data})
        eth_call_reply(conn, request, table, data)

      "eth_gasPrice" ->
        case Map.fetch(table, "eth_gasPrice") do
          {:ok, price} -> json(conn, 200, %{jsonrpc: "2.0", id: request["id"], result: price})
          :error -> error(conn, request, -32_601, "method not stubbed")
        end

      other ->
        error(conn, request, -32_601, "unsupported method #{other}")
    end
  end

  defp eth_call_reply(conn, request, table, data) do
    selector = String.slice(data, 0, 10)

    case Map.fetch(table, selector) do
      {:ok, value} -> respond(conn, request, resolve(value, data))
      :error -> error(conn, request, -32_000, "execution reverted")
    end
  end

  defp resolve(fun, data) when is_function(fun, 1), do: fun.(data)
  defp resolve(value, _data), do: value

  defp respond(conn, request, {:error, code, message}), do: error(conn, request, code, message)

  defp respond(conn, request, {types, values}) do
    result = types |> Codec.encode_args(values) |> Codec.to_hex()
    json(conn, 200, %{jsonrpc: "2.0", id: request["id"], result: result})
  end

  defp error(conn, request, code, message) do
    json(conn, 200, %{jsonrpc: "2.0", id: request["id"], error: %{code: code, message: message}})
  end
end
