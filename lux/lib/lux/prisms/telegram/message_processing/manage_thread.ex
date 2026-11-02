defmodule Lux.Prisms.Telegram.MessageProcessing.ManageThread do
  @moduledoc """
  A prism for managing Telegram supergroup forum topics and message threading.
  Extracts thread context and builds thread reply parameters.
  """

  use Lux.Prism,
    name: "Manage Telegram Thread",
    description: "Resolves forum topic thread identifiers and builds thread reply options",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :object, description: "Telegram message payload"},
        quote_reply: %{type: :boolean, description: "Whether to reply with quote"}
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_thread: %{type: :boolean},
        thread_id: %{type: [:integer, :null]},
        is_general_topic: %{type: :boolean},
        reply_params: %{type: :object}
      },
      required: ["is_thread", "reply_params"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.ThreadManager

  def handler(params, _agent) when is_map(params) do
    message = Map.get(params, :message) || Map.get(params, "message") || params
    quote_reply = Map.get(params, :quote_reply, false)

    thread_info = ThreadManager.extract_thread_info(message)
    reply_params = ThreadManager.build_thread_reply_params(message, quote_reply: quote_reply)

    {:ok,
     %{
       is_thread: thread_info.is_thread,
       thread_id: thread_info.thread_id,
       is_general_topic: thread_info.is_general_topic,
       forum_event: thread_info.forum_event,
       reply_params: reply_params
     }}
  end

  def handler(_, _), do: {:error, "Invalid input: expected message object"}
end
