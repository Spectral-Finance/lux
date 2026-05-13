defmodule Lux.Prisms.Discord.Moderation.TimeoutMember do
  @moduledoc """
  A prism for timing out or clearing timeout for a Discord guild member.

  Pass `communication_disabled_until` as an ISO-8601 timestamp. Pass `nil` or
  an empty string to clear an existing timeout.
  """

  use Lux.Prism,
    name: "Timeout Discord Member",
    description: "Sets or clears a Discord member timeout",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        communication_disabled_until: %{
          type: :string,
          description: "ISO-8601 timestamp, nil, or empty string to clear timeout"
        },
        reason: %{type: :string}
      },
      required: ["guild_id", "user_id", "communication_disabled_until"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timed_out: %{type: :boolean},
        guild_id: %{type: :string},
        user_id: %{type: :string},
        communication_disabled_until: %{type: :string}
      },
      required: ["timed_out"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
         {:ok, user_id} <- Helpers.validate_string(params, :user_id),
         {:ok, disabled_until} <- validate_disabled_until(params) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating timeout for user #{user_id} in guild #{guild_id}")

      payload = %{communication_disabled_until: normalize_disabled_until(disabled_until)}
      opts = Helpers.client_opts(params, %{json: payload})

      case Client.request_with_retry(:patch, "/guilds/#{guild_id}/members/#{user_id}", opts) do
        {:ok, response} ->
          {:ok,
           %{
             timed_out: not is_nil(payload.communication_disabled_until),
             guild_id: guild_id,
             user_id: Map.get(response, "user", %{}) |> Map.get("id", user_id),
             communication_disabled_until: payload.communication_disabled_until
           }}

        error ->
          Logger.error("Failed to update Discord timeout for #{user_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp normalize_disabled_until(value) when value in ["", nil], do: nil
  defp normalize_disabled_until(value), do: value

  defp validate_disabled_until(params) do
    cond do
      Map.has_key?(params, :communication_disabled_until) ->
        {:ok, Map.get(params, :communication_disabled_until)}

      Map.has_key?(params, "communication_disabled_until") ->
        {:ok, Map.get(params, "communication_disabled_until")}

      true ->
        {:error, "Missing or invalid communication_disabled_until"}
    end
  end
end
