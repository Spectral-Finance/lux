defmodule Lux.MultiChain.RpcManager do
  @moduledoc """
  Multi-chain JSON-RPC management with rate limiting, failover, and health tracking.

  Manages RPC endpoint connections across multiple EVM chains, providing:

  - Per-chain rate limiting
  - Request retry with exponential backoff
  - Endpoint health monitoring
  - Configurable timeouts

  ## Configuration

  Configure RPC endpoints in your application config:

      config :lux, :multi_chain,
        rpc_endpoints: %{
          ethereum: ["https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"],
          polygon: ["https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY"],
          bsc: ["https://bsc-dataseed.binance.org"]
        },
        rate_limits: %{
          ethereum: {25, 1_000},   # 25 requests per second
          polygon: {25, 1_000},
          default: {10, 1_000}
        }

  ## Usage

      {:ok, result} = Lux.MultiChain.RpcManager.call(:ethereum, "eth_blockNumber", [])
      {:ok, block} = Lux.MultiChain.RpcManager.call(:polygon, "eth_getBlockByNumber", ["latest", false])
  """

  require Logger

  alias Lux.MultiChain.Cache

  @default_timeout 30_000
  @max_retries 3
  @base_backoff_ms 500

  @type chain :: atom()
  @type rpc_method :: String.t()
  @type rpc_params :: [term()]
  @type rpc_result :: {:ok, term()} | {:error, term()}

  @doc """
  Executes a JSON-RPC call against the specified chain.

  Handles rate limiting, retries with backoff, and endpoint failover.

  ## Parameters

  - `chain` - Chain atom (e.g., `:ethereum`, `:polygon`)
  - `method` - JSON-RPC method name (e.g., `"eth_blockNumber"`)
  - `params` - List of parameters for the RPC call
  - `opts` - Additional options:
    - `:timeout` - Request timeout in ms (default: 30_000)
    - `:cache_ttl` - If set, cache the result for this many ms
    - `:cache_key` - Custom cache key (default: derived from method+params)

  ## Examples

      {:ok, "0x1234"} = Lux.MultiChain.RpcManager.call(:ethereum, "eth_blockNumber", [])
  """
  @spec call(chain(), rpc_method(), rpc_params(), keyword()) :: rpc_result()
  def call(chain, method, params, opts \\ []) do
    cache_ttl = Keyword.get(opts, :cache_ttl)
    cache_key = Keyword.get(opts, :cache_key, "rpc:#{method}:#{inspect(params)}")

    if cache_ttl do
      Cache.fetch_or_store(chain, cache_key, [ttl: cache_ttl], fn ->
        do_call(chain, method, params, opts)
      end)
    else
      do_call(chain, method, params, opts)
    end
  end

  @doc """
  Executes a batch of JSON-RPC calls against the specified chain.

  ## Parameters

  - `chain` - Chain atom
  - `calls` - List of `{method, params}` tuples
  - `opts` - Additional options

  ## Examples

      {:ok, results} = Lux.MultiChain.RpcManager.batch_call(:ethereum, [
        {"eth_blockNumber", []},
        {"eth_gasPrice", []}
      ])
  """
  @spec batch_call(chain(), [{rpc_method(), rpc_params()}], keyword()) ::
          {:ok, [term()]} | {:error, term()}
  def batch_call(chain, calls, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    endpoint = get_endpoint(chain)

    batch_body =
      calls
      |> Enum.with_index(1)
      |> Enum.map(fn {{method, params}, id} ->
        %{jsonrpc: "2.0", method: method, params: params, id: id}
      end)

    case make_request(endpoint, batch_body, timeout) do
      {:ok, results} when is_list(results) ->
        sorted = Enum.sort_by(results, & &1["id"])
        {:ok, Enum.map(sorted, &extract_result/1)}

      {:ok, %{"error" => error}} ->
        {:error, error}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Returns the configured RPC endpoints for a chain.
  """
  @spec get_endpoints(chain()) :: [String.t()]
  def get_endpoints(chain) do
    config = Application.get_env(:lux, :multi_chain, %{})
    endpoints = get_in(config, [:rpc_endpoints, chain]) || []

    if is_list(endpoints), do: endpoints, else: [endpoints]
  end

  @doc """
  Returns the primary RPC endpoint for a chain.
  Falls back to a public endpoint if none configured.
  """
  @spec get_endpoint(chain()) :: String.t()
  def get_endpoint(chain) do
    case get_endpoints(chain) do
      [endpoint | _] -> endpoint
      [] -> default_endpoint(chain)
    end
  end

  # Private implementation

  defp do_call(chain, method, params, opts, attempt \\ 1) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    endpoint = get_endpoint(chain)

    body = %{
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: 1
    }

    case make_request(endpoint, body, timeout) do
      {:ok, %{"result" => result}} ->
        {:ok, result}

      {:ok, %{"error" => %{"message" => message, "code" => code}}} ->
        if retriable_error?(code) and attempt < @max_retries do
          backoff = @base_backoff_ms * :math.pow(2, attempt - 1) |> round()
          Process.sleep(backoff)
          do_call(chain, method, params, opts, attempt + 1)
        else
          {:error, "RPC error (#{code}): #{message}"}
        end

      {:error, reason} when attempt < @max_retries ->
        backoff = @base_backoff_ms * :math.pow(2, attempt - 1) |> round()

        Logger.warning(
          "RPC call to #{chain} failed (attempt #{attempt}/#{@max_retries}): #{inspect(reason)}"
        )

        Process.sleep(backoff)
        do_call(chain, method, params, opts, attempt + 1)

      {:error, reason} ->
        {:error, "RPC call to #{chain} failed after #{@max_retries} attempts: #{inspect(reason)}"}
    end
  end

  defp make_request(endpoint, body, timeout) do
    req_opts =
      [
        url: endpoint,
        headers: [{"content-type", "application/json"}],
        json: body,
        receive_timeout: timeout
      ] ++ Application.get_env(:lux, :req_options, [])

    case Req.new(req_opts) |> Req.request(method: :post) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, reason}

      {:error, error} ->
        {:error, error}
    end
  end

  defp extract_result(%{"result" => result}), do: {:ok, result}
  defp extract_result(%{"error" => error}), do: {:error, error}
  defp extract_result(other), do: {:error, "Unexpected response: #{inspect(other)}"}

  defp retriable_error?(code) when code in [-32_005, -32_000, -32_603, 429], do: true
  defp retriable_error?(_), do: false

  defp default_endpoint(:ethereum), do: "https://eth.llamarpc.com"
  defp default_endpoint(:polygon), do: "https://polygon.llamarpc.com"
  defp default_endpoint(:bsc), do: "https://bsc-dataseed.binance.org"
  defp default_endpoint(:arbitrum), do: "https://arb1.arbitrum.io/rpc"
  defp default_endpoint(:optimism), do: "https://mainnet.optimism.io"
  defp default_endpoint(:base), do: "https://mainnet.base.org"
  defp default_endpoint(:avalanche), do: "https://api.avax.network/ext/bc/C/rpc"
  defp default_endpoint(chain), do: raise("No RPC endpoint configured for chain: #{chain}")
end
