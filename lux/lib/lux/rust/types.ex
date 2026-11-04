defmodule Lux.Rust.Types do
  @moduledoc """
  An advanced, pure-Elixir type system for exchanging data with Rust.

  `Lux.Rust.Types` is the public facade over the Elixir <-> Rust boundary. It
  combines three building blocks:

    * `Lux.Rust.Types.Serializer` - bidirectional conversion between Elixir
      terms and the JSON-shaped representation produced by Rust's `serde`
      (`{:ok, value} | {:error, reason}`).
    * `Lux.Rust.Types.SchemaGenerator` - code generation of Rust `struct` and
      `enum` definitions with `#[derive(Serialize, Deserialize)]`.
    * `Lux.Rust.Types.Type` - named, reusable custom type definitions.

  ## Quick start

      iex> alias Lux.Rust.Types
      iex> Types.encode(%{x: 1.0, y: 2.0}, {:struct, [x: :f64, y: :f64]})
      {:ok, %{"x" => 1.0, "y" => 2.0}}

      iex> alias Lux.Rust.Types
      iex> point = Types.define("Point", {:struct, [x: :f64, y: :f64]})
      iex> Types.rust_type(point)
      {:ok, "Point"}

  ## Complex conversions

  Nested structs, enums, options, vectors, tuples and maps compose freely:

      iex> alias Lux.Rust.Types
      iex> type = {:struct, [id: :u64, tags: {:vec, :string}, status: {:option, :string}]}
      iex> Types.encode(%{id: 1, tags: ["a", "b"], status: nil}, type)
      {:ok, %{"id" => 1, "tags" => ["a", "b"], "status" => nil}}
  """

  alias Lux.Rust.Types.{SchemaGenerator, Serializer, Type}

  @typedoc "Anything accepted as a type: a specification or a named `%Type{}`."
  @type type :: Serializer.rust_type() | Type.t()

  # ------------------------------------------------------------------
  # Serialization
  # ------------------------------------------------------------------

  @doc "Encodes an Elixir term into its Serde wire representation."
  @spec encode(term()) :: {:ok, term()} | {:error, term()}
  def encode(term), do: Serializer.encode(term)

  @doc "Encodes an Elixir term using an explicit type specification or `%Type{}`."
  @spec encode(term(), type()) :: {:ok, term()} | {:error, term()}
  def encode(term, type), do: Serializer.encode(term, to_spec(type))

  @doc "Same as `encode/2` but raises on failure."
  @spec encode!(term(), type() | nil) :: term()
  def encode!(term, type \\ nil), do: Serializer.encode!(term, to_spec(type))

  @doc "Decodes a Serde wire value into an Elixir term."
  @spec decode(term()) :: {:ok, term()} | {:error, term()}
  def decode(wire), do: Serializer.decode(wire)

  @doc "Decodes a Serde wire value using an explicit type specification or `%Type{}`."
  @spec decode(term(), type()) :: {:ok, term()} | {:error, term()}
  def decode(wire, type), do: Serializer.decode(wire, to_spec(type))

  @doc "Same as `decode/2` but raises on failure."
  @spec decode!(term(), type() | nil) :: term()
  def decode!(wire, type \\ nil), do: Serializer.decode!(wire, to_spec(type))

  @doc "Encodes a term to a JSON string (the representation `serde_json` produces)."
  @spec to_json(term(), type() | nil) :: {:ok, String.t()} | {:error, term()}
  def to_json(term, type \\ nil), do: Serializer.to_json(term, to_spec(type))

  @doc "Decodes a JSON string into an Elixir term."
  @spec from_json(String.t(), type() | nil) :: {:ok, term()} | {:error, term()}
  def from_json(json, type \\ nil), do: Serializer.from_json(json, to_spec(type))

  @doc "Round-trips a term through the wire representation."
  @spec round_trip(term(), type() | nil) :: {:ok, term()} | {:error, term()}
  def round_trip(term, type \\ nil), do: Serializer.round_trip(term, to_spec(type))

  # ------------------------------------------------------------------
  # Custom type definitions
  # ------------------------------------------------------------------

  @doc """
  Defines a named, reusable custom type.

  Accepts a `{:struct, fields}` or `{:enum, variants}` tuple, or any other
  `t:Serializer.rust_type/0` which is stored as a `:alias`.

      iex> alias Lux.Rust.Types
      iex> Types.define("UserId", :u64).kind
      :alias

      iex> alias Lux.Rust.Types
      iex> Types.define("Color", {:enum, [red: :unit, green: :unit]}).kind
      :enum
  """
  @spec define(String.t(), term()) :: Type.t()
  def define(name, {:struct, fields}) when is_binary(name) and is_list(fields) do
    %Type{name: name, kind: :struct, fields: fields}
  end

  def define(name, {:enum, variants}) when is_binary(name) and is_list(variants) do
    %Type{name: name, kind: :enum, variants: variants}
  end

  def define(name, spec) when is_binary(name) do
    %Type{name: name, kind: :alias, spec: spec}
  end

  @doc "Defines a custom type with additional metadata (`:doc`, `:tag`, `:derives`)."
  @spec define(String.t(), term(), keyword()) :: Type.t()
  def define(name, spec, opts) when is_binary(name) and is_list(opts) do
    name |> define(spec) |> struct(opts)
  end

  # ------------------------------------------------------------------
  # Type mapping and code generation
  # ------------------------------------------------------------------

  @doc """
  Maps a type specification or `%Type{}` to its Rust source representation.

      iex> alias Lux.Rust.Types
      iex> Types.rust_type({:option, {:vec, :string}})
      {:ok, "Option<Vec<String>>"}
  """
  @spec rust_type(type()) :: {:ok, String.t()} | {:error, term()}
  def rust_type(%Type{kind: :struct, name: name}), do: {:ok, name}
  def rust_type(%Type{kind: :enum, name: name}), do: {:ok, name}
  def rust_type(%Type{kind: :alias, spec: spec}), do: SchemaGenerator.to_rust_type(spec)
  def rust_type(spec), do: SchemaGenerator.to_rust_type(spec)

  @doc """
  Infers a Rust type from a runtime value using the serializer's wire rules.

      iex> alias Lux.Rust.Types
      iex> Types.infer_type([1, 2, 3])
      {:ok, "Vec<i64>"}
  """
  @spec infer_type(term()) :: {:ok, String.t()} | {:error, term()}
  def infer_type(value), do: SchemaGenerator.rust_type(value)

  @doc "Generates a Rust definition for a type specification or `%Type{}`."
  @spec generate(type(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate(type, opts \\ [])
  def generate(%Type{} = type, opts), do: do_generate(type, opts)
  def generate(spec, opts), do: SchemaGenerator.generate(spec, opts)

  defp do_generate(%Type{kind: :struct} = type, opts) do
    SchemaGenerator.generate({:struct, type.fields}, merge_opts(type, opts))
  end

  defp do_generate(%Type{kind: :enum} = type, opts) do
    SchemaGenerator.generate({:enum, type.variants}, merge_opts(type, opts))
  end

  defp do_generate(%Type{kind: :alias, name: name}, _opts), do: {:error, {:not_generatable, name}}

  defp merge_opts(%Type{} = type, opts) do
    opts
    |> Keyword.put_new(:name, type.name)
    |> Keyword.put_new(:tag, type.tag)
    |> Keyword.put_new(:derive, type.derives)
  end

  defp to_spec(%Type{kind: :struct, fields: fields}), do: {:struct, fields}
  defp to_spec(%Type{kind: :enum, variants: variants}), do: {:enum, variants}
  defp to_spec(%Type{kind: :alias, spec: spec}), do: spec
  defp to_spec(spec), do: spec
end
