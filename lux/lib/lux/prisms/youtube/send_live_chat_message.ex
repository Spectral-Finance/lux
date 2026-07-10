defmodule Lux.Prisms.YouTube.SendLiveChatMessage do
  @moduledoc """
  A prism for sending/inserting live chat messages on a YouTube live broadcast.
  """

  use Lux.Prism,
    name: "Send YouTube Live Chat Message",
    description: "Sends a text message to a YouTube live chat stream",
    input_schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{
          type: :string,
          description: "The live chat ID of the broadcast"
        },
        message_text: %{
          type: :string,
          description: "The text message content to send",
          minLength: 1,
          maxLength: 140
        },
        access_token: %{
          type: :string,
          description: "OAuth2 access token"
        },
        dry_run: %{
          type: :boolean,
          description: "If true, mock sending the message without hitting the YouTube API",
          default: false
        }
      },
      required: ["live_chat_id", "message_text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether the message was successfully sent"
        },
        message_id: %{
          type: :string,
          description: "The YouTube message ID"
        },
        message_text: %{
          type: :string,
          description: "The text of the sent message"
        }
      },
      required: ["sent"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.Utils
  require Logger

  def handler(params, agent) do
    params = Utils.normalize_to_atoms(params)
    agent_name = agent[:name] || "Unknown Agent"

    live_chat_id = Map.get(params, :live_chat_id)
    message_text = Map.get(params, :message_text)
    access_token = Map.get(params, :access_token)
    plug = Map.get(params, :plug)

    dry_run = Map.get(params, :dry_run) || Application.get_env(:lux, :youtube_dry_run, false) || System.get_env("YOUTUBE_DRY_RUN") == "true"

    Logger.info("Agent #{agent_name} sending live chat message: #{message_text}")

    body = %{
      snippet: %{
        liveChatId: live_chat_id,
        type: "textMessageEvent",
        textMessageDetails: %{
          messageText: message_text
        }
      }
    }

    case Client.request(:post, "/liveChat/messages", %{
      params: %{part: "snippet"},
      access_token: access_token,
      plug: plug,
      dry_run: dry_run,
      json: body
    }) do
      {:ok, %{"id" => message_id, "snippet" => %{"textMessageDetails" => %{"messageText" => sent_text}}}} ->
        {:ok, %{sent: true, message_id: message_id, message_text: sent_text}}

      {:ok, %{"id" => message_id}} ->
        {:ok, %{sent: true, message_id: message_id, message_text: message_text}}

      {:error, error} ->
        Logger.error("Failed to send live chat message: #{inspect(error)}")
        {:error, error}
    end
  end
end
