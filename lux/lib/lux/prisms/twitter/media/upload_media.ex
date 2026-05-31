defmodule Lux.Prisms.Twitter.Media.UploadMedia do
  @moduledoc "Runs a single INIT, APPEND, FINALIZE, or STATUS step in the X/Twitter chunked media upload flow."

  use Lux.Prism,
    name: "Twitter Media Upload Step",
    description: "Uploads media through X/Twitter API v2 chunked upload",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["init", "append", "finalize", "status"]},
        media_id: %{type: :string},
        media: %{type: :string},
        access_token: %{type: :string}
      },
      required: ["action"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{action: action} = input, _context) do
    action = if is_binary(action), do: String.to_existing_atom(action), else: action
    opts = Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit])
    params = Map.drop(input, [:action, :access_token, :bearer_token, :plug, :with_rate_limit])

    Client.media_upload(action, params, opts)
  rescue
    ArgumentError -> {:error, "Unsupported media upload action"}
  end

  def handler(_input, _context), do: {:error, "Missing action"}
end
