defmodule Lux.Prisms.Twitter.Automation.ManageFollow do
  @moduledoc """
  A prism for managing Twitter follow/unfollow operations.

  Enables agents to programmatically follow or unfollow Twitter users
  as part of engagement rules, growth strategies, or community management.

  ## Examples

      iex> ManageFollow.handler(%{
      ...>   action: :follow,
      ...>   source_user_id: "123456789",
      ...>   target_user_id: "987654321"
      ...> }, %{name: "GrowthBot"})
      {:ok, %{success: true, action: :follow, following: true, target_user_id: "987654321"}}

      iex> ManageFollow.handler(%{
      ...>   action: :unfollow,
      ...>   source_user_id: "123456789",
      ...>   target_user_id: "111111111"
      ...> }, %{name: "GrowthBot"})
      {:ok, %{success: true, action: :unfollow, following: false, target_user_id: "111111111"}}
  """

  use Lux.Prism,
    name: "Manage Twitter Follow",
    description: "Follow or unfollow a Twitter user as part of engagement strategy",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["follow", "unfollow"],
          description: "Action to perform: follow or unfollow"
        },
        source_user_id: %{
          type: :string,
          description: "The authenticated user's ID performing the action"
        },
        target_user_id: %{
          type: :string,
          description: "The user ID to follow or unfollow"
        }
      },
      required: ["action", "source_user_id", "target_user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean, description: "Whether the operation was successful"},
        action: %{type: :string, description: "The action that was performed"},
        following: %{type: :boolean, description: "Current following status after the operation"},
        target_user_id: %{type: :string, description: "The user ID that was followed/unfollowed"}
      },
      required: ["success", "action", "target_user_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Follows or unfollows a Twitter user.
  """
  def handler(%{action: action, source_user_id: source_id, target_user_id: target_id}, agent)
      when action in ["follow", "unfollow"] or action in [:follow, :unfollow] do
    action_str = to_string(action)
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} performing #{action_str} on user #{target_id}")

    case action_str do
      "follow" ->
        do_follow(source_id, target_id)

      "unfollow" ->
        do_unfollow(source_id, target_id)
    end
  end

  def handler(_params, _agent) do
    {:error, "Missing or invalid required parameters: action, source_user_id, target_user_id"}
  end

  defp do_follow(source_id, target_id) do
    body = %{"target_user_id" => target_id}

    case Client.request(:post, "/users/#{source_id}/following", %{json: body}) do
      {:ok, %{"data" => %{"following" => following}}} ->
        {:ok, %{success: true, action: "follow", following: following, target_user_id: target_id}}

      {:error, :rate_limited} ->
        {:error, "Rate limit exceeded for follow operations"}

      {:error, {status, message}} ->
        {:error, "Follow failed: #{message} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Follow failed: #{inspect(error)}"}
    end
  end

  defp do_unfollow(source_id, target_id) do
    case Client.request(:delete, "/users/#{source_id}/following/#{target_id}", %{}) do
      {:ok, %{"data" => %{"following" => following}}} ->
        {:ok, %{success: true, action: "unfollow", following: following, target_user_id: target_id}}

      {:error, :rate_limited} ->
        {:error, "Rate limit exceeded for unfollow operations"}

      {:error, {status, message}} ->
        {:error, "Unfollow failed: #{message} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Unfollow failed: #{inspect(error)}"}
    end
  end
end
