defmodule Lux.Prisms.Discord.MessageManagement do
  @moduledoc """
  Message management prism for Discord: create, edit, delete, bulk delete, history.
  Includes rate limit tracking and retry mechanisms.
  """

  alias Lux.Integrations.Discord.Client

  @max_bulk_delete 100
  @max_retries 3

  @doc "Send a message to a channel."
  def send_message(channel_id, params, opts \\ %{}) do
    body = %{content: params[:content]}
    |> maybe_put(:embeds, params[:embeds])
    |> maybe_put(:components, params[:components])
    |> maybe_put(:message_reference, if(params[:reply_to], do: %{message_id: params[:reply_to]}))

    with_retry(fn ->
      Client.request(:post, "/channels/#{channel_id}/messages", Map.merge(opts, %{json: body}))
    end)
  end

  @doc "Edit an existing message."
  def edit_message(channel_id, message_id, params, opts \\ %{}) do
    body = %{}
    |> maybe_put(:content, params[:content])
    |> maybe_put(:embeds, params[:embeds])

    with_retry(fn ->
      Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", Map.merge(opts, %{json: body}))
    end)
  end

  @doc "Delete a message."
  def delete_message(channel_id, message_id, opts \\ %{}) do
    with_retry(fn ->
      Client.request(:delete, "/channels/#{channel_id}/messages/#{message_id}", opts)
    end)
  end

  @doc "Bulk delete messages (2-100 messages, not older than 14 days)."
  def bulk_delete(channel_id, message_ids, opts \\ %{}) when length(message_ids) <= @max_bulk_delete do
    with_retry(fn ->
      Client.request(:post, "/channels/#{channel_id}/messages/bulk-delete",
        Map.merge(opts, %{json: %{messages: message_ids}}))
    end)
  end

  @doc "Get message history for a channel."
  def get_history(channel_id, params \\ %{}, opts \\ %{}) do
    query = %{}
    |> maybe_put(:limit, params[:limit] || 50)
    |> maybe_put(:before, params[:before])
    |> maybe_put(:after, params[:after])
    |> maybe_put(:around, params[:around])

    query_string = query |> Enum.reject(fn {_, v} -> is_nil(v) end) |> URI.encode_query()
    path = "/channels/#{channel_id}/messages?#{query_string}"

    with_retry(fn -> Client.request(:get, path, opts) end)
  end

  @doc "Pin a message."
  def pin_message(channel_id, message_id, opts \\ %{}) do
    with_retry(fn ->
      Client.request(:put, "/channels/#{channel_id}/pins/#{message_id}", opts)
    end)
  end

  @doc "Add a reaction to a message."
  def add_reaction(channel_id, message_id, emoji, opts \\ %{}) do
    encoded = URI.encode(emoji)
    with_retry(fn ->
      Client.request(:put, "/channels/#{channel_id}/messages/#{message_id}/reactions/#{encoded}/@me", opts)
    end)
  end

  defp with_retry(fun, attempt \\ 1) do
    case fun.() do
      {:error, %{status: 429} = resp} when attempt < @max_retries ->
        retry_after = get_in(resp, [:body, "retry_after"]) || 1
        Process.sleep(trunc(retry_after * 1000))
        with_retry(fun, attempt + 1)
      result -> result
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
