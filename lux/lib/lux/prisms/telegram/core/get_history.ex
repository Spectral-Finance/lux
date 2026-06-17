defmodule Lux.Prisms.Telegram.Core.GetHistory do
  @moduledoc """
  Prism to retrieve message history from a Telegram chat using Core API.
  """

  alias Lux.Integrations.TelegramCore.Client

  def call(params) do
    # Expects chat_id and optionally limit
    case Client.get_messages(params) do
      {:ok, messages} -> 
        # Return as a signal for the agent to process
        {:ok, %{messages: messages, count: length(messages)}}
      {:error, reason} -> 
        {:error, reason}
    end
  end
end
