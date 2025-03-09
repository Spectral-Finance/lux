defmodule Lux.Components.RustConfig do
  @moduledoc """
  Configuration struct for Rust components.
  """
  defstruct [:name, :config]
end

defmodule Lux.Components.Rust do
  @moduledoc """
  Interface for Rust-based Lux components.
  """
  use Rustler, otp_app: :lux, crate: :lux_rust

  # These functions are implemented in Rust
  def initialize(_config), do: :erlang.nif_error(:nif_not_loaded)
  def process(_resource, _input), do: :erlang.nif_error(:nif_not_loaded)
  def cleanup(_resource), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Creates a new Rust component with the given configuration.
  """
  def new(name, config \\ %{}) do
    rust_config = %Lux.Components.RustConfig{
      name: name,
      config: config
    }
    case initialize(rust_config) do
      {:ok, resource} -> {:ok, %{resource: resource, reference: make_ref()}}
      {:error, reason} -> {:error, reason}
      resource when is_reference(resource) -> {:ok, %{resource: resource, reference: make_ref()}}
    end
  end

  @doc """
  Processes input through a Rust component.
  """
  def call(%{resource: resource}, input) do
    case process(resource, input) do
      {:ok, result} when is_list(result) -> {:ok, Map.new(result)}
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      result when is_list(result) -> {:ok, Map.new(result)}
      result -> {:ok, result}
    end
  end

  @doc """
  Cleans up resources associated with a Rust component.
  """
  def terminate(%{resource: resource}) do
    case cleanup(resource) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
