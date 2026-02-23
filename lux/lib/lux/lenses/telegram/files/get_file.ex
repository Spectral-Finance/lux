defmodule Lux.Lenses.Telegram.Files.GetFile do
  @moduledoc """
  A lens for retrieving file information from the Telegram Bot API.

  Returns information about a file including the path needed to download it.
  The file can be downloaded via `https://api.telegram.org/file/bot<token>/<file_path>`.

  Note: For security reasons, the download link expires after 1 hour.

  ## Examples

      iex> GetFile.focus(%{file_id: "BQACAgIAAxkBAAIBXl..."}, %{})
      {:ok, %{
        file_id: "BQACAgIAAxkBAAIBXl...",
        file_unique_id: "AgADXXX",
        file_size: 102400,
        file_path: "documents/file_1234.pdf"
      }}
  """

  alias Lux.Integrations.Telegram

  use Lux.Lens,
    name: "Get Telegram File",
    description: "Retrieves file information and download path from the Telegram Bot API",
    url: "https://api.telegram.org/bot/getFile",
    method: :get,
    headers: Telegram.headers(),
    auth: Telegram.auth(),
    schema: %{
      type: :object,
      properties: %{
        file_id: %{
          type: :string,
          description: "File identifier to get information about"
        }
      },
      required: ["file_id"]
    }

  @impl true
  def before_focus(params) do
    case params[:file_id] || params["file_id"] do
      nil -> {:error, "file_id is required"}
      file_id -> {:ok, %{"file_id" => file_id}}
    end
  end

  @impl true
  def after_focus(%{"ok" => true, "result" => file}) do
    {:ok, %{
      file_id: file["file_id"],
      file_unique_id: file["file_unique_id"],
      file_size: file["file_size"],
      file_path: file["file_path"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()}
  end

  def after_focus(%{"ok" => false, "description" => description}) do
    {:error, description}
  end

  def after_focus(response) do
    {:error, response}
  end
end
