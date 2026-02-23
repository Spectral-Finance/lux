defmodule Lux.Lenses.Twitter.Automation.GetFollowers do
  @moduledoc """
  A lens for retrieving a user's Twitter followers list.

  Enables agents to access follower data for audience analysis,
  targeting for engagement rules, and follow/unfollow management.

  ## Examples

      iex> GetFollowers.focus(%{
      ...>   "user_id" => "123456789",
      ...>   "max_results" => 100
      ...> }, %{})
      {:ok, %{followers: [...], result_count: 100}}
  """

  use Lux.Lens,
    name: "Get Twitter Followers",
    description: "Retrieve a user's followers list for audience management",
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "Twitter user ID whose followers to retrieve"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of followers to return (1-1000)",
          minimum: 1,
          maximum: 1000
        },
        user_fields: %{
          type: :array,
          items: %{type: :string},
          description: "User fields to include: id, name, username, description, public_metrics, etc."
        },
        pagination_token: %{
          type: :string,
          description: "Token for paginating results"
        }
      },
      required: ["user_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @default_user_fields ["id", "name", "username", "description", "public_metrics", "created_at"]

  defoverridable focus: 2

  @doc """
  Fetches the followers list for the given user.
  """
  def focus(params, _context) do
    user_id = params["user_id"] || params[:user_id]
    max_results = params["max_results"] || params[:max_results] || 100
    user_fields = params["user_fields"] || params[:user_fields] || @default_user_fields

    query_params =
      %{
        "max_results" => max_results,
        "user.fields" => Enum.join(user_fields, ",")
      }
      |> maybe_add_param(params, "pagination_token")

    Logger.info("Fetching followers for user: #{user_id}")

    case Client.request(:get, "/users/#{user_id}/followers", %{params: query_params}) do
      {:ok, %{"data" => users, "meta" => meta}} ->
        {:ok, %{
          followers: Enum.map(users, &format_user/1),
          result_count: meta["result_count"] || length(users),
          next_token: meta["next_token"]
        }}

      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, %{followers: [], result_count: 0}}

      {:error, error} ->
        Logger.error("Failed to get followers for user #{user_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp format_user(user) do
    %{
      id: user["id"],
      name: user["name"],
      username: user["username"],
      description: user["description"],
      metrics: user["public_metrics"] || %{},
      created_at: user["created_at"]
    }
  end

  defp maybe_add_param(params, source, key) do
    val = source[key] || source[String.to_atom(key)]
    case val do
      nil -> params
      value -> Map.put(params, key, value)
    end
  end
end
