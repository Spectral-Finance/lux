defmodule Lux.Prisms.Telegram.MessageProcessing.ProcessCallbackQuery do
  @moduledoc """
  A prism for parsing incoming Telegram callback queries, decoding structured callback data,
  and formatting answers.
  """

  use Lux.Prism,
    name: "Process Telegram Callback Query",
    description: "Parses callback queries, unpacks data payloads, and creates response options",
    input_schema: %{
      type: :object,
      properties: %{
        callback_query: %{type: :object, description: "Raw Telegram callback_query object"},
        answer_text: %{type: :string, description: "Optional notification text"},
        show_alert: %{type: :boolean, description: "Whether to show an alert popup"}
      },
      required: ["callback_query"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        action: %{type: :string},
        args: %{type: :array},
        user: %{type: :object},
        chat_id: %{type: [:integer, :null]},
        answer_params: %{type: :object}
      },
      required: ["id", "action", "answer_params"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.CallbackQueryProcessor

  def handler(params, _agent) when is_map(params) do
    callback_query = Map.get(params, :callback_query) || Map.get(params, "callback_query") || params
    answer_text = Map.get(params, :answer_text) || Map.get(params, "answer_text")
    show_alert = Map.get(params, :show_alert, false)

    case CallbackQueryProcessor.parse(callback_query) do
      {:ok, parsed} ->
        answer_opts = []
        answer_opts = if answer_text, do: [{:text, answer_text} | answer_opts], else: answer_opts
        answer_opts = if show_alert, do: [{:show_alert, true} | answer_opts], else: answer_opts

        answer_params = CallbackQueryProcessor.build_answer(parsed.id, answer_opts)

        {:ok,
         %{
           id: parsed.id,
           action: parsed.action,
           args: parsed.args,
           raw_data: parsed.raw_data,
           user: parsed.user,
           chat_id: parsed.chat_id,
           message_id: parsed.message_id,
           answer_params: answer_params
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid input: expected callback_query"}
end
