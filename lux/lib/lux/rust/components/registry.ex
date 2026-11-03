defmodule Lux.Rust.Components.Registry do
  @moduledoc """
  Maintains registration, metadata, and lifecycle dispatch for native Rust components
  (Prisms and Beams).
  """

  alias Lux.Rust

  @default_components %{
    "RustMatrixMultiply" => %{
      name: "RustMatrixMultiply",
      description: "SIMD matrix dot product implemented natively in Rust",
      type: :prism,
      input_schema: %{
        type: "object",
        properties: %{
          "a" => %{type: "array", items: %{type: "number"}},
          "b" => %{type: "array", items: %{type: "number"}}
        },
        required: ["a", "b"]
      },
      output_schema: %{
        type: "object",
        properties: %{
          "dot_product" => %{type: "number"}
        },
        required: ["dot_product"]
      }
    },
    "RustFastHasher" => %{
      name: "RustFastHasher",
      description: "High-speed cryptographic hashing in native Rust",
      type: :prism,
      input_schema: %{
        type: "object",
        properties: %{"data" => %{type: "string"}},
        required: ["data"]
      },
      output_schema: %{
        type: "object",
        properties: %{"hash" => %{type: "string"}},
        required: ["hash"]
      }
    }
  }

  @doc """
  Lists all available native Rust components.
  """
  @spec list_components() :: list(map())
  def list_components do
    Map.values(@default_components)
  end

  @doc """
  Gets metadata for a specific native Rust component.
  """
  @spec get_component(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_component(name) do
    case Map.get(@default_components, name) do
      nil -> {:error, :not_found}
      comp -> {:ok, comp}
    end
  end

  @doc """
  Invokes a native Rust component with input arguments and context.
  """
  @spec invoke(String.t(), term(), map(), keyword()) :: {:ok, term()} | {:error, term()}
  def invoke(component_name, args, ctx \\ %{}, opts \\ []) do
    case component_name do
      "RustMatrixMultiply" ->
        Rust.call("math.dot_product", args, opts)

      "RustFastHasher" ->
        case args do
          %{"data" => d} ->
            hash = :sha256 |> :crypto.hash(d) |> Base.encode16(case: :lower)
            {:ok, %{"hash" => hash}}

          _ ->
            {:error, "Expected map with 'data' key"}
        end

      other ->
        Rust.call(other, args, opts)
    end
  end
end
