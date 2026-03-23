defmodule Lux.Prisms.Telegram.Webhook.GetUpdates do
  @moduledoc """
  A prism for receiving incoming updates via long polling via the Telegram Bot API.

  This prism provides an interface to call the getUpdates endpoint, which
  receives incoming updates using long polling. An array of Update objects is returned.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /getUpdates
  - Optional offset, limit, timeout, allowed_updates parameters
  - Returns a list of Update objects

  ## Examples

      iex> GetUpdates.handler(%{limit: 10}, %{name: "Agent"})
      {:ok, %{updates: [%{"update_id" => 123, "message" => %{...}}]}}
  """

  use Lux.Prism,
    name: "Get Telegram Updates",
    description: "Receives incoming updates via long polling from the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          description: "Identifier of the first update to be returned"
        },
        limit: %{
          type: :integer,
          description: "Limits the number of updates to be retrieved (1-100, default 100)"
        },
        timeout: %{
          type: :integer,
          description: "Timeout in seconds for long polling (0 for short polling)"
        },
        allowed_updates: %{
          type: :array,
          description: "A list of the update types you want your bot to receive",
          items: %{type: :string}
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        updates: %{
          type: :array,
          description: "List of Update objects"
        }
      },
      required: ["updates"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to get updates.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} getting updates")

    request_body = Map.take(params, [:offset, :limit, :timeout, :allowed_updates])
    request_opts = %{json: request_body}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/getUpdates", request_opts) do
      {:ok, %{"result" => updates}} ->
        Logger.info("Successfully retrieved #{length(updates)} updates")
        {:ok, %{updates: updates}}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to get updates: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to get updates: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
