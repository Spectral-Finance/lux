defmodule Lux.Prisms.YouTube.OAuth.RefreshToken do
  @moduledoc """
  Refreshes a YouTube OAuth access token.
  """

  use Lux.Prism,
    name: "Refresh YouTube OAuth Token",
    description: "Refreshes an OAuth access token using a refresh token",
    input_schema: %{
      type: :object,
      properties: %{
        client_id: %{type: :string},
        client_secret: %{type: :string},
        refresh_token: %{type: :string}
      },
      required: ["client_id", "client_secret", "refresh_token"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(input, _context), do: Client.refresh_access_token(input, input)
end
