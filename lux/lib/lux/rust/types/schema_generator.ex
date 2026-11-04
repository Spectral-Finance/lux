defmodule Lux.Rust.Types.SchemaGenerator do
  @moduledoc """
  Generates idiomatic Rust type definitions from Elixir type specifications.

  The generator turns the same `t:Lux.Rust.Types.Serializer.rust_type/0`
  specifications used by the serializer into Rust `struct` and `enum`
  declarations annotated with `#[derive(Serialize, Deserialize)]`, so the
  Elixir and Rust sides of the boundary can never drift apart.

  ## Options

    * `:name` - the Rust type name (defaults to the `:struct`/`:enum` module)
    * `:derive` - extra derives appended to `Serialize, Deserialize`
    * `:tag` - `:external` (default) for `{"Variant": value}`, `:internal` to
      flatten fields with a `"type"` tag, or `{:adjacent, "t", "c"}` for
      adjacently tagged enums (mirrors `#[serde(tag = "...", content = "...")]`)
    * `:rename_all` - a `#[serde(rename_all = "...")]` attribute value

  ## Examples

      iex> Lux.Rust.Types.SchemaGenerator.generate({:struct, [x: :f64, y: :f64]}, name: "Point")
      {:ok, "#[derive(Serialize, Deserialize)]\\npub struct Point {\\n    pub x: f64,\\n    pub y: f64,\\n}"}

      iex> Lux.Rust.Types.SchemaGenerator.generate({:enum, [ok: :i64, err: :string]}, name: "Result")
      {:ok, "#[derive(Serialize, Deserialize)]\\npub enum Result {\\n    Ok(i64),\\n    Err(String),\\n}"}
  """

  alias Lux.Rust.Types.Serializer

  @primitive_types %{
    bool: "bool",
    i8: "i8",
    i16: "i16",
    i32: "i32",
    i64: "i64",
    i128: "i128",
    u8: "u8",
    u16: "u16",
    u32: "u32",
    u64: "u64",
    u128: "u128",
    f32: "f32",
    f64: "f64",
    string: "String",
    char: "char",
    atom: "String"
  }

  @doc """
  Generates a Rust type definition for the given Rust `type` specification.

  See the module documentation for the supported options.
  """
  @spec generate(Serializer.rust_type(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate(type, opts \\ [])

  def generate({:struct, fields}, opts) when is_list(fields) do
    with {:ok, name} <- resolve_name(Keyword.get(opts, :name)),
         {:ok, body} <- render_struct_fields(fields) do
      {:ok, render_struct(name, body, opts)}
    end
  end

  def generate({:struct, module}, opts) when is_atom(module) do
    fields = module |> struct() |> Map.from_struct() |> Map.keys() |> Enum.map(&{&1, :string})
    generate({:struct, fields}, Keyword.put_new(opts, :name, inspect(module)))
  end

  def generate({:enum, variants}, opts) when is_list(variants) do
    with {:ok, name} <- resolve_name(Keyword.get(opts, :name)),
         {:ok, body} <- render_variants(variants) do
      {:ok, render_enum(name, body, opts)}
    end
  end

  def generate(other, _opts), do: {:error, {:unsupported_type, other}}

  @doc "Generates multiple Rust definitions as a single source string."
  @spec generate_all([{Serializer.rust_type(), keyword()}]) ::
          {:ok, String.t()} | {:error, term()}
  def generate_all(specs) when is_list(specs) do
    Enum.reduce_while(specs, {:ok, []}, fn {type, opts}, {:ok, acc} ->
      case generate(type, opts) do
        {:ok, code} -> {:cont, {:ok, [code | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, blocks} -> {:ok, blocks |> Enum.reverse() |> Enum.join("\n\n")}
      error -> error
    end
  end

  @doc """
  Renders a Rust type using the serializer's type inference rules.

  This is the entry point used by `Lux.Rust.Types` for one-shot conversions.
  """
  @spec rust_type(term()) :: {:ok, String.t()} | {:error, term()}
  def rust_type(term), do: term |> Serializer.encode() |> rust_type_for_wire()

  defp rust_type_for_wire({:ok, wire}), do: {:ok, primitive_or_container(wire)}
  defp rust_type_for_wire({:error, _reason} = error), do: error

  defp primitive_or_container(nil), do: "()"
  defp primitive_or_container(value) when is_boolean(value), do: "bool"
  defp primitive_or_container(value) when is_integer(value), do: "i64"
  defp primitive_or_container(value) when is_float(value), do: "f64"
  defp primitive_or_container(value) when is_binary(value), do: "String"

  defp primitive_or_container(value) when is_list(value) do
    element =
      case value do
        [] -> "()"
        [head | _tail] -> primitive_or_container(head)
      end

    "Vec<#{element}>"
  end

  defp primitive_or_container(value) when is_map(value) do
    case Map.to_list(value) do
      [] -> "HashMap<String, ()>"
      [{_key, first} | _rest] -> "HashMap<String, #{primitive_or_container(first)}>"
    end
  end

  @doc """
  Maps a Rust `type` specification to its Rust source representation.

  Unlike `rust_type/1`, which infers a type from a runtime value, this converts
  an explicit specification such as `{:option, :string}` directly.
  """
  @spec to_rust_type(Serializer.rust_type()) :: {:ok, String.t()} | {:error, term()}
  def to_rust_type(type), do: rust_type_string(type)

  # ------------------------------------------------------------------
  # Rendering
  # ------------------------------------------------------------------

  defp resolve_name(name) when is_binary(name) and name != "", do: {:ok, name}
  defp resolve_name(name) when is_atom(name) and not is_nil(name), do: {:ok, inspect(name)}
  defp resolve_name(_name), do: {:error, :missing_name}

  defp render_struct_fields([]), do: {:ok, ""}

  defp render_struct_fields(fields) do
    Enum.reduce_while(fields, {:ok, []}, fn {name, type}, {:ok, acc} ->
      case rust_type_string(type) do
        {:ok, rust} -> {:cont, {:ok, ["    pub #{name}: #{rust}," | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> finish_lines()
  end

  defp render_variants([]), do: {:ok, ""}

  defp render_variants(variants) do
    Enum.reduce_while(variants, {:ok, []}, fn {name, type}, {:ok, acc} ->
      case rust_variant(name, type) do
        {:ok, line} -> {:cont, {:ok, [line | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> finish_lines()
  end

  defp finish_lines({:ok, lines}), do: {:ok, lines |> Enum.reverse() |> Enum.join("\n")}
  defp finish_lines({:error, _reason} = error), do: error

  defp rust_variant(name, :unit), do: {:ok, "    #{Macro.camelize(Atom.to_string(name))},"}

  defp rust_variant(name, type) do
    case rust_type_string(type) do
      {:ok, rust} -> {:ok, "    #{Macro.camelize(Atom.to_string(name))}(#{rust}),"}
      {:error, _reason} = error -> error
    end
  end

  defp rust_type_string(type) when is_atom(type) do
    case Map.fetch(@primitive_types, type) do
      {:ok, rust} -> {:ok, rust}
      :error -> {:error, {:unsupported_type, type}}
    end
  end

  defp rust_type_string({:option, type}) do
    with {:ok, rust} <- rust_type_string(type), do: {:ok, "Option<#{rust}>"}
  end

  defp rust_type_string({container, type}) when container in [:vec, :list] do
    with {:ok, rust} <- rust_type_string(type), do: {:ok, "Vec<#{rust}>"}
  end

  defp rust_type_string({:map, key_type, value_type}) do
    with {:ok, key} <- rust_type_string(key_type),
         {:ok, value} <- rust_type_string(value_type) do
      {:ok, "HashMap<#{key}, #{value}>"}
    end
  end

  defp rust_type_string({:tuple, types}) when is_list(types) do
    types
    |> Enum.reduce_while({:ok, []}, fn type, {:ok, acc} ->
      case rust_type_string(type) do
        {:ok, rust} -> {:cont, {:ok, [rust | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, rusts} -> {:ok, "(#{rusts |> Enum.reverse() |> Enum.join(", ")})"}
      error -> error
    end
  end

  defp rust_type_string({:struct, _} = type), do: generate(type, name: "Struct")
  defp rust_type_string({:enum, _} = type), do: generate(type, name: "Enum")
  defp rust_type_string(other), do: {:error, {:unsupported_type, other}}

  defp render_struct(name, "", opts), do: "#{attributes(opts)}pub struct #{name} {}"

  defp render_struct(name, body, opts) do
    "#{attributes(opts)}pub struct #{name} {\n#{body}\n}"
  end

  defp render_enum(name, "", opts), do: "#{attributes(opts)}pub enum #{name} {}"

  defp render_enum(name, body, opts) do
    "#{attributes(opts)}pub enum #{name} {\n#{body}\n}"
  end

  defp attributes(opts) do
    derives = ["Serialize", "Deserialize" | List.wrap(Keyword.get(opts, :derive, []))]

    lines = ["#[derive(#{Enum.join(derives, ", ")})]"]

    lines =
      case Keyword.get(opts, :rename_all) do
        nil -> lines
        rename -> lines ++ ["#[serde(rename_all = \"#{rename}\")]"]
      end

    lines =
      case Keyword.get(opts, :tag, :external) do
        :external ->
          lines

        :internal ->
          lines ++ ["#[serde(tag = \"type\")]"]

        {:adjacent, tag, content} ->
          lines ++ ["#[serde(tag = \"#{tag}\", content = \"#{content}\")]"]

        other ->
          lines ++ ["/* unknown tag: #{inspect(other)} */"]
      end

    Enum.join(lines, "\n") <> "\n"
  end
end
