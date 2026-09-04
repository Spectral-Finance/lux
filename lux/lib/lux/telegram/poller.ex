defmodule Lux.Telegram.Poller do
  @moduledoc """
  GenServer implementation for long-polling Telegram Bot API updates.
  Tracks update `offset` and dispatches `Lux.Signals.TelegramUpdate` signals.
  """

  use GenServer
  require Logger

  defmodule State do
    @moduledoc false
    defstruct [
      :token,
      :client,
      :offset,
      :timeout,
      :poll_interval,
      :allowed_updates,
      :handler,
      :plug,
      :autostart,
      :consecutive_errors,
      :backoff_delay
    ]
  end

  @doc """
  Starts the Telegram updates Poller GenServer.

  ## Options
    * `:token` - Telegram bot API token
    * `:client` - Client module or struct (default `Lux.Telegram.Client`)
    * `:offset` - Starting update offset (default 0)
    * `:timeout` - Long polling timeout in seconds (default 30)
    * `:poll_interval` - Delay between poll requests in ms (default 1000)
    * `:allowed_updates` - Optional list of allowed update types
    * `:handler` - Callback function `(signal -> term)`, PID, or module to receive updates
    * `:plug` - Req plug for testing
    * `:autostart` - Boolean indicating whether polling loop starts automatically (default true)
    * `:name` - GenServer process registration name
  """
  def start_link(opts \\ %{}) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}
    gen_opts = if name = opts_map[:name], do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts_map, gen_opts)
  end

  @doc """
  Triggers a single poll operation synchronously. Returns `{:ok, signals}` or `{:error, reason}`.
  """
  def poll_once(pid_or_name) do
    GenServer.call(pid_or_name, :poll_once)
  end

  @doc """
  Retrieves the current update offset.
  """
  def get_offset(pid_or_name) do
    GenServer.call(pid_or_name, :get_offset)
  end

  @doc """
  Manually updates the update offset in Poller state.
  """
  def set_offset(pid_or_name, new_offset) when is_integer(new_offset) do
    GenServer.call(pid_or_name, {:set_offset, new_offset})
  end

  @doc """
  Stops the poller process.
  """
  def stop(pid_or_name) do
    GenServer.stop(pid_or_name)
  end

  @impl true
  def init(opts_map) do
    token = Lux.Integrations.Telegram.fetch_token(opts_map)
    offset = Map.get(opts_map, :offset, 0)
    handler = Map.get(opts_map, :handler)
    timeout = Map.get(opts_map, :timeout, 30)
    poll_interval = Map.get(opts_map, :poll_interval, 1000)
    allowed_updates = Map.get(opts_map, :allowed_updates)
    plug = Map.get(opts_map, :plug)
    client = Map.get(opts_map, :client, Lux.Telegram.Client)
    autostart = Map.get(opts_map, :autostart, true)
    consecutive_errors = Map.get(opts_map, :consecutive_errors, 0)
    backoff_delay = Map.get(opts_map, :backoff_delay, 0)

    state = %State{
      token: token,
      client: client,
      offset: offset,
      timeout: timeout,
      poll_interval: poll_interval,
      allowed_updates: allowed_updates,
      handler: handler,
      plug: plug,
      autostart: autostart,
      consecutive_errors: consecutive_errors,
      backoff_delay: backoff_delay
    }

    if autostart do
      send(self(), :poll)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:poll_once, _from, state) do
    case do_poll(state) do
      {:ok, signals, new_state} ->
        {:reply, {:ok, signals}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  def handle_call(:get_offset, _from, state) do
    {:reply, state.offset, state}
  end

  def handle_call({:set_offset, new_offset}, _from, state) do
    {:reply, :ok, %{state | offset: new_offset}}
  end

  @impl true
  def handle_info(:poll, state) do
    case do_poll(state) do
      {:ok, _signals, new_state} ->
        schedule_next_poll(new_state, new_state.poll_interval)
        {:noreply, new_state}

      {:error, :invalid_token, new_state} ->
        {:noreply, %{new_state | autostart: false}}

      {:error, {_status, _reason}, new_state} ->
        schedule_next_poll(new_state, new_state.backoff_delay)
        {:noreply, new_state}

      {:error, _reason, new_state} ->
        schedule_next_poll(new_state, new_state.backoff_delay)
        {:noreply, new_state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_next_poll(%State{autostart: true}, delay) when is_integer(delay) and delay >= 0 do
    Process.send_after(self(), :poll, delay)
  end

  defp schedule_next_poll(_state, _delay), do: :ok

  defp do_poll(state) do
    json_params =
      %{offset: state.offset, timeout: state.timeout}
      |> then(fn map ->
        if state.allowed_updates, do: Map.put(map, :allowed_updates, state.allowed_updates), else: map
      end)

    client_opts =
      [
        token: state.token,
        timeout: state.timeout,
        offset: state.offset,
        allowed_updates: state.allowed_updates,
        plug: state.plug,
        json: json_params,
        max_retries: 0,
        max_rate_limit_retries: 0
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    response =
      cond do
        is_struct(state.client, Lux.Telegram.Client) ->
          Lux.Telegram.Client.request(state.client, :post, "/getUpdates", client_opts)

        is_atom(state.client) and function_exported?(state.client, :request, 3) ->
          state.client.request(:post, "/getUpdates", client_opts)

        is_atom(state.client) and function_exported?(state.client, :request, 4) ->
          state.client.request(state.client, :post, "/getUpdates", client_opts)

        true ->
          Lux.Telegram.Client.request(:post, "/getUpdates", client_opts)
      end

    case response do
      {:ok, %{"ok" => true, "result" => updates}} when is_list(updates) ->
        case process_updates(updates, state.offset, state.handler) do
          {:ok, signals, new_offset} ->
            new_state = %{state | offset: new_offset, consecutive_errors: 0, backoff_delay: 0}
            {:ok, signals, new_state}

          {:error, reason, _signals, unadvanced_offset} ->
            consecutive = state.consecutive_errors + 1
            backoff_ms = calculate_backoff(consecutive)
            new_state = %{state | offset: unadvanced_offset, consecutive_errors: consecutive, backoff_delay: backoff_ms}
            {:error, {:handler_error, reason}, new_state}
        end

      {:ok, %{"ok" => true, "result" => _other}} ->
        consecutive = state.consecutive_errors + 1
        backoff_ms = calculate_backoff(consecutive)
        Logger.warning("Telegram Poller received malformed updates list.")
        {:error, :malformed_response, %{state | consecutive_errors: consecutive, backoff_delay: backoff_ms}}

      {:ok, %{"ok" => false, "error_code" => 401}} ->
        Logger.error("Invalid Telegram bot token. Polling halted.")
        {:error, :invalid_token, %{state | autostart: false}}

      {:ok, %{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}}} ->
        backoff_ms = retry_after * 1000
        consecutive = state.consecutive_errors + 1
        Logger.warning("Telegram Poller rate limited (429). Retrying in #{retry_after}s.")
        {:error, {429, retry_after}, %{state | consecutive_errors: consecutive, backoff_delay: backoff_ms}}

      {:ok, %{"ok" => false, "description" => desc} = body} ->
        consecutive = state.consecutive_errors + 1
        backoff_ms = calculate_backoff(consecutive)
        Logger.warning("Telegram Poller API error: #{desc}")
        {:error, body, %{state | consecutive_errors: consecutive, backoff_delay: backoff_ms}}

      {:error, :invalid_token} ->
        Logger.error("Invalid Telegram bot token. Polling halted.")
        {:error, :invalid_token, %{state | autostart: false}}

      {:error, {401, _desc}} ->
        Logger.error("Invalid Telegram bot token. Polling halted.")
        {:error, :invalid_token, %{state | autostart: false}}

      {:error, {429, desc}} ->
        retry_after = extract_retry_after(desc)
        consecutive = state.consecutive_errors + 1
        backoff_ms = calculate_backoff(consecutive, retry_after)
        Logger.warning("Telegram Poller rate limited (429): #{inspect(desc)}. Retrying in #{backoff_ms}ms.")
        {:error, {429, retry_after || 5}, %{state | consecutive_errors: consecutive, backoff_delay: backoff_ms}}

      {:error, reason} ->
        consecutive = state.consecutive_errors + 1
        backoff_ms = calculate_backoff(consecutive)
        Logger.warning("Telegram Poller network error: #{inspect(reason)}")
        {:error, reason, %{state | consecutive_errors: consecutive, backoff_delay: backoff_ms}}
    end
  end

  defp calculate_backoff(consecutive_errors, retry_after_sec \\ nil) do
    retry_sec =
      cond do
        is_integer(retry_after_sec) and retry_after_sec > 0 -> retry_after_sec
        is_float(retry_after_sec) and retry_after_sec > 0 -> trunc(retry_after_sec)
        is_binary(retry_after_sec) ->
          case Integer.parse(retry_after_sec) do
            {sec, _} when sec > 0 -> sec
            _ -> nil
          end
        true -> nil
      end

    if retry_sec do
      retry_sec * 1000
    else
      exponent = min(consecutive_errors, 5)

      trunc(:math.pow(2, exponent) * 1000)
      |> min(30_000)
    end
  end

  defp extract_retry_after(desc) when is_map(desc) do
    get_in(desc, ["parameters", "retry_after"]) ||
      get_in(desc, [:parameters, :retry_after]) ||
      get_in(desc, ["parameters", :retry_after]) ||
      get_in(desc, [:parameters, "retry_after"]) ||
      desc["retry_after"] ||
      desc[:retry_after]
  end

  defp extract_retry_after(desc) when is_binary(desc) do
    case Regex.run(~r/retry after (\d+)/i, desc) do
      [_, sec] -> String.to_integer(sec)
      _ -> nil
    end
  end

  defp extract_retry_after(_), do: nil

  defp process_updates(updates, current_offset, handler) do
    Enum.reduce_while(updates, {[], current_offset}, fn
      update, {signals_acc, max_offset} when is_map(update) ->
        raw_id = update["update_id"] || update[:update_id]

        update_id =
          cond do
            is_integer(raw_id) and raw_id >= 0 -> raw_id
            is_binary(raw_id) ->
              case Integer.parse(raw_id) do
                {num, _} when num >= 0 -> num
                _ -> nil
              end
            true -> nil
          end

        next_offset =
          if update_id do
            max(max_offset, update_id + 1)
          else
            max_offset
          end

        case Lux.Signals.TelegramUpdate.new(update) do
          {:ok, %Lux.Signal{} = signal} ->
            case dispatch_signal(signal, handler) do
              :ok ->
                {:cont, {[signal | signals_acc], next_offset}}

              {:error, reason} ->
                Logger.error(
                  "Poller handler failed on update #{inspect(update_id)}: #{inspect(reason)}"
                )
                {:halt, {:error, reason, signals_acc, max_offset}}
            end

          {:error, reason} ->
            Logger.warning(
              "Telegram Poller dropping invalid update (id: #{inspect(update_id)}): #{inspect(reason)}"
            )
            {:cont, {signals_acc, next_offset}}
        end

      invalid_item, {signals_acc, max_offset} ->
        Logger.warning("Telegram Poller received non-map update item: #{inspect(invalid_item)}")
        {:cont, {signals_acc, max_offset}}
    end)
    |> case do
      {:error, reason, signals_acc, unadvanced_offset} ->
        {:error, reason, Enum.reverse(signals_acc), unadvanced_offset}

      {signals_acc, final_offset} ->
        {:ok, Enum.reverse(signals_acc), final_offset}
    end
  end

  defp dispatch_signal(signal, handler) do
    try do
      result =
        cond do
          is_function(handler, 1) ->
            handler.(signal)

          is_pid(handler) ->
            send(handler, {:telegram_update, signal})
            :ok

          is_atom(handler) and handler != nil ->
            cond do
              Code.ensure_loaded?(handler) and function_exported?(handler, :handle_signal, 1) ->
                handler.handle_signal(signal)

              Code.ensure_loaded?(handler) and function_exported?(handler, :handle_update, 1) ->
                handler.handle_update(signal)

              true ->
                :ok
            end

          true ->
            :ok
        end

      case result do
        {:error, reason} ->
          Logger.error("Poller handler returned error: #{inspect(reason)}")
          {:error, reason}

        :error ->
          Logger.error("Poller handler returned :error")
          {:error, :handler_error}

        _ ->
          :ok
      end
    rescue
      e ->
        Logger.error("Poller handler error: #{inspect(e)}")
        {:error, {:handler_exception, e}}
    catch
      :throw, value ->
        Logger.error("Poller handler threw: #{inspect(value)}")
        {:error, {:handler_throw, value}}

      :exit, reason ->
        Logger.error("Poller handler exited: #{inspect(reason)}")
        {:error, {:handler_exit, reason}}

      kind, reason ->
        Logger.error("Poller handler #{kind}: #{inspect(reason)}")
        {:error, {:handler_crash, {kind, reason}}}
    end
  end
end
