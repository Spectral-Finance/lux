defmodule Lux.Prisms.YouTube.OAuth.ExchangeCode do
  @moduledoc """
  Exchanges a YouTube OAuth authorization code for tokens.
  """

  use Lux.Prism,
    name: "Exchange YouTube OAuth Code",
    description: "Exchanges an OAuth authorization code for YouTube API tokens",
    input_schema: %{
      type: :object,
      properties: %{
        client_id: %{type: :string},
        client_secret: %{type: :string},
        code: %{type: :string},
        redirect_uri: %{type: :string}
      },
      required: ["client_id", "client_secret", "code", "redirect_uri"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(input, _context), do: Client.exchange_code(input, input)
end
