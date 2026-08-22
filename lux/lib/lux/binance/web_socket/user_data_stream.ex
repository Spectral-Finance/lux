defmodule Lux.Binance.WebSocket.UserDataStream do
  @moduledoc """
  UserDataStream manager for Binance Spot & Futures private WebSocket channels.

  Handles creating, renewing (keep-alive every 30 mins), and closing the `listenKey` required
  for streaming account updates and execution reports.
  """

  use GenServer
  require Logger

  alias Lux.Binance.Client

  @keep_alive_interval 30 * 60 * 1000 # 30 minutes in ms

  defstruct [
    :market_type,
    :listen_key,
    :api_key,
    :testnet?,
    :timer_ref,
    :subscriber,
    :req_options,
    :ws_pid,
    :ws_base_url
  ]

  @doc """
  Starts the UserDataStream GenServer, creating a `listenKey` and scheduling keep-alive updates.

  ## Options
    - `:market_type` - `:spot` (default) or `:futures`.
    - `:api_key` - API key string (required).
    - `:testnet` - Boolean, whether to use testnet (default: `false`).
    - `:subscriber` - PID to receive listenKey updates.
    - `:req_options` - Options passed to HTTP client (e.g. `plug: {Req.Test, ...}`).
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Creates a new `listenKey` for Spot or Futures user data stream.
  """
  @spec create_listen_key(atom(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def create_listen_key(market_type \\ :spot, opts \\ []) do
    path = get_user_data_path(market_type)
    case Client.request(:post, market_type, path, %{}, opts) do
      {:ok, %{"listenKey" => listen_key}} -> {:ok, listen_key}
      {:ok, res} -> {:error, res}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Sends a keep-alive request for an active `listenKey`.
  """
  @spec keep_alive_listen_key(atom(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def keep_alive_listen_key(market_type, listen_key, opts \\ []) do
    path = get_user_data_path(market_type)
    params = %{listenKey: listen_key}
    Client.request(:put, market_type, path, params, opts)
  end

  @doc """
  Closes an active `listenKey`.
  """
  @spec close_listen_key(atom(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def close_listen_key(market_type, listen_key, opts \\ []) do
    path = get_user_data_path(market_type)
    params = %{listenKey: listen_key}
    Client.request(:delete, market_type, path, params, opts)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    market_type = Keyword.get(opts, :market_type, :spot)
    api_key = opts[:api_key]
    testnet? = Keyword.get(opts, :testnet, Keyword.get(opts, :testnet?, false))
    subscriber = opts[:subscriber] || self()
    req_options = opts[:req_options] || []
    ws_base_url = opts[:ws_base_url]

    case create_listen_key(market_type, opts) do
      {:ok, listen_key} ->
        timer_ref = schedule_keep_alive()

        {:ok, ws_pid} = start_ws_client(market_type, listen_key, testnet?, subscriber, ws_base_url)

        state = %__MODULE__{
          market_type: market_type,
          listen_key: listen_key,
          api_key: api_key,
          testnet?: testnet?,
          timer_ref: timer_ref,
          subscriber: subscriber,
          req_options: req_options,
          ws_pid: ws_pid,
          ws_base_url: ws_base_url
        }

        send(subscriber, {:listen_key_created, listen_key})
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to create Binance UserDataStream listenKey: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:keep_alive, state) do
    opts = [api_key: state.api_key, testnet: state.testnet?, req_options: state.req_options]

    new_state =
      case keep_alive_listen_key(state.market_type, state.listen_key, opts) do
        {:ok, _} ->
          Logger.debug("Binance UserDataStream listenKey keep-alive successful: #{state.listen_key}")
          state

        {:error, reason} ->
          Logger.warning("Binance UserDataStream listenKey keep-alive failed: #{inspect(reason)}. Attempting listenKey recreation...")

          case create_listen_key(state.market_type, opts) do
            {:ok, new_listen_key} ->
              Logger.info("Recreated Binance UserDataStream listenKey: #{new_listen_key}")
              
              if state.ws_pid != nil and Process.alive?(state.ws_pid) do
                Process.exit(state.ws_pid, :normal)
              end
              
              {:ok, new_ws_pid} = start_ws_client(state.market_type, new_listen_key, state.testnet?, state.subscriber, state.ws_base_url)
              
              send(state.subscriber, {:listen_key_created, new_listen_key})
              %{state | listen_key: new_listen_key, ws_pid: new_ws_pid}

            {:error, err} ->
              Logger.error("Failed to recreate Binance UserDataStream listenKey: #{inspect(err)}")
              state
          end
      end

    timer_ref = schedule_keep_alive()
    {:noreply, %{new_state | timer_ref: timer_ref}}
  end

  @impl true
  def terminate(_reason, state) do
    if state.ws_pid != nil and Process.alive?(state.ws_pid) do
      Process.exit(state.ws_pid, :normal)
    end
    
    if state.listen_key do
      opts = [api_key: state.api_key, testnet: state.testnet?, req_options: state.req_options]
      close_listen_key(state.market_type, state.listen_key, opts)
    end
    :ok
  end

  # Private helpers

  defp get_user_data_path(:futures), do: "/fapi/v1/listenKey"
  defp get_user_data_path(_), do: "/api/v3/userDataStream"

  defp schedule_keep_alive do
    Process.send_after(self(), :keep_alive, @keep_alive_interval)
  end

  defp start_ws_client(market_type, listen_key, testnet?, subscriber, ws_base_url) do
    base_url = ws_base_url ||
      if market_type == :futures do
        if testnet?, do: "wss://stream.binancefuture.com/ws", else: "wss://fstream.binance.com/ws"
      else
        if testnet?, do: "wss://testnet.binance.vision/ws", else: "wss://stream.binance.com:9443/ws"
      end

    url = "#{base_url}/#{listen_key}"
    Lux.Binance.WebSocket.Client.start_link(
      url: url,
      market_type: market_type,
      testnet: testnet?,
      subscriber: subscriber
    )
  end
end
