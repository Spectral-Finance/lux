defmodule Lux.Prisms.YouTube.Live.SendChatMessage do
  @moduledoc """
  Sends a text message to a YouTube live chat.
  """

  use Lux.Prism,
    name: "Send YouTube Live Chat Message",
    description: "Sends a text message to the active YouTube live chat",
    input_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        live_chat_id: %{type: :string},
        text: %{type: :string}
      },
      required: ["access_token", "live_chat_id", "text"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveWorkflow

  def handler(input, _context) do
    LiveWorkflow.send_chat_message(
      Client.get(input, :live_chat_id),
      Client.get(input, :text),
      input
    )
  end
end
