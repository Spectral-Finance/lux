defmodule Lux.Web3.MultiChain.RPCClient do
  @moduledoc """
  JSON-RPC client for EVM-compatible chains.
  """

  require Logger

  alias Lux.Web3.MultiChain.ChainRegistry

  @type rpc_result :: {:ok, term()} | {:error, term()}

  @doc """
  Calls one JSON-RPC method on a configured chain.
  """
  @spec call(atom() | String.t() | integer(), String.t(), list(), keyword() | map()) :: rpc_result()
  def call(chain, method, params \\ [], opts \\ %{}) do
    with {:ok, rpc_url} <- ChainRegistry.rpc_url(chain, opts) do
      request_with_retry(rpc_url, method, params, opts, 0)
    end
  end

  @doc """
  Calls a JSON-RPC batch on one configured chain.
  """
  @spec batch(atom() | String.t() | integer(), [{String.t(), list()}], keyword() | map()) :: rpc_result()
  def batch(chain, calls, opts \\ %{}) do
    with {:ok, rpc_url} <- ChainRegistry.rpc_url(chain, opts) do
      payload =
        calls
        |> Enum.with_index(1)
        |> Enum.map(fn {{method, params}, id} -> request_body(method, params, id) end)

      request_with_retry(rpc_url, payload, opts, 0)
    end
  end

  defp request_with_retry(rpc_url, method, params, opts, attempt) do
    request_with_retry(rpc_url, request_body(method, params, 1), opts, attempt)
  end

  defp request_with_retry(rpc_url, payload, opts, attempt) do
    case do_request(rpc_url, payload, opts) do
      {:ok, %{status: status}} = response when status in [408, 425, 429, 500, 502, 503, 504] ->
        maybe_retry(response, rpc_url, payload, opts, attempt)

      response ->
        normalize_response(response)
    end
  end

  defp maybe_retry(response, rpc_url, payload, opts, attempt) do
    if attempt < option(opts, :max_retries, 2) do
      delay_ms = retry_delay_ms(response, attempt, option(opts, :retry_base_delay_ms, 500))

      Logger.debug("Retrying EVM RPC request after #{delay_ms}ms",
        status: elem(response, 1).status,
        attempt: attempt + 1
      )

      sleep(opts).(delay_ms)
      request_with_retry(rpc_url, payload, opts, attempt + 1)
    else
      normalize_response(response)
    end
  end

  defp do_request(rpc_url, payload, opts) do
    [
      method: :post,
      url: rpc_url,
      headers: [{"Content-Type", "application/json"}],
      json: payload
    ]
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
  end

  defp normalize_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    case body do
      %{"result" => result} -> {:ok, result}
      %{"error" => error} -> {:error, {:rpc_error, error}}
      responses when is_list(responses) -> normalize_batch(responses)
      other -> {:error, {:invalid_rpc_response, other}}
    end
  end

  defp normalize_response({:ok, %{status: status, body: body}}), do: {:error, {:http_error, status, body}}
  defp normalize_response({:error, error}), do: {:error, error}

  defp normalize_batch(responses) do
    errors = Enum.filter(responses, &Map.has_key?(&1, "error"))

    if errors == [] do
      {:ok, Enum.map(responses, &Map.get(&1, "result"))}
    else
      {:error, {:rpc_batch_error, errors}}
    end
  end

  defp request_body(method, params, id) do
    %{jsonrpc: "2.0", id: id, method: method, params: params}
  end

  defp retry_delay_ms({:ok, %{headers: headers}}, attempt, base_delay_ms) do
    retry_after_ms(headers) || base_delay_ms * Integer.pow(2, attempt)
  end

  defp retry_after_ms(headers) when is_map(headers), do: headers |> Map.to_list() |> retry_after_ms()

  defp retry_after_ms(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) == "retry-after", do: value

      _ ->
        nil
    end)
    |> seconds_to_ms()
  end

  defp retry_after_ms(_headers), do: nil
  defp seconds_to_ms(value) when is_integer(value) and value >= 0, do: value * 1000
  defp seconds_to_ms(value) when is_list(value), do: value |> List.first() |> seconds_to_ms()

  defp seconds_to_ms(value) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, ""} when seconds >= 0 -> seconds * 1000
      _ -> nil
    end
  end

  defp seconds_to_ms(_value), do: nil

  defp option(opts, key, default) do
    case opts[key] do
      nil -> default
      value -> value
    end
  end

  defp sleep(opts), do: option(opts, :sleep, &Process.sleep/1)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
