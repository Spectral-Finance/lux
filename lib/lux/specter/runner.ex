defmodule Lux.Specter.Runner do
  @moduledoc """
  GenServer implementation for running a Specter agent.
  Handles chat interactions and maintains conversation state.
  """
  use GenServer
  require Logger
  alias Lux.{Specter, LLM}

  def start_link(%Specter{} = specter) do
    GenServer.start_link(__MODULE__, specter)
  end

  @impl true
  def init(specter) do
    {:ok, %{specter: specter, chat_history: []}}
  end

  @impl true
  def handle_call({:chat, message}, _from, %{specter: specter, chat_history: history} = state) do
    prompt = build_prompt(message, specter, history)

    case LLM.call(prompt, [], config: specter.llm_config) do
      {:ok, %{payload: %{content: content}}} ->
        new_history =
          history ++
            [
              %{role: :user, content: message},
              %{role: :assistant, content: content}
            ]

        {:reply, {:ok, content}, %{state | chat_history: new_history}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp build_prompt(message, specter, history) do
    context = """
    You are #{specter.name}.
    Description: #{specter.description}
    Your goal is: #{specter.goal}
    """

    history_str = format_chat_history(history)

    """
    #{context}

    Previous messages:
    #{history_str}

    User: #{message}
    Assistant:
    """
  end

  defp format_chat_history([]), do: "No previous messages."

  defp format_chat_history(history) do
    history
    |> Enum.map(fn
      %{role: :user, content: content} -> "User: #{content}"
      %{role: :assistant, content: content} -> "Assistant: #{content}"
    end)
    |> Enum.join("\n")
  end
end
