defmodule Lux.Lenses.Telegram.GetChatAdministrators do
  @moduledoc """
  A lens to fetch the list of administrators in a Telegram chat.
  Uses Telegram Bot API endpoint: POST /getChatAdministrators
  """

  use Lux.Lens,
    name: "Get Telegram Chat Administrators",
    description: "Fetches the list of administrators in a Telegram chat",
    url: "https://api.telegram.org/bot/getChatAdministrators",
    method: :post,
    headers: Lux.Integrations.Telegram.headers(),
    auth: Lux.Integrations.Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        }
      },
      required: ["chat_id"]
    }

  @impl true
  def before_focus(params) do
    # Ensure keys are formatted correctly and we support both string and atom keys
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    # For POST request in Lux.Lens, the body is serialized from the params
    %{chat_id: chat_id}
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => admins}) when is_list(admins) do
    # Map over admins and return simplified structure
    transformed = Enum.map(admins, fn admin ->
      %{
        status: admin["status"],
        user: %{
          id: admin["user"]["id"],
          is_bot: admin["user"]["is_bot"],
          first_name: admin["user"]["first_name"],
          last_name: admin["user"]["last_name"] || "",
          username: admin["user"]["username"] || ""
        },
        custom_title: admin["custom_title"] || "",
        is_anonymous: admin["is_anonymous"] || false
      }
    end)
    {:ok, transformed}
  end

  def after_focus(%{"ok" => false, "description" => desc}) do
    {:error, desc}
  end

  def after_focus(other) do
    {:error, "Unexpected response: #{inspect(other)}"}
  end
end
