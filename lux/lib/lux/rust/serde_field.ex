defmodule Lux.Rust.SerdeField do
  @moduledoc """
  Represents a single struct field with Serde metadata.

  Handles field naming, rename rules, default values, skip conditions,
  and tag/content attributes for Serde-compatible struct definitions.
  """

  use Lux.Types

  @typedoc """
  Serde attribute keys supported by this module.
  """
  @type serde_attr_key ::
          :rename
          | :rename_all
          | :tag
          | :content
          | :default
          | :skip_serializing_if
          | :skip_deserializing

  @typedoc """
  Map of Serde attributes applied to a struct or enum.
  """
  @type serde_attrs :: %{
          optional(:rename) => atom(),
          optional(:rename_all) => atom(),
          optional(:tag) => String.t(),
          optional(:content) => String.t(),
          optional(:default) => term(),
          optional(:skip_serializing_if) => String.t(),
          optional(:skip_deserializing) => boolean()
        }

  @typedoc """
  A SerdeField represents one field in a Rust struct schema.
  """
  @type t :: %{
          name: atom(),
          rust_name: String.t(),
          rust_type: String.t(),
          serde_attrs: serde_attrs()
        }

  @enforce_keys [:name, :rust_name, :rust_type]
  defstruct name: nil,
            rust_name: "",
            rust_type: "",
            serde_attrs: %{}

  @doc """
  Converts a field descriptor tuple `{elixir_name, type, metadata}` into a SerdeField struct.

  ## Examples

      iex> field = Lux.Rust.SerdeField.from_descriptor({:symbol, :string, [rename: :snake_case]})
      iex> field.name
      :symbol

      iex> field = Lux.Rust.SerdeField.from_descriptor({:price_usd, :float, [default: 0.0]})
      iex> field.serde_attrs[:default]
      0.0
  """
  @spec from_descriptor({atom(), primitive_type(), map()}) :: t()
        when primitive_type:
               :integer
               | :float
               | :boolean
               | :string
               | :bytes
               | :char
               | :vec
               | :option
               | :hash_map
               | :tuple
               | :array
  def from_descriptor({name, type, metadata}) when is_atom(name) and is_atom(type) and is_map(metadata) do
    rust_type = type_to_rust_string(type, metadata[:type_inner])
    rust_name = apply_rename(name, metadata[:rename], metadata[:rename_all])
    serde_attrs = extract_serde_attrs(metadata)

    %__MODULE__{
      name: name,
      rust_name: rust_name,
      rust_type: rust_type,
      serde_attrs: serde_attrs
    }
  end

  @doc "Returns the Elixir (original) field name."
  @spec elixir_name(t()) :: atom()
  def elixir_name(%__MODULE__{name: name}), do: name

  @doc "Returns the Rust (snake_case) field name."
  @spec rust_name(t()) :: String.t()
  def rust_name(%__MODULE__{rust_name: rust_name}), do: rust_name

  @doc "Returns the Rust type string for this field."
  @spec rust_type_string(t()) :: String.t()
  def rust_type_string(%__MODULE__{rust_type: rust_type}), do: rust_type

  @doc """
  Generates the Rust field definition line for code generation.

  ## Examples

      iex> field = Lux.Rust.SerdeField.from_descriptor({:price_usd, :float, [default: 0.0]})
      iex> Lux.Rust.SerdeField.to_rust_field(field)
      "#[serde(default = \"0.0\")]\npub price_usd: f64,"
  """
  @spec to_rust_field(t()) :: String.t()
  def to_rust_field(%__MODULE__{rust_name: name, rust_type: rust_type, serde_attrs: attrs}) do
    serde_lines =
      attrs
      |> Enum.map(fn
        {:rename, _} -> nil
        {:rename_all, _} -> nil
        {:tag, _} -> nil
        {:content, _} -> nil
        {:default, val} -> "#[serde(default = \"#{serialize_default(val)}\")]"
        {:skip_serializing_if, pattern} -> "#[serde(skip_serializing_if = \"#{pattern}\")]"
        {:skip_deserializing, true} -> "#[serde(skip_deserializing)]"
        {_k, _v} -> nil
      end)
      |> Enum.filter(& &1)

    [serde_lines, "pub #{name}: #{rust_type},"]
    |> List.flatten()
    |> Enum.join("\n")
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp type_to_rust_string(:integer, _inner), do: "i64"
  defp type_to_rust_string(:float, _inner), do: "f64"
  defp type_to_rust_string(:boolean, _inner), do: "bool"
  defp type_to_rust_string(:string, _inner), do: "String"
  defp type_to_rust_string(:bytes, _inner), do: "Vec<u8>"
  defp type_to_rust_string(:char, _inner), do: "char"
  defp type_to_rust_string(:vec, inner), do: "Vec<#{type_to_rust_string(inner, nil)}>"
  defp type_to_rust_string(:option, inner), do: "Option<#{type_to_rust_string(inner, nil)}>"
  defp type_to_rust_string(:hash_map, _inner), do: "HashMap<String, String>"
  defp type_to_rust_string(:tuple, _inner), do: "(String, i64)"
  defp type_to_rust_string(:array, _inner), do: "[i64; 0]"

  defp apply_rename(name, :rename, _rename_all) do
    to_snake_case(Atom.to_string(name))
  end

  defp apply_rename(name, nil, :rename_all) do
    to_snake_case(Atom.to_string(name))
  end

  defp apply_rename(name, nil, nil) do
    to_snake_case(Atom.to_string(name))
  end

  defp apply_rename(name, nil, :PascalCase) do
    name |> Atom.to_string() |> String.capitalize()
  end

  defp apply_rename(name, nil, :SCREAMING_SNAKE_CASE) do
    name |> Atom.to_string() |> String.upcase() |> to_snake_case()
  end

  defp apply_rename(name, nil, _rule) do
    to_snake_case(Atom.to_string(name))
  end

  defp apply_rename(_name, custom_rename, _rename_all) when is_atom(custom_rename) do
    to_snake_case(Atom.to_string(custom_rename))
  end

  defp extract_serde_attrs(metadata) do
    metadata
    |> Map.take([:rename, :rename_all, :tag, :content, :default, :skip_serializing_if, :skip_deserializing])
    |> Map.new()
  end

  defp to_snake_case(str) do
    str
    |> String.replace(~r/([a-z])([A-Z])/, "\1_\2")
    |> String.downcase()
  end

  defp serialize_default(nil), do: "None"
  defp serialize_default(val) when is_number(val), do: to_string(val)
  defp serialize_default(true), do: "true"
  defp serialize_default(false), do: "false"
  defp serialize_default(val) when is_binary(val), do: inspect(val)
  defp serialize_default(val), do: to_string(val)
end
