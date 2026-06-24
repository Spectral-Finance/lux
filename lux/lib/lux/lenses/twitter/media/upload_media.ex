defmodule Lux.Lenses.Twitter.Media.UploadMedia do
  @moduledoc """
  A lens for uploading media to Twitter/X via the v1.1 media upload API.

  Supports images, videos, and GIFs. Returns a media ID string which can be
  attached to tweets via `CreateTweet` or `QuoteTweet`.

  ## Examples

      iex> UploadMedia.focus(%{
      ...>   media_data: "/9j/4AAQ...base64...",
      ...>   media_type: "image/jpeg"
      ...> })
      {:ok, %{media_id: "123456789", media_key: "3_123456789"}}

      iex> UploadMedia.focus(%{
      ...>   media_data: "...base64...",
      ...>   media_type: "video/mp4",
      ...>   media_category: "tweet_video"
      ...> })
      {:ok, %{media_id: "123456789", media_key: "3_123456789"}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Upload Media",
    description: "Uploads media (image/video/GIF) to Twitter/X for use in tweets",
    url: "https://upload.twitter.com/1.1/media/upload.json",
    method: :post,
    headers: [{"Content-Type", "application/json"}],
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        media_data: %{
          type: :string,
          description: "Base64-encoded media data"
        },
        media_type: %{
          type: :string,
          description: "MIME type of the media",
          enum: [
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/webp",
            "video/mp4",
            "video/quicktime"
          ]
        },
        media_category: %{
          type: :string,
          description: "Category of the media upload",
          enum: [
            "tweet_image",
            "tweet_video",
            "tweet_gif",
            "dm_image",
            "dm_video",
            "dm_gif",
            "subtitles"
          ]
        },
        additional_owners: %{
          type: :array,
          description: "List of user IDs to grant media access to",
          items: %{type: :string}
        }
      },
      required: ["media_data", "media_type"]
    }

  def after_focus(%{"media_id_string" => media_id, "media_key" => media_key}) do
    {:ok, %{media_id: media_id, media_key: media_key}}
  end

  def after_focus(%{"media_id_string" => media_id}) do
    {:ok, %{media_id: media_id}}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
