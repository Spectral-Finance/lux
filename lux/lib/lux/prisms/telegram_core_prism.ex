defmodule Lux.Prisms.TelegramCorePrism do
  @moduledoc """
  A high-level Prism enabling autonomous Lux agents to control Telegram bots.
  Supports checking bot credentials, sending/editing/deleting messages, forwarding,
  dispatching media, configuring webhooks, polling updates, and priority queueing.

  ## Examples

      iex> Lux.Prisms.TelegramCorePrism.run(%{
      ...>   action: "send_message",
      ...>   payload: %{
      ...>     chat_id: 123456789,
      ...>     text: "Alert: Agent executed operation successfully."
      ...>   }
      ...> })
      {:ok, %{action: "send_message", result: %{message_id: 101}}}
  """

  use Lux.Prism,
    name: "Telegram Core Prism",
    description: "Telegram Bot API operations for agents: messages, media, webhooks, rate-limited queuing, and updates",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "get_me",
            "send_message",
            "edit_message",
            "delete_message",
            "forward_message",
            "send_photo",
            "send_document",
            "set_webhook",
            "get_webhook_info",
            "delete_webhook",
            "poll_updates",
            "register_bot_token",
            "enqueue_message"
          ],
          description: "Telegram Bot API action to execute"
        },
        payload: %{
          type: :object,
          description: "Payload data corresponding to the selected action"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.Integrations.Telegram

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "get_me")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "TelegramCorePrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("get_me", payload) do
    opts = extract_client_opts(payload)
    Telegram.get_me(opts)
  end

  defp execute_action("send_message", payload) do
    chat_id = Map.get(payload, :chat_id, Map.get(payload, "chat_id"))
    text = Map.get(payload, :text, Map.get(payload, "text", ""))
    opts = extract_client_opts(payload)
    Telegram.send_message(chat_id, text, opts)
  end

  defp execute_action("edit_message", payload) do
    chat_id = Map.get(payload, :chat_id, Map.get(payload, "chat_id"))
    message_id = Map.get(payload, :message_id, Map.get(payload, "message_id"))
    text = Map.get(payload, :text, Map.get(payload, "text", ""))
    opts = extract_client_opts(payload)
    Telegram.edit_message_text(chat_id, message_id, text, opts)
  end

  defp execute_action("delete_message", payload) do
    chat_id = Map.get(payload, :chat_id, Map.get(payload, "chat_id"))
    message_id = Map.get(payload, :message_id, Map.get(payload, "message_id"))
    opts = extract_client_opts(payload)
    Telegram.delete_message(chat_id, message_id, opts)
  end

  defp execute_action("forward_message", payload) do
    to_chat_id = Map.get(payload, :to_chat_id, Map.get(payload, "to_chat_id"))
    from_chat_id = Map.get(payload, :from_chat_id, Map.get(payload, "from_chat_id"))
    message_id = Map.get(payload, :message_id, Map.get(payload, "message_id"))
    opts = extract_client_opts(payload)
    Telegram.forward_message(to_chat_id, from_chat_id, message_id, opts)
  end

  defp execute_action("send_photo", payload) do
    chat_id = Map.get(payload, :chat_id, Map.get(payload, "chat_id"))
    photo = Map.get(payload, :photo, Map.get(payload, "photo"))
    opts = extract_client_opts(payload)
    Telegram.send_photo(chat_id, photo, opts)
  end

  defp execute_action("send_document", payload) do
    chat_id = Map.get(payload, :chat_id, Map.get(payload, "chat_id"))
    document = Map.get(payload, :document, Map.get(payload, "document"))
    opts = extract_client_opts(payload)
    Telegram.send_document(chat_id, document, opts)
  end

  defp execute_action("set_webhook", payload) do
    url = Map.get(payload, :url, Map.get(payload, "url"))
    secret = Map.get(payload, :secret_token, Map.get(payload, "secret_token"))
    opts = extract_client_opts(payload)
    Telegram.set_webhook(url, secret, opts)
  end

  defp execute_action("get_webhook_info", payload) do
    opts = extract_client_opts(payload)
    Telegram.get_webhook_info(opts)
  end

  defp execute_action("delete_webhook", payload) do
    opts = extract_client_opts(payload)
    Telegram.delete_webhook(opts)
  end

  defp execute_action("poll_updates", payload) do
    opts = extract_client_opts(payload)
    Telegram.poll_updates(payload, opts)
  end

  defp execute_action("register_bot_token", payload) do
    name = Map.get(payload, :name, Map.get(payload, "name", "agent_bot"))
    token = Map.get(payload, :token, Map.get(payload, "token", ""))
    pass = Map.get(payload, :passphrase, Map.get(payload, "passphrase", "lux_secret_key"))
    registry = Map.get(payload, :registry, Map.get(payload, "registry", Telegram.init_token_registry()))

    case Telegram.register_bot(registry, name, token, pass) do
      {:ok, updated_reg, record} ->
        {:ok, %{registry: updated_reg, bot: record, masked_token: Telegram.mask_token(token)}}

      error ->
        error
    end
  end

  defp execute_action("enqueue_message", payload) do
    queue = Map.get(payload, :queue, Telegram.init_queue())
    chat_id = Map.get(payload, :chat_id, Map.get(payload, "chat_id", 0))
    priority = Map.get(payload, :priority, :normal)
    msg_payload = Map.get(payload, :message, %{})

    {:ok, updated_q, item} = Telegram.enqueue_message(queue, chat_id, msg_payload, priority)
    {:ok, %{queue: updated_q, item: item, pending: Telegram.pending_message_count(updated_q)}}
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end

  defp extract_client_opts(payload) do
    opts = %{}

    opts =
      case Map.get(payload, :token, Map.get(payload, "token")) do
        nil -> opts
        token -> Map.put(opts, :token, token)
      end

    case Map.get(payload, :plug, Map.get(payload, "plug")) do
      nil -> opts
      plug -> Map.put(opts, :plug, plug)
    end
  end
end
