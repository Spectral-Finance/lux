defmodule Lux.Lenses.Telegram.Bot.GetMe do
  @moduledoc """
  A lens for getting basic information about the bot via the Telegram Bot API.

  This lens provides a simple interface to test the bot's auth token and get
  basic bot information. Requires no parameters.

  ## Examples

      iex> GetMe.focus(%{})
      {:ok, %{
        id: 123_456_789,
        is_bot: true,
        first_name: "MyBot",
        username: "my_bot",
        can_join_groups: true,
        can_read_all_group_messages: false,
        supports_inline_queries: false
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Bot Info",
    description: "Returns basic information about the bot",
    url: Telegram.api_url("getMe"),
    method: :post,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  @doc """
  Transforms the Telegram API response into a clean format.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, %{
      id: result["id"],
      is_bot: result["is_bot"],
      first_name: result["first_name"],
      username: result["username"],
      can_join_groups: result["can_join_groups"],
      can_read_all_group_messages: result["can_read_all_group_messages"],
      supports_inline_queries: result["supports_inline_queries"]
    }}
  end

  def after_focus(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => retry_after}} = error) do
    {:error, %{
      reason: :rate_limited,
      retry_after: retry_after,
      description: error["description"]
    }}
  end

  def after_focus(%{"ok" => false, "description" => description, "error_code" => code}) do
    {:error, %{reason: :api_error, error_code: code, description: description}}
  end

  def after_focus(%{"description" => description}) do
    {:error, %{reason: :api_error, description: description}}
  end
end
