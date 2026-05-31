defmodule Lux.Lenses.Twitter.GetUser do
  @moduledoc "Reads an X/Twitter user by ID or username."

  alias Lux.Integrations.Twitter.Client
  alias Lux.Lenses.Twitter.Input

  def view do
    Lux.Lens.new(
      name: "Get Twitter User",
      module_name: inspect(__MODULE__),
      description: "Reads a user through X/Twitter API v2",
      schema: %{
        type: :object,
        properties: %{user_id: %{type: :string}, username: %{type: :string}}
      }
    )
  end

  def focus(input, _opts \\ []) do
    input = Input.normalize(input)
    opts = Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit])

    params =
      Map.drop(input, [
        :user_id,
        :username,
        :access_token,
        :bearer_token,
        :plug,
        :with_rate_limit
      ])

    cond do
      input[:user_id] -> Client.get_user(input[:user_id], params, opts)
      input[:username] -> Client.get_user_by_username(input[:username], params, opts)
      true -> {:error, "Missing user_id or username"}
    end
  end
end
