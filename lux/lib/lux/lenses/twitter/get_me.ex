defmodule Lux.Lenses.Twitter.GetMe do
  @moduledoc "Reads the authenticated X/Twitter user's profile."

  alias Lux.Integrations.Twitter.Client
  alias Lux.Lenses.Twitter.Input

  def view do
    Lux.Lens.new(
      name: "Get Authenticated Twitter User",
      module_name: inspect(__MODULE__),
      description: "Reads the authenticated user's profile through X/Twitter API v2",
      schema: %{
        type: :object,
        properties: %{user_fields: %{type: :array, items: %{type: :string}}}
      }
    )
  end

  def focus(input \\ %{}, _opts \\ []) do
    input = Input.normalize(input)
    opts = Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit])
    params = Map.drop(input, [:access_token, :bearer_token, :plug, :with_rate_limit])
    Client.get_me(params, opts)
  end
end
