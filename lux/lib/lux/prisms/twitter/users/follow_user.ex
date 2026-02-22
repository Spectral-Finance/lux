defmodule Lux.Prisms.Twitter.Users.FollowUser do
  @moduledoc """
  A prism for following a user via the Twitter API v2.

  Follows a target user on behalf of the authenticated user.

  ## Authentication

  Requires OAuth 1.0a User Context authentication.

  ## Rate Limits

  400 follows per day per user.

  ## Examples

      iex> FollowUser.handler(%{
      ...>   user_id: "123456789",
      ...>   target_user_id: "987654321"
      ...> }, %{name: "Agent"})
      {:ok, %{following: true, pending_follow: false, target_user_id: "987654321"}}

      iex> FollowUser.handler(%{
      ...>   user_id: "123456789",
      ...>   target_user_id: "111111111"  # protected account
      ...> }, %{name: "Agent"})
      {:ok, %{following: false, pending_follow: true, target_user_id: "111111111"}}
  """

  use Lux.Prism,
    name: "Follow User",
    description: "Follows a user on behalf of the authenticated user via Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The authenticated user's ID who is following",
          pattern: "^[0-9]+$"
        },
        target_user_id: %{
          type: :string,
          description: "The ID of the user to follow",
          pattern: "^[0-9]+$"
        }
      },
      required: ["user_id", "target_user_id"]
    }

  alias Lux.Integrations.Twitter

  @twitter_api_base "https://api.twitter.com/2/users"

  @doc """
  Follows a user via the Twitter API v2.
  """
  def handler(%{user_id: user_id, target_user_id: target_user_id}, _agent) do
    url = "#{@twitter_api_base}/#{user_id}/following"
    body = %{"target_user_id" => target_user_id}

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", Twitter.build_oauth_header(:post, url, %{})}
    ]

    [method: :post, url: url, headers: headers, json: body]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> handle_response(target_user_id)
  end

  def handler(%{"user_id" => user_id, "target_user_id" => target_user_id}, agent),
    do: handler(%{user_id: user_id, target_user_id: target_user_id}, agent)

  defp handle_response(
         {:ok, %{status: status, body: %{"data" => data}}},
         target_user_id
       )
       when status in 200..299 do
    {:ok,
     %{
       following: data["following"] || false,
       pending_follow: data["pending_follow"] || false,
       target_user_id: target_user_id
     }}
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
