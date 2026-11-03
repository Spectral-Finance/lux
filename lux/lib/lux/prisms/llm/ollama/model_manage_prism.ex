defmodule Lux.Prisms.Llm.Ollama.ModelManagePrism do
  @moduledoc """
  A prism for managing local Ollama models: listing installed models,
  pulling models, inspecting model specifications, and checking model presence.
  """

  use Lux.Prism,
    name: "Ollama Model Manager",
    description: "Lists, downloads, checks, and manages local Ollama models",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform",
          enum: ["list", "pull", "check", "show", "delete"],
          default: "list"
        },
        model_name: %{
          type: :string,
          description: "Model tag or identifier (e.g. 'llama3.2', 'deepseek-r1:7b')"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        status: %{type: :string},
        installed: %{type: [:boolean, :null]},
        models: %{type: [:array, :null]},
        details: %{type: [:object, :null]}
      },
      required: ["action", "status"]
    }

  alias Lux.LLM.Ollama.ModelManager

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "list")
    model_name = Map.get(inputs, "model_name") || Map.get(inputs, :model_name)

    case action do
      "list" ->
        case ModelManager.list_models() do
          {:ok, models} ->
            model_summaries =
              Enum.map(models, fn m ->
                %{
                  name: m.name,
                  size_mb: Float.round((m.size || 0) / (1024 * 1024), 2),
                  family: m.family,
                  parameter_size: m.parameter_size,
                  quantization: m.quantization_level
                }
              end)

            {:ok,
             %{
               action: "list",
               status: "success",
               installed: nil,
               models: model_summaries,
               details: nil
             }}

          {:error, reason} ->
            {:error, "Failed to list Ollama models: #{inspect(reason)}"}
        end

      "check" ->
        if is_nil(model_name) do
          {:error, "Missing required parameter 'model_name' for check action"}
        else
          installed = ModelManager.model_installed?(model_name)

          {:ok,
           %{
             action: "check",
             status: "success",
             installed: installed,
             models: nil,
             details: %{model_name: model_name, installed: installed}
           }}
        end

      "pull" ->
        if is_nil(model_name) do
          {:error, "Missing required parameter 'model_name' for pull action"}
        else
          case ModelManager.pull_model(model_name) do
            {:ok, res} ->
              {:ok,
               %{
                 action: "pull",
                 status: "success",
                 installed: true,
                 models: nil,
                 details: res
               }}

            {:error, reason} ->
              {:error, "Failed to pull model '#{model_name}': #{inspect(reason)}"}
          end
        end

      "show" ->
        if is_nil(model_name) do
          {:error, "Missing required parameter 'model_name' for show action"}
        else
          case ModelManager.show_model_info(model_name) do
            {:ok, res} ->
              {:ok,
               %{
                 action: "show",
                 status: "success",
                 installed: true,
                 models: nil,
                 details: res
               }}

            {:error, reason} ->
              {:error, "Failed to show model info for '#{model_name}': #{inspect(reason)}"}
          end
        end

      "delete" ->
        if is_nil(model_name) do
          {:error, "Missing required parameter 'model_name' for delete action"}
        else
          case ModelManager.delete_model(model_name) do
            :ok ->
              {:ok,
               %{
                 action: "delete",
                 status: "success",
                 installed: false,
                 models: nil,
                 details: %{model_name: model_name, deleted: true}
               }}

            {:error, reason} ->
              {:error, "Failed to delete model '#{model_name}': #{inspect(reason)}"}
          end
        end

      other ->
        {:error, "Unsupported action '#{other}'. Must be one of: list, pull, check, show, delete"}
    end
  end
end
