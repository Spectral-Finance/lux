defmodule Lux.Prisms.Twitter.Tweets.CreateThread do
  @moduledoc "Creates an X/Twitter thread by posting each item as a reply to the previous post."

  use Lux.Prism,
    name: "Create Twitter Thread",
    description: "Creates a thread through X/Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        texts: %{type: :array, items: %{type: :string}, minItems: 1},
        access_token: %{type: :string}
      },
      required: ["texts"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{texts: texts} = input, _context) when is_list(texts) do
    Client.create_thread(texts, Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit]))
  end

  def handler(_input, _context), do: {:error, "Missing texts"}
end
