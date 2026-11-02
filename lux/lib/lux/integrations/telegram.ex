defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Unified integration entrypoint for Telegram Bot API.

  Provides high-level helpers for:
  - Request settings and authentication headers for Lux Lenses
  - Bot verification and identity (`get_me/1`)
  - Message lifecycle: send, edit, delete, forward, and copy
  - Media delivery: photos, documents, audio, and animations
  - Webhooks and updates polling (`set_webhook/3`, `poll_updates/2`)
  - Secure token management with AES-256-GCM encryption (`TokenManager`)
  - Rate limiting adhering to Telegram's 30 msgs/s global limit (`RateLimiter`)
  - Priority message queueing (`RateLimitQueue`)
  """

  alias Lux.Integrations.Telegram.{
    Client,
    RateLimiter,
    RateLimitQueue,
    TokenManager,
    UpdatesHandler
  }

  @doc """
  Common request settings for Telegram Bot API calls.
  """
  def request_settings do
    %{
      headers: headers(),
      auth: auth()
    }
  end

  @doc """
  Common headers for Telegram Bot API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Telegram Bot API calls.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Adds Telegram bot token to the URL or connection for Req and Lenses.
  """
  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = get_token()
    path = conn.request_path

    updated_path =
      cond do
        String.contains?(path, "/bot/") ->
          String.replace(path, "/bot/", "/bot#{token}/")

        String.contains?(path, "/bot:token/") ->
          String.replace(path, "/bot:token/", "/bot#{token}/")

        true ->
          path
      end

    %{conn | request_path: updated_path}
  end

  def add_auth_header(req) when is_map(req) do
    req
  end

  defp get_token do
    case Application.get_env(:lux, :api_keys) do
      nil -> System.get_env("TELEGRAM_BOT_TOKEN") || ""
      keys -> Keyword.get(keys, :telegram_bot, System.get_env("TELEGRAM_BOT_TOKEN") || "")
    end
  end

  # --- Delegation to Client & Methods ---

  @doc """
  Retrieves bot information via `/getMe`.
  """
  def get_me(opts \\ %{}) do
    Client.request(:get, "/getMe", opts)
  end

  @doc """
  Sends a text message to target chat (`/sendMessage`).
  """
  def send_message(chat_id, text, opts \\ %{}) do
    body =
      opts
      |> Map.take([:parse_mode, :disable_web_page_preview, :reply_to_message_id, :reply_markup,
                   "parse_mode", "disable_web_page_preview", "reply_to_message_id", "reply_markup"])
      |> Map.put("chat_id", chat_id)
      |> Map.put("text", text)

    req_opts = Map.put(opts, :json, body)
    Client.request(:post, "/sendMessage", req_opts)
  end

  @doc """
  Edits an existing text message (`/editMessageText`).
  """
  def edit_message_text(chat_id, message_id, text, opts \\ %{}) do
    body =
      opts
      |> Map.take([:parse_mode, :reply_markup, "parse_mode", "reply_markup"])
      |> Map.put("chat_id", chat_id)
      |> Map.put("message_id", message_id)
      |> Map.put("text", text)

    req_opts = Map.put(opts, :json, body)
    Client.request(:post, "/editMessageText", req_opts)
  end

  @doc """
  Deletes a message from a chat (`/deleteMessage`).
  """
  def delete_message(chat_id, message_id, opts \\ %{}) do
    body = %{"chat_id" => chat_id, "message_id" => message_id}
    req_opts = Map.put(opts, :json, body)
    Client.request(:post, "/deleteMessage", req_opts)
  end

  @doc """
  Forwards a message to another chat (`/forwardMessage`).
  """
  def forward_message(to_chat_id, from_chat_id, message_id, opts \\ %{}) do
    body = %{
      "chat_id" => to_chat_id,
      "from_chat_id" => from_chat_id,
      "message_id" => message_id
    }

    req_opts = Map.put(opts, :json, body)
    Client.request(:post, "/forwardMessage", req_opts)
  end

  @doc """
  Sends a photo via URL or file_id (`/sendPhoto`).
  """
  def send_photo(chat_id, photo_url_or_id, opts \\ %{}) do
    body =
      opts
      |> Map.take([:caption, :parse_mode, "caption", "parse_mode"])
      |> Map.put("chat_id", chat_id)
      |> Map.put("photo", photo_url_or_id)

    req_opts = Map.put(opts, :json, body)
    Client.request(:post, "/sendPhoto", req_opts)
  end

  @doc """
  Sends a document via URL or file_id (`/sendDocument`).
  """
  def send_document(chat_id, document_url_or_id, opts \\ %{}) do
    body =
      opts
      |> Map.take([:caption, :parse_mode, "caption", "parse_mode"])
      |> Map.put("chat_id", chat_id)
      |> Map.put("document", document_url_or_id)

    req_opts = Map.put(opts, :json, body)
    Client.request(:post, "/sendDocument", req_opts)
  end

  @doc """
  Configures webhook URL for receiving updates (`/setWebhook`).
  """
  def set_webhook(url, secret_token \\ nil, opts \\ %{}) do
    body =
      %{"url" => url}
      |> then(fn m -> if secret_token, do: Map.put(m, "secret_token", secret_token), else: m end)

    req_opts = Map.put(opts, :json, body)
    Client.request(:post, "/setWebhook", req_opts)
  end

  @doc """
  Gets current webhook status (`/getWebhookInfo`).
  """
  def get_webhook_info(opts \\ %{}) do
    Client.request(:get, "/getWebhookInfo", opts)
  end

  @doc """
  Removes webhook integration (`/deleteWebhook`).
  """
  def delete_webhook(opts \\ %{}) do
    Client.request(:post, "/deleteWebhook", opts)
  end

  # --- Delegations to Submodules ---

  # Token Manager
  defdelegate valid_token_format?(token), to: TokenManager
  defdelegate encrypt_token(token, pass), to: TokenManager
  defdelegate decrypt_token(encoded, pass), to: TokenManager
  defdelegate mask_token(token), to: TokenManager
  defdelegate init_token_registry(), to: TokenManager, as: :init_registry
  defdelegate register_bot(reg, name, token, pass), to: TokenManager
  defdelegate get_bot_token(reg, name, pass), to: TokenManager

  # Rate Limiter
  defdelegate init_rate_limiter(), to: RateLimiter, as: :init_state
  defdelegate check_rate_limit(state, chat_id, type \\ :private, now \\ nil), to: RateLimiter
  defdelegate record_retry_after(state, chat_id, resp), to: RateLimiter
  defdelegate calculate_backoff(attempt), to: RateLimiter

  # Rate Limit Queue
  defdelegate init_queue(), to: RateLimitQueue
  defdelegate enqueue_message(queue, chat_id, payload, priority \\ :normal), to: RateLimitQueue, as: :enqueue
  defdelegate dequeue_message(queue), to: RateLimitQueue, as: :dequeue
  defdelegate pending_message_count(queue), to: RateLimitQueue, as: :total_count

  # Updates Handler
  defdelegate verify_secret_token(header, expected), to: UpdatesHandler
  defdelegate normalize_update(raw), to: UpdatesHandler
  defdelegate poll_updates(params \\ %{}, opts \\ %{}), to: UpdatesHandler
end
