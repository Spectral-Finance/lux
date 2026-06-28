defmodule Lux.Prisms.YouTube.SendChatMessage do
  @moduledoc """
  Sends a chat message to a YouTube live broadcast chat.
  """
  use Lux.Prism,
    name: "YouTube Send Chat Message",
    description: "Sends a text message to a specific live chat. Requires OAuth authorization.",
    input_schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{
          type: :string,
          description: "The ID of the live chat."
        },
        message_text: %{
          type: :string,
          description: "The text of the message to send."
        },
        dry_run: %{
          type: :boolean,
          description: "If true, simulates the API calls without mutation."
        }
      },
      required: ["live_chat_id", "message_text"]
    }

  alias Lux.Integrations.YouTube.LiveChat
  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(params, _context) do
    live_chat_id = Map.get(params, "live_chat_id") || Map.get(params, :live_chat_id)
    message_text = Map.get(params, "message_text") || Map.get(params, :message_text)
    dry_run = Map.get_lazy(params, "dry_run", fn -> Map.get(params, :dry_run, true) end)

    config = %Client.Config{
      access_token: Application.get_env(:lux, :api_keys)[:youtube_access_token],
      dry_run: dry_run
    }

    LiveChat.send_message(live_chat_id, message_text, config)
  end
end
