defmodule Lux.Telegram.Messaging do
  @moduledoc """
  Messaging API functions for Telegram Bot API integration.
  """

  alias Lux.Telegram.Client
  alias Lux.Telegram.Keyboards

  @doc """
  Sends a text message to a Telegram chat.
  """
  def send_message(chat_id, text, opts \\ %{}) do
    {client_opts, api_opts} = split_opts(opts)
    api_opts = normalize_api_opts(api_opts)
    json = Map.merge(api_opts, %{chat_id: chat_id, text: text})
    Client.request(:post, "/sendMessage", Map.put(client_opts, :json, json))
  end

  @doc """
  Edits text of a message in a Telegram chat or inline message.
  Supports:
  - `edit_message_text(chat_id, message_id, text, opts)`
  - `edit_message_text(inline_message_id, text, opts)`
  """
  def edit_message_text(chat_id_or_inline_id, message_id_or_text, text_or_opts \\ %{}, opts \\ %{})

  def edit_message_text(chat_id, message_id, text, opts)
      when (is_integer(message_id) or is_binary(message_id)) and is_binary(text) do
    {client_opts, api_opts} = split_opts(opts)
    api_opts = normalize_api_opts(api_opts)

    base =
      cond do
        chat_id != nil and message_id != nil ->
          %{chat_id: chat_id, message_id: message_id}

        message_id != nil ->
          %{message_id: message_id}

        true ->
          %{}
      end

    json = Map.merge(api_opts, Map.put(base, :text, text))
    Client.request(:post, "/editMessageText", Map.put(client_opts, :json, json))
  end

  def edit_message_text(inline_message_id, text, opts, _)
      when is_binary(inline_message_id) and is_binary(text) do
    {client_opts, api_opts} = split_opts(opts)
    api_opts = normalize_api_opts(api_opts)
    json = Map.merge(api_opts, %{inline_message_id: inline_message_id, text: text})
    Client.request(:post, "/editMessageText", Map.put(client_opts, :json, json))
  end

  def edit_message_text(chat_id, message_id, text, opts) do
    {client_opts, api_opts} = split_opts(opts)
    api_opts = normalize_api_opts(api_opts)

    base =
      cond do
        chat_id != nil and message_id != nil ->
          %{chat_id: chat_id, message_id: message_id}

        message_id != nil ->
          %{message_id: message_id}

        true ->
          %{}
      end

    json = Map.merge(api_opts, Map.put(base, :text, text))
    Client.request(:post, "/editMessageText", Map.put(client_opts, :json, json))
  end

  @doc """
  Deletes a message from a Telegram chat.
  """
  def delete_message(chat_id, message_id, opts \\ %{}) do
    {client_opts, api_opts} = split_opts(opts)
    json = Map.merge(api_opts, %{chat_id: chat_id, message_id: message_id})
    Client.request(:post, "/deleteMessage", Map.put(client_opts, :json, json))
  end

  @doc """
  Copies a message from one Telegram chat to another.
  """
  def copy_message(chat_id, from_chat_id, message_id, opts \\ %{}) do
    {client_opts, api_opts} = split_opts(opts)
    api_opts = normalize_api_opts(api_opts)
    json = Map.merge(api_opts, %{chat_id: chat_id, from_chat_id: from_chat_id, message_id: message_id})
    Client.request(:post, "/copyMessage", Map.put(client_opts, :json, json))
  end

  @doc """
  Forwards a message from one Telegram chat to another.
  """
  def forward_message(chat_id, from_chat_id, message_id, opts \\ %{}) do
    {client_opts, api_opts} = split_opts(opts)
    api_opts = normalize_api_opts(api_opts)
    json = Map.merge(api_opts, %{chat_id: chat_id, from_chat_id: from_chat_id, message_id: message_id})
    Client.request(:post, "/forwardMessage", Map.put(client_opts, :json, json))
  end

  defp split_opts(opts) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts || %{}

    {client_opts, api_opts} =
      Map.split(opts_map, [
        :token,
        :plug,
        :headers,
        :base_url,
        :req_options,
        :sleep_fun,
        :max_retries,
        :max_rate_limit_retries,
        :base_backoff,
        :max_backoff,
        :backoff_factor
      ])

    {client_opts, api_opts}
  end

  defp normalize_api_opts(api_opts) do
    if Map.has_key?(api_opts, :reply_markup) do
      Map.update!(api_opts, :reply_markup, &Keyboards.to_map/1)
    else
      api_opts
    end
  end
end
