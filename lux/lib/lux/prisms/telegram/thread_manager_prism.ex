defmodule Lux.Prisms.Telegram.ThreadManagerPrism do
  @moduledoc """
  Prism for managing conversation threads, session context, and context window trimming.
  """

  use Lux.Prism,
    name: "Telegram Thread Manager Prism",
    description: "Tracks conversation context history and trims message windows to fit token limits.",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :integer, description: "Telegram chat ID"},
        topic_id: %{type: :integer, description: "Forum topic ID"},
        messages: %{type: :array, items: %{type: :object}, description: "List of conversation messages"},
        max_tokens: %{type: :integer, default: 2000, description: "Max token budget"},
        system_prompt: %{type: :string, description: "Optional system prompt"}
      },
      required: ["chat_id", "messages"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        thread_id: %{type: :string},
        trimmed_messages: %{type: :array, items: %{type: :object}},
        message_count: %{type: :integer}
      }
    }

  @impl true
  def handler(params, _agent) do
    chat_id = params[:chat_id] || params["chat_id"] || 0
    topic_id = params[:topic_id] || params["topic_id"] || nil
    messages = params[:messages] || params["messages"] || []
    max_tokens = params[:max_tokens] || params["max_tokens"] || 2000
    system_prompt = params[:system_prompt] || params["system_prompt"] || nil

    result =
      python variables: %{
        chat_id: chat_id,
        topic_id: topic_id,
        messages: messages,
        max_tokens: max_tokens,
        system_prompt: system_prompt
      } do
        ~PY"""
        from lux.telegram.threads import ConversationMessage, ConversationSession

        session = ConversationSession(chat_id=int(chat_id), topic_id=int(topic_id) if topic_id else None)
        for idx, m in enumerate(messages):
            msg_id = m.get("message_id", idx + 1)
            sender_id = m.get("sender_id", 1)
            sender_name = m.get("sender_name", "User")
            text = m.get("text", "")
            is_bot = bool(m.get("is_bot", False))
            session.add_message(ConversationMessage(
                message_id=msg_id,
                sender_id=sender_id,
                sender_name=sender_name,
                text=text,
                is_bot=is_bot
            ))

        trimmed = session.trim_context_window(max_tokens=int(max_tokens), system_prompt=system_prompt)
        {
            "thread_id": str(session.thread_id),
            "trimmed_messages": trimmed,
            "message_count": len(session.history)
        }
        """
      end

    {:ok, result}
  rescue
    e in RuntimeError ->
      {:error, "Thread context management failed: #{Exception.message(e)}"}
  end
end
