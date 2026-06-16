defmodule Lux.Lenses.Telegram.GetFile do
  @moduledoc """
  A lens for retrieving info about a file from the Telegram Bot API.

  This lens gets basic info about a file and prepares it for downloading.

  ## Examples

      iex> GetFile.focus(%{file_id: "file_123"})
      {:ok, %{"file_id" => "file_123", "file_size" => 1234, "file_path" => "photos/file_0.jpg"}}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram File Info",
    description: "Retrieves basic info about a file and prepares it for downloading using getFile",
    url: "https://api.telegram.org/bot:token/getFile",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        file_id: %{
          type: :string,
          description: "File identifier to get info about"
        }
      },
      required: ["file_id"]
    }

  @impl true
  def after_focus(%{"ok" => true, "result" => file_info}) when is_map(file_info) do
    {:ok, file_info}
  end

  @impl true
  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  @impl true
  def after_focus(other) do
    {:error, "Unexpected response format: #{inspect(other)}"}
  end
end
