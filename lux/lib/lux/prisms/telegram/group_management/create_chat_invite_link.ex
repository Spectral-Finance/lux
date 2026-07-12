defmodule Lux.Prisms.Telegram.GroupManagement.CreateChatInviteLink do
  @moduledoc """
  A prism for creating an additional invite link for a chat via the Telegram Bot API.

  ## Examples

      iex> CreateChatInviteLink.handler(%{
      ...>   chat_id: 123_456_789
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, invite_link: "https://t.me/joinchat/..."}}
  """

  use Lux.Prism,
    name: "Create Chat Invite Link",
    description: "Creates an additional invite link for a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        name: %{
          type: :string,
          description: "Invite link name"
        },
        expire_date: %{
          type: :integer,
          description: "Point in time when the link will expire, unix time"
        },
        member_limit: %{
          type: :integer,
          description: "Maximum number of users that can be members of the chat simultaneously"
        },
        creates_join_request: %{
          type: :boolean,
          description: "True, if users joining the chat via the link need to be approved by chat administrators"
        }
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the operation was successful"
        },
        invite_link: %{
          type: :string,
          description: "The newly created invite link"
        }
      },
      required: ["success", "invite_link"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} attempting to create invite link for chat #{chat_id}")

      request_body = Map.take(params, [:chat_id, :name, :expire_date, :member_limit, :creates_join_request])
      request_opts = %{json: request_body}
      request_opts = if params[:plug], do: Map.put(request_opts, :plug, params[:plug]), else: request_opts

      case Client.request(:post, "/createChatInviteLink", request_opts) do
        {:ok, %{"result" => %{"invite_link" => link}}} ->
          Logger.info("Successfully created invite link for chat #{chat_id}")
          {:ok, %{success: true, invite_link: link}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to create invite link: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to create invite link: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to create invite link: #{inspect(error)}"}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
