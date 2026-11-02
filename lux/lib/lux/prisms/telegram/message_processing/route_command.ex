defmodule Lux.Prisms.Telegram.MessageProcessing.RouteCommand do
  @moduledoc """
  A prism for matching parsed commands against registered routes and executing or dispatching them.
  """

  use Lux.Prism,
    name: "Route Telegram Command",
    description: "Routes parsed Telegram commands to appropriate handlers with permission verification",
    input_schema: %{
      type: :object,
      properties: %{
        command: %{type: :object, description: "Parsed command structure"},
        context: %{type: :object, description: "Execution context including chat_type, user_id, permissions"},
        router: %{type: :object, description: "Router definition"}
      },
      required: ["command"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Telegram.MessageProcessing.CommandRouter

  def handler(params, _agent) when is_map(params) do
    command = Map.get(params, :command) || Map.get(params, "command")
    context = Map.get(params, :context) || Map.get(params, "context") || %{}
    router = Map.get(params, :router) || Map.get(params, "router") || CommandRouter.new()

    case CommandRouter.dispatch(router, command, context) do
      {:ok, result} ->
        {:ok, %{status: "ok", result: result}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid input: expected command"}
end
