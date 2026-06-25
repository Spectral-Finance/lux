defmodule Lux.Prisms.Twitter.GetUserById do
  @moduledoc """
  A prism for fetching a Twitter user by their ID.

  ## Examples

      iex> GetUserById.handler(%{user_id: "123456"}, %{name: "Agent"})
      {:ok, %{id: "123456", name: "John Doe", username: "johndoe"}}
  """

  use Lux.Prism,
    name: "Get User By ID",
    description: "Fetches a Twitter user's profile by their user ID",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The Twitter user ID"
        },
        user.fields: %{
          type: :string,
          description: "Comma-separated list of user fields to return"
        }
      },
      required: ["user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The user's Twitter ID"},
        name: %{type: :string, description: "Display name"},
        username: %{type: :string, description: "Twitter username"},
        verified: %{type: :boolean, description: "Whether the user is verified"}
      },
      required: ["id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles fetching a user by ID.

  Returns {:ok, %{id, name, username, ...}} on success.
  """
  def handler(params, agent) do
    with {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, fields} <- validate_optional_string(params, "user.fields") do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching user #{user_id}")

      url = build_url(user_id, fields)

      case Client.request(:get, url) do
        {:ok, %{"data" => user}} ->
          Logger.info("Successfully fetched user #{user_id}: #{user["username"]}")
          {:ok, Map.take(user, ["id", "name", "username", "verified", "description", "public_metrics"])}

        {:error, {status, %{"errors" => errors}}} when is_list(errors) ->
          error_msg = List.first(errors) |> Map.get("message", "User not found")
          Logger.error("Failed to fetch user: #{error_msg}")
          {:error, {status, error_msg}}

        {:error, error} ->
          Logger.error("Failed to fetch user: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_url(user_id, nil), do: "/users/#{user_id}"
  defp build_url(user_id, fields), do: "/users/#{user_id}?user.fields=#{fields}"

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_string(params, key, default \\ "") do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      :error -> {:ok, default}
      _ -> {:error, "Invalid #{key}"}
    end
  end
end
