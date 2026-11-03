defmodule Lux.Integrations.Discord.Capabilities do
  @moduledoc """
  Discord server, channel, thread, and message management capabilities for Lux agents (#55).
  """

  @discord_api_base "https://discord.com/api/v10"

  def base_url, do: @discord_api_base

  def build_thread_payload(name, auto_archive_duration \\ 1440, type \\ 11)
      when is_binary(name) do
    trimmed = String.trim(name)

    if trimmed == "" do
      {:error, :empty_thread_name}
    else
      {:ok,
       %{
         name: String.slice(trimmed, 0, 100),
         auto_archive_duration: auto_archive_duration,
         type: type
       }}
    end
  end

  def summarize_message_activity(messages) when is_list(messages) do
    total = length(messages)

    by_author =
      Enum.reduce(messages, %{}, fn msg, acc ->
        author = get_in(msg, [:author, :id]) || "unknown"
        Map.update(acc, author, 1, &(&1 + 1))
      end)

    %{total_messages: total, active_authors: map_size(by_author), counts_by_author: by_author}
  end
end
