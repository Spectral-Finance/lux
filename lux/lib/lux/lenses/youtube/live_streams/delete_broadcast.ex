defmodule Lux.Lenses.YouTube.LiveStreams.DeleteBroadcast do
  @moduledoc """
  A lens for deleting a YouTube live broadcast.

  Removes the broadcast resource while optionally keeping the associated
  live stream and video.

  ## Parameters

  - `broadcast_id`: YouTube broadcast ID to delete (required)
  - `notify_subscribers`: Whether to notify subscribers of deletion

  ## Examples

      iex> DeleteBroadcast.focus(%{
      ...>   broadcast_id: "abc123..."
      ...> })
      {:ok, %{deleted: true, broadcast_id: "abc123..."}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Delete YouTube Broadcast",
    description: "Deletes a YouTube live broadcast resource",
    url: "#{YouTube.api_base_url()}/liveBroadcasts",
    method: :delete,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{
          type: :string,
          description: "YouTube broadcast ID to delete",
          pattern: "^[a-zA-Z0-9_-]+$"
        },
        notify_subscribers: %{
          type: :boolean,
          description: "Whether to notify subscribers of deletion",
          default: true
        }
      },
      required: ["broadcast_id"]
    }

  @impl true
  def before_focus(params) do
    broadcast_id = params[:broadcast_id]
    notify = Map.get(params, :notify_subscribers, true)
    %{url: "#{YouTube.api_base_url()}/liveBroadcasts?id=#{broadcast_id}&notifySubscribers=#{notify}"}
  end

  @doc """
  Transforms the deletion response.
  """
  @impl true
  def after_focus(%{"id" => broadcast_id}) do
    Logger.info("Successfully deleted broadcast: #{broadcast_id}")
    {:ok, %{deleted: true, broadcast_id: broadcast_id}}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}
end
