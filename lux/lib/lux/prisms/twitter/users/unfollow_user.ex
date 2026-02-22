defmodule Lux.Prisms.Twitter.Users.UnfollowUser do
  @moduledoc """
  A prism for unfollowing a user via the Twitter API v2.

  Removes a follow relationship on behalf of the authenticated user.

  ## Authentication

  Requires OAuth 1.0a User Context authentication.

  ## Rate Limits

  500 unfollow operations per day per user.

  ## Examples

      iex> UnfollowUser.handler(%{
      ...>   user_id: "123456789",
      ...>   target_user_id: "987654321"
      ...> }, %{name: "Agent"})
      {:ok, %{following: false, target_user_id: "987654321"}}

      iex> UnfollowUser.handler(%{
      ...>   user_id: "123456789",
      ...>   target_user_id: "0000000000"
      ...> }, %{name: "Agent"})
      {:error, %{title: "Not Found", detail: "User 0000000000 not found"}}
  """

  use Lux.Prism,
    name: "Unfollow User",
    description: "Unfollows a user on behalf of the authenticated user via Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The authenticated user's ID who is unfollowing",
          pattern: "^[0-9]+$"
        },
        target_user_id: %{
          type: :string,
          description: "The ID of the user to unfollow",
          pattern: "^[0-9]+$"
        }
      },
      required: ["user_id", "target_user_id"]
    }

  alias Lux.Integrations.Twitter

  @twitter_api_base "https://api.twitter.com/2/users"

  @doc """
  Unfollows a user via the Twitter API v2.
  """
  def handler(%{user_id: user_id, target_user_id: target_user_id}, _agent) do
    url = "#{@twitter_api_base}/#{user_id}/following/#{target_user_id}"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", Twitter.build_oauth_header(:delete, url, %{})}
    ]

    [method: :delete, url: url, headers: headers]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> handle_response(target_user_id)
  end

  def handler(%{"user_id" => user_id, "target_user_id" => target_user_id}, agent),
    do: handler(%{user_id: user_id, target_user_id: target_user_id}, agent)

  defp handle_response(
         {:ok, %{status: status, body: %{"data" => %{"following" => following}}}},
         target_user_id
       )
       when status in 200..299 do
    {:ok, %{following: following, target_user_id: target_user_id}}
  end

  defp handle_response({:ok, %{status: 401}}, _target_user_id) do
    {:error, %{title: "Unauthorized", detail: "Invalid or missing OAuth credentials"}}
  end

  defp handle_response({:ok, %{status: 403, body: %{"detail" => detail}}}, _target_user_id) do
    {:error, %{title: "Forbidden", detail: detail}}
  end

  defp handle_response({:ok, %{status: 404}}, target_user_id) do
    {:error, %{title: "Not Found", detail: "User #{target_user_id} not found"}}
  end

  defp handle_response({:ok, %{status: 429}}, _target_user_id) do
    {:error,
     %{title: "Rate Limited", detail: "Twitter API rate limit exceeded. Try again later."}}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _target_user_id) do
    {:error, %{title: "Unexpected response", status: status, detail: inspect(body)}}
  end

  defp handle_response({:error, reason}, _target_user_id) do
    {:error, %{title: "Request failed", detail: inspect(reason)}}
  end
end
