defmodule Lux.Prisms.Telegram.SendMessage do
  @moduledoc """
  Prism for sending messages via Telegram Bot API.

  Supports text, markdown, HTML, reply markup (inline keyboard, custom keyboard),
  and reply-to functionality.
  """

  use Lux.Prism,
    name: "Telegram Send Message",
    description: "Send a message to a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat ID"},
        text: %{type: :string, description: "Message text"},
        parse_mode: %{type: :string, enum: ["Markdown", "MarkdownV2", "HTML"]},
        reply_to_message_id: %{type: :integer},
        disable_notification: %{type: :boolean},
        reply_markup: %{type: :object, description: "InlineKeyboardMarkup or ReplyKeyboardMarkup"},
        token: %{type: :string}
      },
      required: ["chat_id", "text", "token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        message_id: %{type: :integer},
        chat: %{type: :object}
      }
    }

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _opts) do
    api_params =
      %{chat_id: params[:chat_id] || params["chat_id"],
        text: params[:text] || params["text"]}
      |> maybe_put(:parse_mode, params[:parse_mode] || params["parse_mode"])
      |> maybe_put(:reply_to_message_id, params[:reply_to_message_id] || params["reply_to_message_id"])
      |> maybe_put(:disable_notification, params[:disable_notification] || params["disable_notification"])
      |> maybe_put(:reply_markup, params[:reply_markup] || params["reply_markup"])

    Client.request("sendMessage", api_params, build_opts(params))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(params) do
    opts = [token: params[:token] || params["token"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
