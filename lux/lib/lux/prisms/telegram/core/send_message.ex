defmodule Lux.Prisms.Telegram.Core.SendMessage do
  @moduledoc """
  Prism to send a message via Telegram Core API (User account).
  """

  alias Lux.Integrations.TelegramCore.Client

  def call(params) do
    # Expects chat_id and text
    case Client.send_message(params) do
      {:ok, msg_id} -> 
        {:ok, %{message_id: msg_id, status: "sent"}}
      {:error, reason} -> 
        {:error, reason}
    end
  end
end
