defmodule Lux.Lenses.Telegram.Updates.GetUpdates do
  @moduledoc """
  A lens for receiving incoming updates using long polling.
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Telegram Get Updates",
    description: "Use this method to receive incoming updates using long polling.",
    url: "https://api.telegram.org/bot<token>/getUpdates",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned."
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved. Values between 1-100 are accepted."
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling."
        }
      }
    }

  @doc """
  Transforms the Telegram API response.
  """
  @impl true
  def after_focus(%{"ok" => true, "result" => result}) do
    {:ok, result}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end
  
  def after_focus(other), do: {:error, other}
end
