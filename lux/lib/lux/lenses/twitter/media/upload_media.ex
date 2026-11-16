defmodule Lux.Lenses.Twitter.Media.UploadMedia do
  @moduledoc """
  A lens for uploading media assets (images, GIFs, video chunks) to Twitter/X
  for attachment to tweets.

  ## Examples

      iex> UploadMedia.focus(%{
      ...>   "media_data" => "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
      ...>   "media_category" => "tweet_image"
      ...> })
      {:ok, %{
        media_id_string: "1890000000000000999",
        size: 68
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Upload Twitter Media",
    description: "Uploads base64-encoded media (image, GIF, video) to Twitter and returns a media_id",
    url: "https://upload.twitter.com/1.1/media/upload.json",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        media_data: %{
          type: :string,
          description: "Base64-encoded file content to upload"
        },
        media_category: %{
          type: :string,
          description: "Media category for Twitter processing",
          enum: ["tweet_image", "tweet_gif", "tweet_video"]
        }
      },
      required: ["media_data"]
    }

  @impl true
  def after_focus(%{"media_id_string" => media_id} = body) do
    {:ok,
     %{
       media_id_string: media_id,
       media_id: Map.get(body, "media_id"),
       size: Map.get(body, "size"),
       expires_after_secs: Map.get(body, "expires_after_secs")
     }}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, %{"errors" => errors}}
  end

  def after_focus(error) do
    {:error, error}
  end
end
