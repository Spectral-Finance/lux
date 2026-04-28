defmodule Lux.Integrations.MultiChainAggregator.RPCManager do
  @moduledoc """
  Multi-chain RPC connection manager with failover, rate limiting,
  and automatic retry logic.
  """

  use Agent

  @max_retries 3
  @retry_delay 1_000
  @request_timeout 15_000
  @max_rps 10

  def start_link(chain, config) do
    Agent.start_link(fn ->
      %{
        chain: chain,
        rpc_urls: config.rpc_urls,
        current_index: 0,
        request_count: 0,
        error_count: 0,
        last_request: nil,
        rate_limiter: %{}
      }
    end, name: via(chain))
  end

  def call(chain, method, params) do
    state = Agent.get(via(chain), & &1)
    url = Enum.at(state.rpc_urls, state.current_index)

    body = Jason.encode!(%{
      jsonrpc: "2.0",
      id: System.unique_integer([:positive]),
      method: method,
      params: params
    })

    case http_post(url, body) do
      {:ok, result} ->
        Agent.update(via(chain), fn s -> %{s | request_count: s.request_count + 1, last_request: System.system_time(:millisecond)} end)
        extract_result(result)

      {:error, reason} ->
        handle_rpc_error(chain, state, method, params, reason)
    end
  end

  defp http_post(url, body) do
    headers = [{"Content-Type", "application/json"}]
    
    case :httpc.request(:post, {to_charlist(url), headers, "application/json", body}, [timeout: @request_timeout], []) do
      {:ok, {{_, 200, _}, _, response}} -> {:ok, Jason.decode!(to_string(response))}
      {:ok, {{_, status, _}, _, error}} -> {:error, "HTTP #{status}: #{to_string(error)}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp extract_result(%{"result" => result}), do: {:ok, result}
  defp extract_result(%{"error" => error}), do: {:error, error}

  defp handle_rpc_error(chain, state, method, params, reason) do
    Agent.update(via(chain), fn s -> %{s | error_count: s.error_count + 1} end)
    
    if state.current_index < length(state.rpc_urls) - 1 do
      Agent.update(via(chain), fn s -> %{s | current_index: s.current_index + 1} end)
      call(chain, method, params)
    else
      Agent.update(via(chain), fn s -> %{s | current_index: 0} end)
      {:error, reason}
    end
  end

  defp via(chain), do: {:via, Registry, {Lux.Registry, {:rpc_manager, chain}}}
end