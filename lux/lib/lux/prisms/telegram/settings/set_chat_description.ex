defmodule Lux.Prisms.Telegram.Settings.SetChatDescription do
  @moduledoc """
  A prism to set a new description for a chat.
  Uses Telegram Bot API endpoint: POST /setChatDescription
  """

  use Lux.Prism,
    name: "Set Telegram Chat Description",
    description: "Sets a new description for a chat or channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        description: %{
          type: :string,
          description: "New chat description; 0-255 characters"
        }
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the chat description was successfully set"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id) do
      
      agent_name = agent[:name] || "Unknown Agent"
      desc = fetch_optional(params, :description) || ""
      Logger.info("Agent #{agent_name} setting chat description to '#{desc}' in #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        description: desc
      }

      case Client.request(:post, "/setChatDescription", %{json: request_body}) do
        {:ok, %{"ok" => true}} ->
          Logger.info("Successfully set chat description in chat #{chat_id}")
          {:ok, %{success: true}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to set chat description: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set chat description: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set chat description: #{inspect(error)}"}
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

  defp fetch_optional(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} -> val
      :error -> Map.get(params, to_string(key))
    end
  end
end
