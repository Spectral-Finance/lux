defmodule Lux.Lenses.Twitter.UploadMedia do
  @moduledoc """
  Lens for uploading media to Twitter (v1.1 API).

  ## Examples
      Lux.Lenses.Twitter.UploadMedia.focus(%{media: "base64encodedstring...", media_category: "tweet_image"})
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Upload Media",
    description: "Uploads media (images, video, gif) for use in tweets",
    url: "https://upload.twitter.com/1.1/media/upload.json",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        media: %{type: :string, description: "Base64 encoded media or URL"},
        media_category: %{
          type: :string,
          enum: ["tweet_image", "tweet_video", "tweet_gif"],
          description: "Category of the media"
        }
      },
      required: ["media"]
    }

  @impl true
  def after_focus(%{"media_id_string" => media_id, "size" => size, "expires_after_secs" => expires}) do
    {:ok,
     %{
       media_id_string: media_id,
       size: size,
       expires_after_secs: expires
     }}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:error, other}
end
