defmodule Lux.Lenses.Telegram.Bot.GetMe do
  @moduledoc """
  A lens for retrieving information about the Telegram bot.

  Returns basic information about the bot's identity including its ID,
  username, first name, and supported capabilities.

  ## Examples

      iex> GetMe.focus(%{}, %{})
      {:ok, %{
        id: 123456789,
        is_bot: true,
        first_name: "MyBot",
        username: "mybot",
        can_join_groups: true,
        can_read_all_group_messages: false,
        supports_inline_queries: false
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Bot Info",
    description: "Retrieves basic information about the Telegram bot",
    url: "https://api.telegram.org/bot/getMe",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{}
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => bot}) do
    {:ok, %{
      id: bot["id"],
      is_bot: bot["is_bot"],
      first_name: bot["first_name"],
      last_name: bot["last_name"],
      username: bot["username"],
      can_join_groups: bot["can_join_groups"],
      can_read_all_group_messages: bot["can_read_all_group_messages"],
      supports_inline_queries: bot["supports_inline_queries"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end
end
