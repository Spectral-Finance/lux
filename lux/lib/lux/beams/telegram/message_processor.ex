defmodule Lux.Beams.Telegram.MessageProcessor do
  @moduledoc """
  A beam that demonstrates processing an incoming Telegram message.
  It tracks the message in the thread manager and parses any commands.
  """
  use Lux.Beam,
    name: "Telegram Message Processor",
    description: "Orchestrates saving a message to a thread and parsing commands.",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :object, description: "Incoming Telegram message"},
        chat_id: %{type: :string},
        thread_manager_pid: %{description: "PID of the ThreadManager"}
      },
      required: ["message", "chat_id", "thread_manager_pid"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        thread_saved: %{type: :boolean},
        command_parsed: %{type: :boolean},
        command_info: %{type: :object}
      }
    }

  sequence do
    # 1. Save to thread
    step(:save_message, Lux.Prisms.Telegram.ManageThread, %{
      action: "add_message",
      pid: :thread_manager_pid,
      chat_id: :chat_id,
      message: :message
    })

    # 2. Check if text message to parse
    branch {__MODULE__, :has_text?} do
      true ->
        step(:parse, Lux.Prisms.Telegram.ParseCommand, %{
          text: {:ref, "message.text"} # In a real scenario we extract text
        })
      false ->
        step(:skip, Lux.Prisms.NoOp, %{})
    end
  end

  def has_text?(ctx) do
    is_map(ctx[:message]) and Map.has_key?(ctx[:message], "text")
  end
end
