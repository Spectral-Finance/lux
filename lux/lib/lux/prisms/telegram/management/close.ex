defmodule Lux.Prisms.Telegram.Management.Close do
  @moduledoc """
  A prism for closing the bot instance via the Telegram Bot API.

  This prism provides an interface to call the close endpoint. Use this method
  to close the bot instance before moving it from one local server to another.
  The method will return error 429 in the first 10 minutes after the bot is started.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /close
  - No required parameters
  - Returns true on success

  ## Examples

      iex> Close.handler(%{}, %{name: "Agent"})
      {:ok, %{success: true}}
  """

  use Lux.Prism,
    name: "Close Telegram Bot Instance",
    description: "Closes the bot instance via the Telegram Bot API",
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
          description: "Whether the close was successful"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to close the bot instance.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} closing bot instance")

    request_opts = %{json: %{}}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/close", request_opts) do
      {:ok, %{"result" => true}} ->
        Logger.info("Successfully closed bot instance")
        {:ok, %{success: true}}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to close bot: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to close bot: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
