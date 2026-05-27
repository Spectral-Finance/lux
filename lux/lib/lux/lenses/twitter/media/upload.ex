defmodule Lux.Lenses.Twitter.Media.Upload do
  @moduledoc """
  Uploads media (image, video, GIF) to Twitter for attaching to Tweets.

  Uses the Twitter v1.1 media upload endpoint via INIT/APPEND/FINALIZE flow.

  ## Examples

      # Upload an image
      Lux.Lenses.Twitter.Media.Upload.focus(%{
        media_data: "...base64-encoded-image-data...",
        media_type: "image/jpeg"
      })
  """

  use Lux.Lens,
    name: "Twitter / Media Upload",
    description: "Uploads media (images, video, GIFs) for attachment to Tweets",
    url: "https://upload.twitter.com/1.1/media/upload.json",
    method: :post,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        media_data: %{type: :string, description: "Base64-encoded media data"},
        media_type: %{type: :string, description: "MIME type (image/jpeg, image/png, video/mp4)"},
        media_category: %{type: :string, description: "Category (tweet_image, tweet_video, tweet_gif)", default: "tweet_image"},
        additional_owners: %{type: :string, description: "Comma-separated user IDs for co-ownership"}
      },
      required: ["media_data", "media_type"]
    },
    transform: &__MODULE__.transform_response/1

  @doc false
  def transform_response(response) do
    case response do
      %{status: 200, body: %{"media_id_string" => media_id}} ->
        {:ok, %{media_id: media_id, media_id_string: media_id}}

      %{status: status, body: body} ->
        {:error, %{status: status, body: body}}
    end
  end
end
