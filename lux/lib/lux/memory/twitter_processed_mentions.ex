defmodule Lux.Memory.TwitterProcessedMentions do
  @moduledoc """
  Durable storage for processed mention IDs to prevent double-replying.
  """
  use Lux.Memory,
    backend: Lux.Memory.ETS,
    name: :twitter_processed_mentions

  def processed?(mention_id) do
    case search(mention_id) do
      {:ok, entries} -> Enum.any?(entries, fn e -> e.content == mention_id end)
      _ -> false
    end
  end

  def mark_as_processed(mention_id) do
    add(mention_id, :system, %{processed_at: DateTime.utc_now()})
  end
end
