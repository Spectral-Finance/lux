defmodule Lux.Lenses.Telegram.GetUpdates do
  @moduledoc """
  Lens for retrieving updates from the Telegram Bot API.

  ## Examples

      Lux.Lenses.Telegram.GetUpdates.focus(%{limit: 10, timeout: 30})
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram Updates",
    description: "Receives incoming updates using long polling",
    url: "https://api.telegram.org/bot:token/getUpdates",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned"
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved",
          minimum: 1,
          maximum: 100,
          default: 100
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling"
        }
      }
    }

  def before_focus(params) do
    Map.put(params, :token, Telegram.token())
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => result}) when is_list(result) do
    updates =
      Enum.map(result, fn update ->
        %{
          update_id: update["update_id"],
          message:
            update["message"] || update["edited_message"] || update["channel_post"] ||
              update["callback_query"]
        }
      end)

    {:ok, updates}
  end

  def after_focus(%{"ok" => false, "description" => description}), do: {:error, description}
  def after_focus(other), do: {:error, other}
end
