defmodule Lux.Lenses.YouTube.Videos.DeleteVideo do
  @moduledoc """
  A lens for deleting a video from YouTube.

  ## Parameters

  - `video_id`: YouTube video ID to delete (required)
  - `notify_subscribers`: Whether to notify subscribers (default: true)

  ## Examples

      iex> DeleteVideo.focus(%{
      ...>   video_id: "dQw4w9WgXcQ"
      ...> })
      {:ok, %{deleted: true, video_id: "dQw4w9WgXcQ"}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Delete YouTube Video",
    description: "Deletes a video from YouTube",
    url: "#{YouTube.api_base_url()}/videos",
    method: :delete,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "YouTube video ID to delete",
          pattern: "^[a-zA-Z0-9_-]{11}$"
        },
        notify_subscribers: %{
          type: :boolean,
          description: "Whether to notify subscribers of deletion",
          default: true
        }
      },
      required: ["video_id"]
    }

  @impl true
  def before_focus(params) do
    video_id = params[:video_id]
    notify = Map.get(params, :notify_subscribers, true)
    %{url: "#{YouTube.api_base_url()}/videos?id=#{video_id}&notifySubscribers=#{notify}"}
  end

  @doc """
  Transforms the deletion response.
  """
  @impl true
  def after_focus(%{"id" => video_id}) do
    Logger.info("Successfully deleted video: #{video_id}")
    {:ok, %{deleted: true, video_id: video_id}}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}
end
