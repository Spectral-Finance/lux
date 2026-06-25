defmodule Lux.Lenses.Telegram.Analytics.GetChatStats do
  @moduledoc """
  A lens for gathering Telegram chat and bot usage analytics.

  Fetches member count, chat information, and administrator list
  to build engagement and growth metrics for bot analytics dashboards.

  ## Examples

      iex> GetChatStats.focus(%{chat_id: -1001234567890})
      {:ok, %{
        chat_id: -1001234567890,
        title: "My Group",
        member_count: 1542,
        type: "supergroup",
        admins: [...]
      }}
  """

  alias Lux.Integrations.Telegram.Client
  require Logger

  use Lux.Lens,
    name: "Get Telegram Chat Stats",
    description: "Fetches chat metadata and member count for analytics",
    url: "https://api.telegram.org",
    method: :get,
    headers: [],
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Chat ID or @username"
        },
        include_admins: %{
          type: :boolean,
          description: "Whether to also fetch the admin list",
          default: false
        }
      },
      required: ["chat_id"]
    }

  @impl true
  def focus(%{chat_id: chat_id} = params) do
    with {:ok, %{"result" => chat}}  <- Client.request(:get, "/getChat",    %{params: %{chat_id: chat_id}}),
         {:ok, %{"result" => count}} <- Client.request(:get, "/getChatMemberCount", %{params: %{chat_id: chat_id}}) do

      admins = if Map.get(params, :include_admins, false) do
        case Client.request(:get, "/getChatAdministrators", %{params: %{chat_id: chat_id}}) do
          {:ok, %{"result" => list}} ->
            Enum.map(list, fn a -> %{user_id: get_in(a, ["user", "id"]),
                                     username: get_in(a, ["user", "username"]),
                                     status: a["status"]} end)
          _ -> []
        end
      else
        []
      end

      stats = %{
        chat_id:      chat_id,
        title:        chat["title"],
        type:         chat["type"],
        username:     chat["username"],
        description:  chat["description"],
        member_count: count,
        admins:       admins,
        invite_link:  chat["invite_link"]
      }

      Logger.info("Retrieved stats for chat #{chat_id}: #{count} members")
      {:ok, stats}
    else
      {:error, {status, %{"description" => desc}}} -> {:error, "#{desc} (HTTP #{status})"}
      {:error, reason} -> {:error, reason}
    end
  end
end
