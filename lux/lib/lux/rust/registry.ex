defmodule Lux.Rust.Registry do
  @moduledoc """
  Component registry for Rust-based Lux components.

  Provides a centralized registry for managing all Rust-native components
  (Prisms, Beams, Lenses) with lookup, listing, and statistics.
  """

  @doc """
  Returns a map of component type to count of registered components.
  """
  @spec stats() :: %{String.t() => non_neg_integer()}
  def stats do
    cond do
      Lux.Native.loaded?() ->
        Lux.Native.rust_component_info()
        |> then(fn
          info when is_map(info) -> info
          _ -> %{}
        end)

      true ->
        %{}
    end
  end

  @doc """
  Lists all registered Rust components across all types.

  Returns a list of tuples `{kind, name}`.
  """
  @spec list_all() :: [{String.t(), String.t()}]
  def list_all do
    [:prism, :beam, :lens]
    |> Enum.flat_map(fn type ->
      case Lux.Rust.Component.list(type) do
        {:ok, components} ->
          kind = Atom.to_string(type)
          Enum.map(components, fn c -> {kind, c["name"] || c[:name]} end)

        _ ->
          []
      end
    end)
  end

  @doc """
  Checks if a specific component is registered.
  """
  @spec registered?(atom(), String.t()) :: boolean()
  def registered?(:prism, name), do: registered?("prism", name)
  def registered?(:beam, name), do: registered?("beam", name)
  def registered?(:lens, name), do: registered?("lens", name)
  def registered?(kind, name) when is_binary(kind) do
    case Lux.Rust.Component.list(String.to_existing_atom(kind)) do
      {:ok, components} ->
        Enum.any?(components, fn c ->
          (c["name"] || c[:name]) == name
        end)

      _ ->
        false
    end
  rescue
    ArgumentError -> false
  end

  @doc """
  Unregisters all components.
  """
  @spec clear() :: :ok
  def clear do
    for type <- [:prism, :beam, :lens] do
      case Lux.Rust.Component.list(type) do
        {:ok, components} ->
          for c <- components do
            name = c["name"] || c[:name]
            Lux.Rust.Component.unregister(type, name)
          end

        _ ->
          :ok
      end
    end

    :ok
  end
end
