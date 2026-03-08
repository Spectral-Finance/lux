defmodule Lux.Prisms.Discord.ConversationManager do
  @moduledoc "Agent Discord: threads, messages, reactions, history analysis."

  alias Lux.Integrations.Discord.Client

  def create_thread(channel_id, params, opts \\ %{}) do
    body = %{name: params[:name], auto_archive_duration: params[:archive_duration] || 1440}
    Client.request(:post, "/channels/#{channel_id}/threads", Map.merge(opts, %{json: body}))
  end

  def send_message(channel_id, content, opts \\ %{}) do
    body = %{content: content}
    Client.request(:post, "/channels/#{channel_id}/messages", Map.merge(opts, %{json: body}))
  end

  def edit_message(channel_id, message_id, content, opts \\ %{}) do
    body = %{content: content}
    Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", Map.merge(opts, %{json: body}))
  end

  def delete_message(channel_id, message_id, opts \\ %{}) do
    Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}", opts)
  end

  def add_reaction(channel_id, message_id, emoji, opts \\ %{}) do
    Client.request(:put, "/channels/#{channel_id}/messages/#{message_id}/reactions/#{URI.encode(emoji)}/@me", opts)
  end

  def get_history(channel_id, opts \\ %{}) do
    limit = opts[:limit] || 50
    Client.request(:get, "/channels/#{channel_id}/messages?limit=#{limit}", opts)
  end

  def analyze_history(messages) when is_list(messages) do
    total = length(messages)
    authors = messages |> Enum.map(&(&1["author"]["id"] || &1[:author_id])) |> Enum.frequencies()
    {:ok, %{total_messages: total, unique_authors: map_size(authors), author_counts: authors}}
  end
end
