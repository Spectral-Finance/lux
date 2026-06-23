defmodule Lux.Prisms.Ollama.ManageModel do
  @moduledoc """
  A prism for managing models on an Ollama instance.
  Supports pulling and deleting models.

  ## Examples
      iex> ManageModel.handler(%{
      ...>   action: "pull",
      ...>   model_name: "llama3"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, action: "pull", model_name: "llama3"}}

      iex> ManageModel.handler(%{
      ...>   action: "delete",
      ...>   model_name: "llama3"
      ...> }, %{name: "Agent"})
      {:ok, %{success: true, action: "delete", model_name: "llama3"}}
  """

  use Lux.Prism,
    name: "Manage Ollama Model",
    description: "Pulls or deletes models on an Ollama instance",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The action to perform: 'pull' or 'delete'",
          enum: ["pull", "delete"]
        },
        model_name: %{
          type: :string,
          description: "The name of the model to manage (e.g. 'llama3', 'mistral:latest')"
        }
      },
      required: ["action", "model_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the operation was successful"
        },
        action: %{
          type: :string,
          description: "The action that was performed"
        },
        model_name: %{
          type: :string,
          description: "The name of the model that was managed"
        },
        status: %{
          type: :string,
          description: "Status message from Ollama"
        }
      },
      required: ["success", "action", "model_name"]
    }

  require Logger

  @doc """
  Handles the request to manage an Ollama model.

  Returns {:ok, %{success: true, ...}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, action} <- validate_action(params),
         {:ok, model_name} <- validate_param(params, :model_name) do
      agent_name = get_agent_name(agent)
      base_url = Map.get(params, :base_url, "http://localhost:11434")

      Logger.info("Agent #{agent_name} performing #{action} on model #{model_name}")

      case action do
        "pull" -> pull_model(model_name, base_url, params)
        "delete" -> delete_model(model_name, base_url, params)
      end
    end
  end

  defp pull_model(model_name, base_url, params) do
    req_opts =
      [
        url: "#{base_url}/api/pull",
        json: %{name: model_name, stream: false},
        headers: [{"Content-Type", "application/json"}],
        receive_timeout: 600_000
      ]
      |> maybe_add_plug(params)

    case req_opts |> Req.new() |> Req.post() do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("Successfully pulled model #{model_name}")

        {:ok,
         %{
           success: true,
           action: "pull",
           model_name: model_name,
           status: body["status"] || "success"
         }}

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, error} ->
        {:error, "Ollama API error: #{inspect(error)}"}
    end
  end

  defp delete_model(model_name, base_url, params) do
    req_opts =
      [
        url: "#{base_url}/api/delete",
        json: %{name: model_name},
        headers: [{"Content-Type", "application/json"}]
      ]
      |> maybe_add_plug(params)

    case req_opts |> Req.new() |> Req.request(method: :delete) do
      {:ok, %{status: 200}} ->
        Logger.info("Successfully deleted model #{model_name}")

        {:ok,
         %{
           success: true,
           action: "delete",
           model_name: model_name,
           status: "success"
         }}

      {:ok, %{status: status, body: %{"error" => message}}} ->
        {:error, {status, message}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, error} ->
        {:error, "Ollama API error: #{inspect(error)}"}
    end
  end

  defp maybe_add_plug(opts, %{plug: plug}), do: Keyword.put(opts, :plug, plug)
  defp maybe_add_plug(opts, _), do: opts

  defp validate_action(params) do
    case Map.get(params, :action) || Map.get(params, "action") do
      action when action in ["pull", "delete"] -> {:ok, action}
      nil -> {:error, "Missing required parameter: action"}
      other -> {:error, "Invalid action: #{inspect(other)}. Must be 'pull' or 'delete'"}
    end
  end

  defp validate_param(params, key) do
    case Map.get(params, key) || Map.get(params, to_string(key)) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp get_agent_name(nil), do: "Unknown Agent"
  defp get_agent_name(%{name: name}), do: name
  defp get_agent_name(%{agent: %{name: name}}), do: name
  defp get_agent_name(_), do: "Unknown Agent"
end
