defmodule Lux.Prisms.Telegram.MessageProcessing.ResolveReply do
  @moduledoc """
  A prism for resolving reply hierarchies, quote objects (Telegram Bot API 7.0+),
  and building reply_parameters for responses.
  """

  use Lux.Prism,
    name: "Resolve Telegram Reply",
    description: "Extracts replied message context, parses quote objects, and builds reply parameters",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :object, description: "Telegram message payload"},
        quote: %{type: :string, description: "Optional specific quote string to send in reply"}
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        has_reply: %{type: :boolean},
        replied_message: %{type: [:object, :null]},
        reply_params: %{type: :object},
        llm_context: %{type: :string}
      },
      required: ["has_reply", "reply_params"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.ReplyManager

  def handler(params, _agent) when is_map(params) do
    message = Map.get(params, :message) || Map.get(params, "message") || params
    quote_text = Map.get(params, :quote) || Map.get(params, "quote")

    has_reply = ReplyManager.reply?(message)

    replied_info =
      case ReplyManager.resolve_reply(message) do
        {:ok, info} -> info
        _ -> nil
      end

    opts = if quote_text, do: [quote: quote_text], else: []
    reply_params = ReplyManager.build_reply_parameters(message, opts)
    llm_context = ReplyManager.format_llm_context(message)

    {:ok,
     %{
       has_reply: has_reply,
       replied_message: replied_info,
       reply_params: reply_params,
       llm_context: llm_context
     }}
  end

  def handler(_, _), do: {:error, "Invalid input: expected message object"}
end
