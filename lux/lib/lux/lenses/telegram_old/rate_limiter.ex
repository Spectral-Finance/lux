defmodule Lux.Lenses.Telegram.RateLimiter do
  @moduledoc """
  Rate limiter for Telegram Bot API requests.

  The Telegram Bot API has rate limits that vary by method:
  - Up to 30 messages per second in general
  - 1 message per second to the same chat
  - 20 messages per minute to the same group

  This module implements rate limiting to ensure these limits are respected.
  """

  require Logger

  # Define rate limit configurations
  @global_limit %{
    name: :telegram_global,
    limit: 30,
    window_ms: 1000
  }

  @chat_limit %{
    # This will be dynamically modified with the chat_id
    name: :telegram_chat,
    limit: 1,
    window_ms: 1000
  }

  @group_limit %{
    # This will be dynamically modified with the chat_id
    name: :telegram_group,
    limit: 20,
    window_ms: 60_000
  }

  # Method-specific rate limits
  @method_limits %{
    # These are examples - adjust based on Telegram's actual limits
    "getUpdates" => %{limit: 100, window_ms: 60_000},
    "sendChatAction" => %{limit: 60, window_ms: 1000}
    # Add more method-specific limits as needed
  }

  @doc """
  Executes a function with rate limiting applied based on the Telegram API limits.

  ## Parameters

  - `params`: The parameters being sent to the Telegram API or a chat_id string
  - `fun`: The function to execute (typically the API call)

  ## Returns

  Returns the result of the function.
  """
  def with_rate_limit(params, fun) when is_binary(params) do
    # If params is a string, treat it as a chat_id
    chat_id = params

    # Apply global rate limit first
    case check_and_update(@global_limit) do
      :ok ->
        # Apply chat-specific rate limit
        chat_config = chat_rate_limit_config(chat_id)

        case check_and_update(chat_config) do
          :ok ->
            # Check if this is a group chat (for group rate limiting)
            group_config = group_rate_limit_config(chat_id)

            case check_and_update(group_config) do
              :ok ->
                fun.()

              {:wait, wait_time} ->
                Logger.debug("Rate limit hit for group #{chat_id}, waiting #{wait_time}ms")
                Process.sleep(wait_time)
                with_rate_limit(chat_id, fun)
            end

          {:wait, wait_time} ->
            Logger.debug("Rate limit hit for chat #{chat_id}, waiting #{wait_time}ms")
            Process.sleep(wait_time)
            with_rate_limit(chat_id, fun)
        end

      {:wait, wait_time} ->
        Logger.debug("Global rate limit hit, waiting #{wait_time}ms")
        Process.sleep(wait_time)
        with_rate_limit(chat_id, fun)
    end
  end

  def with_rate_limit(params, fun) when is_map(params) do
    # Extract method for method-specific rate limiting
    method = Map.get(params, "method") || Map.get(params, :method)

    # Apply method-specific rate limit if applicable
    method_result = if method && Map.has_key?(@method_limits, method) do
      method_config = %{
        name: :"telegram_method_#{method}",
        limit: @method_limits[method].limit,
        window_ms: @method_limits[method].window_ms
      }

      check_and_update(method_config)
    else
      :ok
    end

    case method_result do
      :ok ->
        # Apply global rate limit
        case check_and_update(@global_limit) do
          :ok ->
            # If chat_id is present, also apply chat-specific rate limit
            case Map.get(params, "chat_id") || Map.get(params, :chat_id) do
              nil ->
                # No chat_id, just execute the function
                fun.()

              chat_id ->
                # Apply chat-specific rate limit
                chat_config = chat_rate_limit_config(chat_id)

                case check_and_update(chat_config) do
                  :ok ->
                    # Check if this is a group chat (for group rate limiting)
                    # Since we don't know if it's a group without querying,
                    # we'll just apply the group limit for all chats to be safe
                    group_config = group_rate_limit_config(chat_id)

                    case check_and_update(group_config) do
                      :ok ->
                        fun.()

                      {:wait, wait_time} ->
                        Logger.debug("Rate limit hit for group #{chat_id}, waiting #{wait_time}ms")
                        Process.sleep(wait_time)
                        with_rate_limit(params, fun)
                    end

                  {:wait, wait_time} ->
                    Logger.debug("Rate limit hit for chat #{chat_id}, waiting #{wait_time}ms")
                    Process.sleep(wait_time)
                    with_rate_limit(params, fun)
                end
            end

          {:wait, wait_time} ->
            Logger.debug("Global rate limit hit, waiting #{wait_time}ms")
            Process.sleep(wait_time)
            with_rate_limit(params, fun)
        end

      {:wait, wait_time} ->
        Logger.debug("Method-specific rate limit hit for #{method}, waiting #{wait_time}ms")
        Process.sleep(wait_time)
        with_rate_limit(params, fun)
    end
  end

  @doc """
  Checks if a request can be made and updates the counter.

  Returns `:ok` if the request can be made, or `{:wait, wait_time}` with
  the number of milliseconds to wait before retrying.

  ## Parameters

  - `config`: A map containing:
    - `name`: The name of the rate limited service (atom)
    - `limit`: Maximum number of requests in the time window
    - `window_ms`: Time window in milliseconds
  """
  def check_and_update(config) do
    %{name: name, limit: limit, window_ms: window_ms} = config
    table_name = get_table_name(name)
    init(name)

    now = System.monotonic_time(:millisecond)
    cutoff = now - window_ms

    # Use :ets.update_counter with a default to make the operation more atomic
    try do
      # Clean up old entries - this is still not fully atomic but less critical
      :ets.select_delete(table_name, [{{:_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])

      # Use a transaction to make the count and insert operations atomic
      :ets.transaction(table_name, fn ->
        # Count recent requests
        count = :ets.info(table_name, :size)

        if count < limit do
          # We're under the limit, so record this request and proceed
          :ets.insert(table_name, {now, now})
          :ok
        else
          # We're at the limit, find the oldest request and calculate wait time
          case :ets.select(table_name, [{{:"$1", :_}, [], [:"$1"]}]) do
            [] ->
              # This shouldn't happen, but just in case
              {:wait, window_ms}

            timestamps ->
              oldest = Enum.min(timestamps)
              wait_time = oldest + window_ms - now
              {:wait, max(wait_time, 0)}
          end
        end
      end)
    rescue
      # Handle the case where the table doesn't support transactions
      # (e.g., if it wasn't created with :ordered_set type)
      _ ->
        # Fall back to non-transactional approach
        count = :ets.info(table_name, :size)

        if count < limit do
          :ets.insert(table_name, {now, now})
          :ok
        else
          case :ets.select(table_name, [{{:"$1", :_}, [], [:"$1"]}]) do
            [] -> {:wait, window_ms}
            timestamps ->
              oldest = Enum.min(timestamps)
              wait_time = oldest + window_ms - now
              {:wait, max(wait_time, 0)}
          end
        end
    end
  end

  @doc """
  Resets all rate limiters (global and chat-specific).
  """
  def reset_all do
    Logger.info("Resetting all rate limiters")
    reset(@global_limit.name)

    # Find and reset all chat-specific tables
    :ets.all()
    |> Enum.filter(fn table ->
      table_name = inspect(table)
      String.contains?(table_name, "telegram_chat_") or
      String.contains?(table_name, "telegram_group_") or
      String.contains?(table_name, "telegram_method_")
    end)
    |> Enum.each(fn table ->
      # Check if the table still exists before trying to delete objects
      case :ets.info(table) do
        :undefined -> :ok
        _ -> :ets.delete_all_objects(table)
      end
    end)
  end

  # Private helpers

  defp init(name) do
    table_name = get_table_name(name)

    case :ets.info(table_name) do
      :undefined ->
        # Create table with ordered_set type to support transactions
        :ets.new(table_name, [:named_table, :ordered_set, :public])
        Logger.debug("Created new rate limit table: #{inspect(table_name)}")

      _ ->
        :ok
    end
  end

  defp reset(name) do
    table_name = get_table_name(name)

    case :ets.info(table_name) do
      :undefined ->
        :ok

      _ ->
        :ets.delete_all_objects(table_name)
        Logger.debug("Reset rate limit table: #{inspect(table_name)}")
    end
  end

  @doc """
  Gets the ETS table name for a rate limiter.

  ## Parameters

  - `name`: The name of the rate limiter

  ## Returns

  The ETS table name as an atom.
  """
  def get_table_name(name) do
    :"rate_limiter_#{name}"
  end

  defp chat_rate_limit_config(chat_id) do
    %{@chat_limit | name: :"telegram_chat_#{chat_id}"}
  end

  defp group_rate_limit_config(chat_id) do
    %{@group_limit | name: :"telegram_group_#{chat_id}"}
  end
end
