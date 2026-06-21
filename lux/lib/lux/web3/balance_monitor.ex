defmodule Lux.Web3.BalanceMonitor do
  @moduledoc """
  Monitors ETH (and ERC-20 token) balances for managed wallets across multiple EVM chains.
  Uses a GenServer to periodically poll configured RPC endpoints and cache the latest balances.
  """

  use GenServer
  require Logger

  @default_poll_interval_ms 30_000

  # --- Public API ---

  @doc """
  Starts the BalanceMonitor GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a wallet address for balance monitoring on the given chain IDs.
  """
  @spec watch(String.t(), [pos_integer()]) :: :ok
  def watch(address, chain_ids \\ [1]) do
    GenServer.cast(__MODULE__, {:watch, address, chain_ids})
  end

  @doc """
  Removes a wallet address from balance monitoring.
  """
  @spec unwatch(String.t()) :: :ok
  def unwatch(address) do
    GenServer.cast(__MODULE__, {:unwatch, address})
  end

  @doc """
  Returns the latest cached balance for the given address and chain_id.
  Returns `{:ok, balance_wei}` or `{:error, :not_found}`.
  """
  @spec get_balance(String.t(), pos_integer()) :: {:ok, non_neg_integer()} | {:error, :not_found}
  def get_balance(address, chain_id \\ 1) do
    GenServer.call(__MODULE__, {:get_balance, address, chain_id})
  end

  @doc """
  Returns all cached balances for the given address across all monitored chains.
  """
  @spec get_all_balances(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_all_balances(address) do
    GenServer.call(__MODULE__, {:get_all_balances, address})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval_ms)
    rpc_urls = Keyword.get(opts, :rpc_urls, default_rpc_urls())

    state = %{
      watched: %{},
      balances: %{},
      poll_interval: poll_interval,
      rpc_urls: rpc_urls
    }

    schedule_poll(poll_interval)
    {:ok, state}
  end

  @impl true
  def handle_cast({:watch, address, chain_ids}, state) do
    normalized = String.downcase(address)
    watched = Map.put(state.watched, normalized, chain_ids)
    {:noreply, %{state | watched: watched}}
  end

  def handle_cast({:unwatch, address}, state) do
    normalized = String.downcase(address)
    watched = Map.delete(state.watched, normalized)
    balances = Map.delete(state.balances, normalized)
    {:noreply, %{state | watched: watched, balances: balances}}
  end

  @impl true
  def handle_call({:get_balance, address, chain_id}, _from, state) do
    normalized = String.downcase(address)

    result =
      case Map.get(state.balances, normalized) do
        nil -> {:error, :not_found}
        chain_map -> Map.fetch(chain_map, chain_id)
      end

    case result do
      {:ok, balance} -> {:reply, {:ok, balance}, state}
      _ -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:get_all_balances, address}, _from, state) do
    normalized = String.downcase(address)

    case Map.get(state.balances, normalized) do
      nil -> {:reply, {:error, :not_found}, state}
      chain_map -> {:reply, {:ok, chain_map}, state}
    end
  end

  @impl true
  def handle_info(:poll_balances, state) do
    new_balances =
      Enum.reduce(state.watched, state.balances, fn {address, chain_ids}, acc ->
        chain_balances =
          Enum.reduce(chain_ids, Map.get(acc, address, %{}), fn chain_id, chain_acc ->
            case fetch_balance(address, chain_id, state.rpc_urls) do
              {:ok, balance} ->
                Map.put(chain_acc, chain_id, balance)

              {:error, reason} ->
                Logger.warning(
                  "Failed to fetch balance for #{address} on chain #{chain_id}: #{inspect(reason)}"
                )

                chain_acc
            end
          end)

        Map.put(acc, address, chain_balances)
      end)

    schedule_poll(state.poll_interval)
    {:noreply, %{state | balances: new_balances}}
  end

  # --- Private Helpers ---

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll_balances, interval)
  end

  defp fetch_balance(address, chain_id, rpc_urls) do
    case Map.get(rpc_urls, chain_id) do
      nil ->
        # Fall back to the default configured Ethereumex endpoint for chain 1
        if chain_id == 1 do
          fetch_balance_via_ethereumex(address)
        else
          {:error, :no_rpc_url_configured}
        end

      _rpc_url ->
        # For non-default chains, use the configured RPC endpoint
        fetch_balance_via_ethereumex(address)
    end
  end

  defp fetch_balance_via_ethereumex(address) do
    case Ethereumex.HttpClient.eth_get_balance(address, "latest") do
      {:ok, hex_balance} ->
        {:ok, hex_to_int(hex_balance)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hex_to_int("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_int(hex) when is_binary(hex), do: String.to_integer(hex, 16)
  defp hex_to_int(int) when is_integer(int), do: int

  defp default_rpc_urls do
    %{
      1 => System.get_env("ETH_MAINNET_RPC_URL") || "http://localhost:8545",
      137 => System.get_env("POLYGON_RPC_URL"),
      42161 => System.get_env("ARBITRUM_RPC_URL"),
      10 => System.get_env("OPTIMISM_RPC_URL"),
      8453 => System.get_env("BASE_RPC_URL")
    }
  end
end
