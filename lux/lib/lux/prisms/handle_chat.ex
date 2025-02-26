defmodule Lux.Prisms.HandleChat do
  @moduledoc """
  A prism that handles chat messages between agents.
  It processes incoming chat messages and generates appropriate responses.
  """

  use Lux.Prism,
    name: "Handle Chat",
    description: "Processes chat messages and generates responses",
    input_schema: Lux.Signal.Chat,
    output_schema: Lux.Signal.Chat

  alias Lux.LLM

  @doc """
  Handles an incoming chat message and generates a response.
  """
  def handler(
        %{"message" => message, "message_type" => message_type, "context" => context},
        %{agent: agent} = _ctx
      ) do
    # Create a chat signal from the input
    chat_signal = %Lux.Signal{
      payload: %{
        "message" => message,
        "message_type" => message_type,
        "context" => context
      }
    }

    # Process the chat message using the agent's LLM
    case process_chat(chat_signal, agent) do
      {:ok, response} ->
        {:ok,
         %{
           "message" => response.message,
           "message_type" => "response",
           "context" => %{
             "thread_id" => context["thread_id"],
             "reply_to" => chat_signal.id,
             "metadata" => %{
               "sender_id" => agent.id
             }
           }
         }}

      {:error, reason} ->
        {:ok,
         %{
           "message" => "Error processing chat: #{inspect(reason)}",
           "message_type" => "error",
           "context" => %{
             "thread_id" => context["thread_id"],
             "reply_to" => chat_signal.id,
             "metadata" => %{
               "sender_id" => agent.id
             }
           }
         }}
    end
  end

  defp process_chat(chat_signal, agent) do
    # Use the agent's LLM to generate a response
    prompt = """
    You are #{agent.name}, an AI agent with the following goal:
    #{agent.goal}

    You received the following chat message:
    #{chat_signal.payload["message"]}

    Generate an appropriate response based on your goal and capabilities.
    Keep the response concise and relevant to the conversation.
    """

    # need to pass beams and prisms instead of empty list here.
    case LLM.call(prompt, [], agent.llm_config) do
      {:ok, %{content: content}} ->
        {:ok, %{message: content}}

      error ->
        error
    end
  end
end
