defmodule Lux.Prisms.Telegram.Management.LogOut do
  @moduledoc """
  A prism for logging out from the cloud Bot API server via the Telegram Bot API.

  This prism provides an interface to call the logOut endpoint. After calling this
  method, you can immediately log in on a local server, but will not be able to
  log in back to the cloud Bot API server for 10 minutes.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /logOut
  - No required parameters
  - Returns true on success

  ## Examples

      iex> LogOut.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true}}
  """

  use Lux.Prism,
    name: "Telegram Bot Log Out",
    description: "Logs out from the cloud Bot API server via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{},
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the log out was successful"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to log out from the cloud Bot API server.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} logging out from cloud Bot API server")

    request_opts = %{json: %{}}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/logOut", request_opts) do
      {:ok, %{"result" => true}} ->
        Logger.info("Successfully logged out")
        {:ok, %{success: true}}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to log out: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to log out: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
