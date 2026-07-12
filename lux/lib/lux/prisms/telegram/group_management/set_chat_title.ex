defmodule Lux.Prisms.Telegram.GroupManagement.SetChatTitle do
  @moduledoc """
  A prism for changes the title of a chat via the Telegram Bot API.

  ## Examples

      iex> SetChatTitle.handler(%{
      ...>   chat_id: 123_456_789,
...>   title: "New Title"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, chat_id: 123_456_789}}
  """

  use Lux.Prism,
    name: "Set Chat Title",
    description: "Changes the title of a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        title: %{
          type: :string,
          description: "New chat title, 1-128 characters"
        }
      },
      required: ["chat_id", "title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the operation was successful"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Identifier of the target chat"
        }
      },
      required: ["success", "chat_id"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, _} <- validate_param(params, :title) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} attempting to set chat title in chat #{chat_id}")

      request_body = Map.take(params, [:chat_id, :title])
      request_opts = %{json: request_body}
      request_opts = if params[:plug], do: Map.put(request_opts, :plug, params[:plug]), else: request_opts

      case Client.request(:post, "/setChatTitle", request_opts) do
        {:ok, %{"result" => true}} ->
          Logger.info("Successfully completed set chat title in chat #{chat_id}")
          {:ok, %{success: true, chat_id: chat_id}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to set chat title: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set chat title: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set chat title: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, value} when is_map(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
