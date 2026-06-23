defmodule Lux.Prisms.YouTube.ReplyToCommentPrism do
  use Lux.Prism,
    name: "Reply to YouTube Comment",
    description: "Inserts a reply to an existing YouTube comment",
    input_schema: %{
      type: :object,
      properties: %{
        parentId: %{type: :string},
        textOriginal: %{type: :string}
      },
      required: ["parentId", "textOriginal"]
    }

  def handler(%{parentId: parent_id, textOriginal: text} = _input, _ctx) do
    api_key = Lux.Config.youtube_api_key()
    req = Req.new(url: "https://youtube.googleapis.com/youtube/v3/comments")
    opts = [
      method: :post,
      params: %{part: "snippet", key: api_key},
      json: %{
        "snippet" => %{
          "parentId" => parent_id,
          "textOriginal" => text
        }
      }
    ]

    case Req.request(req, opts) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status_code, body: body}} -> {:error, "API returned \#{status_code}: \#{inspect(body)}"}
      {:error, reason} -> {:error, reason}
    end
  end
end
