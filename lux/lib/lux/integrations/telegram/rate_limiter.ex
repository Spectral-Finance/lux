defmodule Lux.Integrations.Telegram.RateLimiter do
  @moduledoc """
  Rate limit management and throttling engine for Telegram Bot API.
  Adheres to Telegram official rate limits:
  - 30 messages/second globally across all chats
  - 1 message/second per private chat
  - 20 messages/minute per group/channel
  Also handles dynamic HTTP 429 Too Many Requests responses and extracts `parameters.retry_after`.
  """

  @global_limit_per_second 30
  @chat_limit_per_second 1
  @group_limit_per_minute 20

  @type state :: %{
          global_window: list(integer()),
          chat_windows: %{String.t() => list(integer())},
          retry_until: %{String.t() => integer()} # chat_id => epoch_second
        }

  @doc """
  Initializes rate limiter state.
  """
  @spec init_state() :: state()
  def init_state do
    %{
      global_window: [],
      chat_windows: %{},
      retry_until: %{}
    }
  end

  @doc """
  Checks whether a message to `chat_id` can be sent immediately under current rate limits.
  Returns `:ok` or `{:rate_limited, wait_ms, reason}`.
  """
  @spec check_rate_limit(state(), String.t() | integer(), :private | :group, integer()) ::
          {:ok, state()} | {:rate_limited, integer(), String.t()}
  def check_rate_limit(state, chat_id, chat_type \\ :private, now_ms \\ :os.system_time(:millisecond)) do
    chat_key = to_string(chat_id)
    now_sec = div(now_ms, 1000)

    # 1. Check if chat is in dynamic retry_after timeout
    case Map.get(state.retry_until, chat_key) do
      wait_until_sec when is_integer(wait_until_sec) and wait_until_sec > now_sec ->
        wait_ms = (wait_until_sec - now_sec) * 1000
        {:rate_limited, wait_ms, "Chat in retry_after penalty"}

      _ ->
        # 2. Check global 30 msgs/sec window
        clean_global = prune_window(state.global_window, now_ms, 1000)

        if length(clean_global) >= @global_limit_per_second do
          oldest = List.last(clean_global)
          wait_ms = max(1000 - (now_ms - oldest), 50)
          {:rate_limited, wait_ms, "Global limit exceeded (30 msgs/s)"}
        else
          # 3. Check chat-level limits
          chat_history = Map.get(state.chat_windows, chat_key, [])

          case chat_type do
            :private ->
              clean_chat = prune_window(chat_history, now_ms, 1000)

              if length(clean_chat) >= @chat_limit_per_second do
                oldest = List.last(clean_chat)
                wait_ms = max(1000 - (now_ms - oldest), 50)
                {:rate_limited, wait_ms, "Private chat limit exceeded (1 msg/s)"}
              else
                updated_state = %{
                  state
                  | global_window: [now_ms | clean_global],
                    chat_windows: Map.put(state.chat_windows, chat_key, [now_ms | clean_chat])
                }

                {:ok, updated_state}
              end

            :group ->
              clean_chat = prune_window(chat_history, now_ms, 60_000)

              if length(clean_chat) >= @group_limit_per_minute do
                oldest = List.last(clean_chat)
                wait_ms = max(60_000 - (now_ms - oldest), 50)
                {:rate_limited, wait_ms, "Group chat limit exceeded (20 msgs/min)"}
              else
                updated_state = %{
                  state
                  | global_window: [now_ms | clean_global],
                    chat_windows: Map.put(state.chat_windows, chat_key, [now_ms | clean_chat])
                }

                {:ok, updated_state}
              end
          end
        end
    end
  end

  @doc """
  Records a 429 response from Telegram and enforces `retry_after`.
  """
  @spec record_retry_after(state(), String.t() | integer(), map() | integer()) :: state()
  def record_retry_after(state, chat_id, response_or_seconds) do
    chat_key = to_string(chat_id)
    now_sec = :os.system_time(:second)

    retry_seconds =
      case response_or_seconds do
        sec when is_integer(sec) ->
          sec

        %{"parameters" => %{"retry_after" => sec}} when is_integer(sec) ->
          sec

        %{"retry_after" => sec} when is_integer(sec) ->
          sec

        _ ->
          5 # Safe default
      end

    wait_until = now_sec + retry_seconds + 1
    %{state | retry_until: Map.put(state.retry_until, chat_key, wait_until)}
  end

  @doc """
  Calculates exponential backoff delay with randomized jitter for general retries.
  """
  @spec calculate_backoff(non_neg_integer()) :: non_neg_integer()
  def calculate_backoff(attempt) do
    base = 500 * :math.pow(2, min(attempt, 5)) |> round()
    jitter = :rand.uniform(250)
    base + jitter
  end

  defp prune_window(timestamps, now, window_size) do
    Enum.filter(timestamps, fn ts -> now - ts < window_size end)
  end
end
