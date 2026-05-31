defmodule Lux.Lenses.Twitter.GetFollowing do
  @moduledoc "Reads accounts followed by an X/Twitter user."

  alias Lux.Integrations.Twitter.Client
  alias Lux.Lenses.Twitter.Input

  def view do
    Lux.Lens.new(
      name: "Get Twitter Following",
      module_name: inspect(__MODULE__),
      description: "Reads accounts followed by a user through X/Twitter API v2",
      schema: %{
        type: :object,
        properties: %{
          user_id: %{type: :string},
          user_fields: %{type: :array, items: %{type: :string}},
          max_results: %{type: :integer},
          pagination_token: %{type: :string}
        },
        required: ["user_id"]
      }
    )
  end

  def focus(input, opts \\ [])

  def focus(input, _opts) when is_map(input) do
    input = Input.normalize(input)
    user_id = input[:user_id]

    if is_nil(user_id) do
      {:error, "Missing user_id"}
    else
      opts = Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit])
      params = Map.drop(input, [:user_id, :access_token, :bearer_token, :plug, :with_rate_limit])
      Client.get_following(user_id, params, opts)
    end
  end

  def focus(_input, _opts), do: {:error, "Missing user_id"}
end
