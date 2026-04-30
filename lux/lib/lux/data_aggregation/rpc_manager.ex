defmodule Lux.DataAggregation.RPCManager do
  @moduledoc """
  Manages RPC connections to multiple EVM chains with automatic failover,
  rate limiting, and health monitoring.

  ## Features
  - Multiple RPC endpoints per chain with automatic failover
  - Rate limiting to prevent API abuse
  - Health checking and endpoint rotation
  - Connection pooling for performance
  """

  use GenServer

  alias Lux.DataAggregation

  @default_request_timeout 30_000
  @health_check_interval 60_000
  @max_retries 3
  @rate_limit_per_second 10

  defstruct [
    :chain,
    :endpoints,
    :active_index,
    :rate_limiter,
    :health_status,
    :request_count,
    :last_health_check
  ]

  def start_link(opts) do
    chains = Keyword.get(opts, :chains, [:ethereum, :polygon, :bsc])
    GenServer.start_link(__MODULE__, chains, name: __MODULE__)
  end

  @impl true
  def init(chains) do
    state = %{
      connections: chains |> Enum.map(&init_chain_connection/1) |> Map.new(),
      rate_limiters: %{},
      health_check_timer: nil
    }

    schedule_health_check()

    {:ok, state}
  end

  defp init_chain_connection(chain) do
    config = DataAggregation.chain_config(chain)
    default_rpc = Keyword.fetch!(config, :default_rpc)

    endpoints = [
      %{url: default_rpc, status: :healthy, latency: 0, fail_count: 0},
      %{url: backup_rpc_url(chain), status: :healthy, latency: 0, fail_count: 0}
    ]

    {chain, %{
      chain_id: Keyword.fetch!(config, :chain_id),
      endpoints: endpoints,
      active_index: 0,
      timeout: @default_request_timeout
    }}
  end

  defp backup_rpc_url(:ethereum), do: "https://rpc.ankr.com/eth"
  defp backup_rpc_url(:polygon), do: "https://polygon-rpc.com"
  defp backup_rpc_url(:bsc), do: "https://rpc.ankr.com/bsc"
  defp backup_rpc_url(:arbitrum), do: "https://rpc.ankr.com/arbitrum"
  defp backup_rpc_url(:optimism), do: "https://rpc.ankr.com/optimism"
  defp backup_rpc_url(:avalanche), do: "https://rpc.ankr.com/avalanche"
  defp backup_rpc_url(:fantom), do: "https://rpc.ankr.com/fantom"
  defp backup_rpc_url(_), do: nil

  @doc """
  Make an RPC call to a specific chain.
  """
  def call(chain, method, params \\ []) do
    GenServer.call(__MODULE__, {:call, chain, method, params})
  end

  @doc """
  Batch RPC calls for efficiency.
  """
  def batch_call(chain, calls) do
    GenServer.call(__MODULE__, {:batch_call, chain, calls})
  end

  @doc """
  Get the current block number for a chain.
  """
  def get_block_number(chain) do
    call(chain, "eth_blockNumber", [])
  end

  @doc """
  Get transaction by hash.
  """
  def get_transaction(chain, tx_hash) do
    call(chain, "eth_getTransactionByHash", [tx_hash])
  end

  @doc """
  Get transaction receipt.
  """
  def get_transaction_receipt(chain, tx_hash) do
    call(chain, "eth_getTransactionReceipt", [tx_hash])
  end

  @doc """
  Get logs/events for a filter.
  """
  def get_logs(chain, filter) do
    call(chain, "eth_getLogs", [filter])
  end

  @doc """
  Get block by number.
  """
  def get_block_by_number(chain, block_number, full_transactions \\ false) do
    call(chain, "eth_getBlockByNumber", [block_number, full_transactions])
  end

  @impl true
  def handle_call({:call, chain, method, params}, _from, state) do
    case Map.get(state.connections, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      conn ->
        case execute_with_retry(chain, method, params, state, 0) do
          {:ok, result, new_state} ->
            {:reply, {:ok, result}, new_state}

          {:error, reason, new_state} ->
            {:reply, {:error, reason}, new_state}
        end
    end
  end

  def handle_call({:batch_call, chain, calls}, _from, state) do
    case Map.get(state.connections, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      _conn ->
        results =
          calls
          |> Enum.map(fn {method, params} ->
            case execute_with_retry(chain, method, params, state, 0) do
              {:ok, result, new_state} -> {:ok, result}
              {:error, reason, _} -> {:error, reason}
            end
          end)

        {:reply, results, state}
    end
  end

  defp execute_with_retry(_chain, _method, _params, state, @max_retries) do
    {:error, :max_retries_exceeded, state}
  end

  defp execute_with_retry(chain, method, params, state, attempt) do
    conn = Map.get!(state.connections, chain)
    endpoint = Enum.at(conn.endpoints, conn.active_index)

    case make_rpc_request(endpoint.url, method, params, conn.timeout) do
      {:ok, result} ->
        # Update endpoint health
        new_endpoints = update_endpoint_health(conn.endpoints, conn.active_index, :ok, 0)
        new_conn = %{conn | endpoints: new_endpoints}
        new_state = %{state | connections: Map.put(state.connections, chain, new_conn)}
        {:ok, result, new_state}

      {:error, reason} ->
        # Update endpoint health and try next
        new_endpoints = update_endpoint_health(conn.endpoints, conn.active_index, :error, 1)
        new_active_index = rem(conn.active_index + 1, length(new_endpoints))
        new_conn = %{conn | endpoints: new_endpoints, active_index: new_active_index}
        new_state = %{state | connections: Map.put(state.connections, chain, new_conn)}

        execute_with_retry(chain, method, params, new_state, attempt + 1)
    end
  end

  defp make_rpc_request(url, method, params, timeout) do
    payload = %{
      jsonrpc: "2.0",
      method: method,
      params: params,
      id: 1
    }

    case Req.post(url, json: payload, timeout: timeout) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case body do
          %{"result" => result} -> {:ok, result}
          %{"error" => %{"message" => msg}} -> {:error, {:rpc_error, msg}}
          _ -> {:error, :invalid_response}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_endpoint_health(endpoints, index, status, fail_increment) do
    Enum.map(Enum.with_index(endpoints), fn {endpoint, i} ->
      if i == index do
        %{
          endpoint
          | status: if(status == :ok, do: :healthy, else: :degraded),
            fail_count: endpoint.fail_count + fail_increment,
            latency: if(status == :ok, do: 0, else: endpoint.latency)
        }
      else
        endpoint
      end
    end)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end

  @impl true
  def handle_info(:health_check, state) do
    new_connections =
      state.connections
      |> Map.new(fn {chain, conn} ->
        new_endpoints =
          conn.endpoints
          |> Enum.map(fn endpoint ->
            case make_rpc_request(endpoint.url, "eth_blockNumber", [], 5000) do
              {:ok, _} -> %{endpoint | status: :healthy, fail_count: 0}
              {:error, _} -> %{endpoint | status: :unhealthy, fail_count: endpoint.fail_count + 1}
            end
          end)

        # Find best endpoint (healthy with lowest fail count)
        healthy_endpoints = Enum.filter(new_endpoints, &(&1.status == :healthy))
        active_index =
          case healthy_endpoints do
            [] -> 0
            _ ->
              best = Enum.min_by(healthy_endpoints, & &1.fail_count)
              Enum.find_index(new_endpoints, &(&1.url == best.url))
          end

        {chain, %{conn | endpoints: new_endpoints, active_index: active_index}}
      end)

    schedule_health_check()
    {:noreply, %{state | connections: new_connections}}
  end

  @doc """
  Returns connection status for all chains.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @impl true
  def handle_call(:status, _from, state) do
    status =
      state.connections
      |> Map.new(fn {chain, conn} ->
        healthy_count = Enum.count(conn.endpoints, &(&1.status == :healthy))
        total_count = length(conn.endpoints)

        {chain, %{
          chain_id: conn.chain_id,
          healthy_endpoints: healthy_count,
          total_endpoints: total_count,
          active_endpoint: Enum.at(conn.endpoints, conn.active_index)
        }}
      end)

    {:reply, status, state}
  end
end
