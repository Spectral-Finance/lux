defmodule Lux.Lenses.Discord.Guilds.ListPresences do
  @moduledoc """
  A lens for retrieving presence information of all members in a Discord guild.

  This lens provides a simple interface for fetching presence data with:
  - Required parameter (guild_id)
  - Optional parameters (limit, after)
  - Direct Discord API error propagation
  - Clean response structure

  Presence information includes:
  - User's online status (online, idle, dnd, offline)
  - Current activities (gaming, streaming, etc.)
  - Client status (desktop, mobile, web)
  - Last activity timestamp

  ## Example
      iex> ListPresences.focus(%{
      ...>   guild_id: "123456789",
      ...>   limit: 100
      ...> })
      {:ok, [
        %{
          user: %{
            id: "111222333",
            username: "user1"
          },
          status: "online",
          activities: [
            %{
              name: "Visual Studio Code",
              type: 0,
              created_at: 1234567890
            }
          ],
          client_status: %{
            desktop: "online",
            mobile: "idle"
          }
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Guild Member Presences",
    description: "Retrieves presence information for all members in a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/presences",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to get presences from",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of presences to return (1-1000)",
          minimum: 1,
          maximum: 1000,
          default: 100
        },
        after: %{
          type: :string,
          description: "Get presences after this user ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into a simplified presence list format.

  ## Parameters
    - response: Raw response from Discord API

  ## Returns
    - `{:ok, presences}` - List of member presences
    - `{:error, reason}` - Error response from Discord API

  ## Examples
      iex> after_focus([
      ...>   %{
      ...>     "user" => %{
      ...>       "id" => "111222333",
      ...>       "username" => "user1"
      ...>     },
      ...>     "status" => "online",
      ...>     "activities" => [
      ...>       %{
      ...>         "name" => "Visual Studio Code",
      ...>         "type" => 0,
      ...>         "created_at" => 1234567890
      ...>       }
      ...>     ],
      ...>     "client_status" => %{
      ...>       "desktop" => "online",
      ...>       "mobile" => "idle"
      ...>     }
      ...>   }
      ...> ])
      {:ok, [
        %{
          user: %{
            id: "111222333",
            username: "user1"
          },
          status: "online",
          activities: [
            %{
              name: "Visual Studio Code",
              type: 0,
              created_at: 1234567890
            }
          ],
          client_status: %{
            desktop: "online",
            mobile: "idle"
          }
        }
      ]}
  """
  @impl true
  def after_focus(presences) when is_list(presences) do
    {:ok, Enum.map(presences, fn presence ->
      %{
        user: %{
          id: presence["user"]["id"],
          username: presence["user"]["username"]
        },
        status: presence["status"],
        activities: Enum.map(presence["activities"] || [], fn activity ->
          %{
            name: activity["name"],
            type: activity["type"],
            created_at: activity["created_at"]
          }
        end),
        client_status: transform_client_status(presence["client_status"] || %{})
      }
    end)}
  end

  def after_focus(%{"message" => message}), do: {:error, %{"message" => message}}

  defp transform_client_status(client_status) do
    Map.new(client_status, fn {platform, status} ->
      {String.to_existing_atom(platform), status}
    end)
  end
end
