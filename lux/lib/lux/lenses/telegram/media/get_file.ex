defmodule Lux.Lenses.Telegram.Media.GetFile do
  @moduledoc """
  A lens for getting file info from Telegram.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Lens,
    name: "Get Telegram File",
    description: "Gets file info from Telegram by file ID",
    url: "https://api.telegram.org/bot/:token/getFile",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        file_id: %{type: :string, description: "The file ID to get info for"}
      },
      required: ["file_id"]
    }

  @impl true
  def focus(%{file_id: file_id}) do
    case Client.request(:get, "/getFile?file_id=#{file_id}") do
      {:ok, %{"result" => file}} ->
        {:ok, %{
          file_id: file["file_id"],
          file_unique_id: file["file_unique_id"],
          file_size: file["file_size"],
          file_path: file["file_path"],
          file_url: build_file_url(file["file_path"])
        }}

      {:error, {status, description}} ->
        {:error, %{status: status, description: description}}

      {:error, error} ->
        {:error, %{error: inspect(error)}}
    end
  end

  defp build_file_url(nil), do: nil
  defp build_file_url(file_path) do
    token = Lux.Config.telegram_bot_token()
    "https://api.telegram.org/file/bot#{token}/#{file_path}"
  end
end
