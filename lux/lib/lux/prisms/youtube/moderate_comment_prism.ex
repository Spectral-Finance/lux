defmodule Lux.Prisms.YouTube.ModerateCommentPrism do
  use Lux.Prism,
    name: "Moderate YouTube Comment",
    description: "Sets the moderation status of a YouTube comment",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        moderationStatus: %{type: :string, enum: ["heldForReview", "published", "rejected"]},
        dry_run: %{type: :boolean, default: false}
      },
      required: ["id", "moderationStatus"]
    }

  def handler(%{id: id, moderationStatus: status} = input, _ctx) do
    dry_run = Map.get(input, :dry_run, false)
    if dry_run do
      {:ok, %{id: id, status: status, dry_run: true}}
    else
      api_key = Lux.Config.youtube_api_key()
      req = Req.new(url: "https://youtube.googleapis.com/youtube/v3/comments/setModerationStatus")
      opts = [
        method: :post,
        params: %{id: id, moderationStatus: status, key: api_key}
      ]
      case Req.request(req, opts) do
        {:ok, %{status: 204}} -> {:ok, %{id: id, status: status}}
        {:ok, %{status: status_code, body: body}} -> {:error, "API returned \#{status_code}: \#{inspect(body)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
