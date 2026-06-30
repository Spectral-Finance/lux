defmodule Lux.Prisms.Telegram.ManageThread do
  @moduledoc """
  A prism that interfaces with the Telegram ThreadManager.
  """
  use Lux.Prism,
    name: "Manage Telegram Thread",
    description: "Adds a message to a thread or retrieves the thread history.",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["add_message", "get_thread", "add_callback", "get_callbacks", "prune"]},
        chat_id: %{type: :string},
        message: %{type: :object},
        message_id: %{type: :integer},
        callback_query: %{type: :object},
        pid: %{description: "PID or name of the ThreadManager process"}
      },
      required: ["action", "pid"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: :string},
        thread: %{type: :array, items: %{type: :object}},
        callbacks: %{type: :array, items: %{type: :object}}
      }
    }

  def handler(%{"action" => action, "pid" => pid} = input, _ctx) do
    # Assuming pid is an atom registered name or actual PID.
    # If passed as string and it's a registered name, convert.
    pid_or_name = if is_binary(pid) and String.starts_with?(pid, "Elixir."), do: String.to_atom(pid), else: pid

    case action do
      "add_message" ->
        case Lux.Integrations.Telegram.ThreadManager.add_message(pid_or_name, input["chat_id"], input["message"]) do
          :ok -> {:ok, %{"result" => "ok"}}
          error -> error
        end
        
      "get_thread" ->
        thread = Lux.Integrations.Telegram.ThreadManager.get_thread(pid_or_name, input["chat_id"], input["message_id"])
        {:ok, %{"thread" => thread}}
        
      "add_callback" ->
        case Lux.Integrations.Telegram.ThreadManager.add_callback(pid_or_name, input["callback_query"]) do
          :ok -> {:ok, %{"result" => "ok"}}
          error -> error
        end
        
      "get_callbacks" ->
        callbacks = Lux.Integrations.Telegram.ThreadManager.get_callbacks(pid_or_name)
        {:ok, %{"callbacks" => callbacks}}
        
      "prune" ->
        case Lux.Integrations.Telegram.ThreadManager.prune(pid_or_name) do
          :ok -> {:ok, %{"result" => "ok"}}
          error -> error
        end
    end
  end
end
