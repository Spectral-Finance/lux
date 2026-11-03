defmodule Lux.Integrations.Twitter.CoreClient do
  @moduledoc """
  X / Twitter API v2 Core Integration for tweet publishing, threading, and rate-limit management (#58).
  """

  @max_tweet_chars 280

  def build_tweet_payload(text, opts \\ []) when is_binary(text) do
    trimmed = String.trim(text)
    len = String.length(trimmed)

    cond do
      len == 0 ->
        {:error, :empty_tweet}

      len > @max_tweet_chars ->
        {:error, {:tweet_too_long, len, @max_tweet_chars}}

      true ->
        base = %{text: trimmed}

        base =
          case Keyword.get(opts, :reply_to_id) do
            nil -> base
            reply_id -> Map.put(base, :reply, %{in_reply_to_tweet_id: to_string(reply_id)})
          end

        {:ok, base}
    end
  end
end
