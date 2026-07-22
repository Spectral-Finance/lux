defmodule Lux.Prisms.Telegram.Settings.SetChatTitle do
  @moduledoc """
  A prism to set a new title for a chat.
  Uses Telegram Bot API endpoint: POST /setChatTitle
  """

  use Lux.Prism,
    name: "Set Telegram Chat Title",
    description: "Sets a new title for a chat or channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        title: %{
          type: :string,
          description: "New chat title; 1-128 characters"
        }
      },
      required: ["chat_id", "title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the chat title was successfully set"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id),
         {:ok, title} <- fetch_param(params, :title) do
      
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting chat title to '#{title}' in #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        title: title
      }

      case Client.request(:post, "/setChatTitle", %{json: request_body}) do
        {:ok, %{"ok" => true}} ->
          Logger.info("Successfully set chat title in chat #{chat_id}")
          {:ok, %{success: true}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to set chat title: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set chat title: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set chat title: #{inspect(error)}"}
      end
    end
  end

  defp fetch_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} -> {:ok, val}
      :error ->
        case Map.fetch(params, to_string(key)) do
          {:ok, val} -> {:ok, val}
          :error -> {:error, "Missing or invalid #{key}"}
        end
    end
  end
end
