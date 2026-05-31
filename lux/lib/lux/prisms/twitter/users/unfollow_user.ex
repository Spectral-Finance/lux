defmodule Lux.Prisms.Twitter.Users.UnfollowUser do
  @moduledoc "Unfollows a target X/Twitter user from an authenticated source user."

  use Lux.Prism,
    name: "Unfollow Twitter User",
    description: "Unfollows a user through X/Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        source_user_id: %{type: :string},
        target_user_id: %{type: :string},
        access_token: %{type: :string}
      },
      required: ["source_user_id", "target_user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{source_user_id: source_id, target_user_id: target_id} = input, _context) do
    Client.unfollow_user(
      source_id,
      target_id,
      Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit])
    )
  end

  def handler(_input, _context), do: {:error, "Missing source_user_id or target_user_id"}
end
