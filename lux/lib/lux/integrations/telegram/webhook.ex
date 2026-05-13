defmodule Lux.Integrations.Telegram.Webhook do
  @moduledoc """
  Webhook and update helpers for the Telegram Bot API.
  """

  alias Lux.Integrations.Telegram.Client

  @secret_header "x-telegram-bot-api-secret-token"

  @set_webhook_keys [
    :url,
    :certificate,
    :ip_address,
    :max_connections,
    :allowed_updates,
    :drop_pending_updates,
    :secret_token
  ]

  @get_updates_keys [:offset, :limit, :timeout, :allowed_updates]

  @doc "Configures a webhook for the bot."
  @spec set(String.t(), Client.request_opts()) :: {:ok, map()} | {:error, term()}
  def set(url, opts \\ %{}) when is_binary(url) do
    payload =
      opts
      |> opts_map()
      |> Map.take(@set_webhook_keys)
      |> Map.put(:url, url)
      |> reject_nil_values()

    Client.request(:post, "/setWebhook", put_json(opts, payload))
  end

  @doc "Deletes the configured webhook."
  @spec delete(Client.request_opts()) :: {:ok, map()} | {:error, term()}
  def delete(opts \\ %{}) do
    payload =
      opts
      |> opts_map()
      |> Map.take([:drop_pending_updates])
      |> reject_nil_values()

    Client.request(:post, "/deleteWebhook", put_json(opts, payload))
  end

  @doc "Returns current webhook status."
  @spec info(Client.request_opts()) :: {:ok, map()} | {:error, term()}
  def info(opts \\ %{}), do: Client.request(:get, "/getWebhookInfo", opts)

  @doc "Fetches updates for polling-based bots."
  @spec get_updates(Client.request_opts()) :: {:ok, map()} | {:error, term()}
  def get_updates(opts \\ %{}) do
    payload =
      opts
      |> opts_map()
      |> Map.take(@get_updates_keys)
      |> reject_nil_values()

    Client.request(:post, "/getUpdates", put_json(opts, payload))
  end

  @doc """
  Verifies Telegram webhook secret token from a Plug connection, map, or header list.
  """
  @spec verify_secret_token(Plug.Conn.t() | map() | [{String.t(), String.t()}], String.t()) ::
          boolean()
  def verify_secret_token(_headers, expected) when not is_binary(expected) or expected == "",
    do: false

  def verify_secret_token(headers, expected) do
    case secret_token(headers) do
      token when is_binary(token) and byte_size(token) == byte_size(expected) ->
        Plug.Crypto.secure_compare(token, expected)

      _ ->
        false
    end
  end

  @doc "Returns the Telegram update type."
  @spec update_type(map()) :: atom()
  def update_type(%{"message" => _message}), do: :message
  def update_type(%{"edited_message" => _message}), do: :edited_message
  def update_type(%{"channel_post" => _message}), do: :channel_post
  def update_type(%{"edited_channel_post" => _message}), do: :edited_channel_post
  def update_type(%{"callback_query" => _query}), do: :callback_query
  def update_type(%{"inline_query" => _query}), do: :inline_query
  def update_type(%{"chosen_inline_result" => _result}), do: :chosen_inline_result
  def update_type(%{"poll" => _poll}), do: :poll
  def update_type(%{"poll_answer" => _answer}), do: :poll_answer
  def update_type(%{"my_chat_member" => _member}), do: :my_chat_member
  def update_type(%{"chat_member" => _member}), do: :chat_member
  def update_type(%{"chat_join_request" => _request}), do: :chat_join_request
  def update_type(_update), do: :unknown

  @doc "Extracts the chat id from message-like updates."
  @spec chat_id(map()) :: integer() | String.t() | nil
  def chat_id(%{"message" => %{"chat" => %{"id" => id}}}), do: id
  def chat_id(%{"edited_message" => %{"chat" => %{"id" => id}}}), do: id
  def chat_id(%{"channel_post" => %{"chat" => %{"id" => id}}}), do: id
  def chat_id(%{"callback_query" => %{"message" => %{"chat" => %{"id" => id}}}}), do: id
  def chat_id(_update), do: nil

  defp secret_token(%Plug.Conn{} = conn) do
    conn
    |> Plug.Conn.get_req_header(@secret_header)
    |> List.first()
  end

  defp secret_token(headers) when is_map(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(to_string(key)) == @secret_header, do: value
    end)
  end

  defp secret_token(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(to_string(key)) == @secret_header, do: value
    end)
  end

  defp put_json(opts, payload) do
    opts
    |> opts_map()
    |> Map.drop(@set_webhook_keys ++ @get_updates_keys ++ [:drop_pending_updates, :secret_token])
    |> Map.put(:json, payload)
  end

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp reject_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end
end
