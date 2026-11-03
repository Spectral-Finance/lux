defmodule Lux.LLM.Ollama.ModelManager do
  @moduledoc """
  Manages local models on the Ollama daemon:
  - Listing installed local models (`/api/tags`)
  - Inspecting actively running models loaded in VRAM/RAM (`/api/ps`)
  - Pulling / downloading new models (`/api/pull`)
  - Inspecting model details, template, and parameters (`/api/show`)
  - Deleting models (`/api/delete`)
  """

  require Logger

  @default_endpoint "http://localhost:11434"

  defmodule Model do
    @moduledoc """
    Represents an installed local Ollama model.
    """
    @type t :: %__MODULE__{
            name: String.t(),
            model: String.t(),
            size: integer(),
            digest: String.t(),
            modified_at: String.t() | nil,
            format: String.t() | nil,
            family: String.t() | nil,
            parameter_size: String.t() | nil,
            quantization_level: String.t() | nil
          }

    defstruct [
      :name,
      :model,
      :size,
      :digest,
      :modified_at,
      :format,
      :family,
      :parameter_size,
      :quantization_level
    ]
  end

  defmodule RunningModel do
    @moduledoc """
    Represents a model currently loaded in memory/VRAM.
    """
    @type t :: %__MODULE__{
            name: String.t(),
            model: String.t(),
            size: integer(),
            digest: String.t(),
            expires_at: String.t() | nil,
            size_vram: integer()
          }

    defstruct [:name, :model, :size, :digest, :expires_at, size_vram: 0]
  end

  @doc """
  Lists all local models installed on the Ollama daemon.
  """
  @spec list_models(keyword()) :: {:ok, list(Model.t())} | {:error, term()}
  def list_models(opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_base_endpoint())
    url = "#{endpoint}/api/tags"

    [url: url, headers: [{"Content-Type", "application/json"}]]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        parsed =
          Enum.map(models, fn m ->
            details = m["details"] || %{}

            %Model{
              name: m["name"],
              model: m["model"],
              size: m["size"],
              digest: m["digest"],
              modified_at: m["modified_at"],
              format: details["format"],
              family: details["family"],
              parameter_size: details["parameter_size"],
              quantization_level: details["quantization_level"]
            }
          end)

        {:ok, parsed}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists models currently active/loaded in VRAM/RAM.
  """
  @spec list_running_models(keyword()) :: {:ok, list(RunningModel.t())} | {:error, term()}
  def list_running_models(opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_base_endpoint())
    url = "#{endpoint}/api/ps"

    [url: url, headers: [{"Content-Type", "application/json"}]]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.get()
    |> case do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        parsed =
          Enum.map(models, fn m ->
            %RunningModel{
              name: m["name"],
              model: m["model"],
              size: m["size"],
              digest: m["digest"],
              expires_at: m["expires_at"],
              size_vram: m["size_vram"] || 0
            }
          end)

        {:ok, parsed}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a model is installed locally.
  """
  @spec model_installed?(String.t(), keyword()) :: boolean()
  def model_installed?(model_name, opts \\ []) do
    case list_models(opts) do
      {:ok, models} ->
        target = String.downcase(model_name)

        Enum.any?(models, fn m ->
          name = String.downcase(m.name || "")
          name == target or name == "#{target}:latest" or String.starts_with?(name, "#{target}:")
        end)

      _ ->
        false
    end
  end

  @doc """
  Pulls / downloads a model to the local Ollama instance.
  """
  @spec pull_model(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def pull_model(model_name, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_base_endpoint())
    url = "#{endpoint}/api/pull"
    insecure = Keyword.get(opts, :insecure, false)

    body = %{
      name: model_name,
      stream: false,
      insecure: insecure
    }

    [
      url: url,
      json: body,
      headers: [{"Content-Type", "application/json"}],
      receive_timeout: 300_000
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Shows metadata and parameters for a local model.
  """
  @spec show_model_info(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def show_model_info(model_name, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_base_endpoint())
    url = "#{endpoint}/api/show"

    [
      url: url,
      json: %{name: model_name},
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.post()
    |> case do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes a model from the local Ollama daemon.
  """
  @spec delete_model(String.t(), keyword()) :: :ok | {:error, term()}
  def delete_model(model_name, opts \\ []) do
    endpoint = Keyword.get(opts, :endpoint, get_base_endpoint())
    url = "#{endpoint}/api/delete"

    [
      url: url,
      json: %{name: model_name},
      headers: [{"Content-Type", "application/json"}]
    ]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.delete()
    |> case do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_base_endpoint do
    case Application.get_env(:lux, :ollama) do
      opts when is_list(opts) -> Keyword.get(opts, :endpoint, @default_endpoint)
      opts when is_map(opts) -> Map.get(opts, :endpoint, @default_endpoint)
      _ -> @default_endpoint
    end || System.get_env("OLLAMA_ENDPOINT", @default_endpoint)
  end
end
