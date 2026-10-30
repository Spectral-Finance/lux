defmodule Lux.Rust.TypeSystem do
  @moduledoc """
  Type system mapping and Serde serialization bridge between Elixir and Rust.

  Maps primitive, composite, and optional types between Elixir schemas and Rust,
  generates serde-compatible Rust data structures (`struct` and `enum`), and
  provides bidirectional conversion utilities for Lux Signal payloads.

  ## Examples

      iex> Lux.Rust.TypeSystem.to_rust_type(:string)
      "String"

      iex> Lux.Rust.TypeSystem.to_rust_type({:list, :integer})
      "Vec<i64>"

      iex> Lux.Rust.TypeSystem.to_rust_type({:option, :float})
      "Option<f64>"
  """

  @doc """
  Maps Elixir schema types to corresponding Rust type representations.
  """
  def to_rust_type(:string), do: "String"
  def to_rust_type(:binary), do: "Vec<u8>"
  def to_rust_type(:integer), do: "i64"
  def to_rust_type(:int), do: "i64"
  def to_rust_type(:float), do: "f64"
  def to_rust_type(:boolean), do: "bool"
  def to_rust_type(:bool), do: "bool"
  def to_rust_type(:map), do: "serde_json::Value"
  def to_rust_type(:any), do: "serde_json::Value"
  def to_rust_type({:list, inner}), do: "Vec<#{to_rust_type(inner)}>"
  def to_rust_type({:array, inner}), do: "Vec<#{to_rust_type(inner)}>"
  def to_rust_type({:option, inner}), do: "Option<#{to_rust_type(inner)}>"
  def to_rust_type({:map, k, v}), do: "std::collections::HashMap<#{to_rust_type(k)}, #{to_rust_type(v)}>"
  def to_rust_type(custom) when is_binary(custom), do: custom
  def to_rust_type(custom) when is_atom(custom), do: custom |> to_string() |> Macro.camelize()

  @doc """
  Generates a Serde-compatible Rust struct definition from field specifications.
  """
  def generate_rust_struct(name, fields, opts \\ []) when is_binary(name) and is_list(fields) do
    derives = Keyword.get(opts, :derives, ["Serialize", "Deserialize", "Debug", "Clone"])
    derives_str = Enum.join(derives, ", ")

    field_lines =
      Enum.map(fields, fn
        {field_name, field_type} ->
          rust_field = Macro.underscore(to_string(field_name))
          rust_type = to_rust_type(field_type)
          "    pub #{rust_field}: #{rust_type},"

        {field_name, field_type, field_opts} ->
          rust_field = Macro.underscore(to_string(field_name))
          rust_type = to_rust_type(field_type)
          rename_attr = ifKeyword(field_opts, :rename, fn r -> "    #[serde(rename = \"#{r}\")]\n" end) || ""
          "#{rename_attr}    pub #{rust_field}: #{rust_type},"
      end)
      |> Enum.join("\n")

    """
    #[derive(#{derives_str})]
    pub struct #{name} {
    #{field_lines}
    }
    """
    |> String.trim()
  end

  @doc """
  Generates a Serde-compatible Rust enum definition from variant specifications.
  """
  def generate_rust_enum(name, variants, opts \\ []) when is_binary(name) and is_list(variants) do
    derives = Keyword.get(opts, :derives, ["Serialize", "Deserialize", "Debug", "Clone"])
    derives_str = Enum.join(derives, ", ")

    variant_lines =
      Enum.map(variants, fn
        variant when is_atom(variant) or is_binary(variant) ->
          "    #{Macro.camelize(to_string(variant))},"

        {variant, type} ->
          rust_type = to_rust_type(type)
          "    #{Macro.camelize(to_string(variant))}(#{rust_type}),"

        {variant, fields} when is_list(fields) ->
          inner_fields =
            Enum.map(fields, fn {f, t} ->
              "        #{Macro.underscore(to_string(f))}: #{to_rust_type(t)}"
            end)
            |> Enum.join(",\n")

          "    #{Macro.camelize(to_string(variant))} {\n#{inner_fields}\n    },"
      end)
      |> Enum.join("\n")

    """
    #[derive(#{derives_str})]
    #[serde(tag = "type", content = "payload")]
    pub enum #{name} {
    #{variant_lines}
    }
    """
    |> String.trim()
  end

  @doc """
  Encodes an Elixir map or struct into a Serde-compatible JSON string.
  """
  def to_rust_json(data) do
    Jason.encode(data)
  end

  @doc """
  Decodes a JSON string received from a Rust Serde serialization into an Elixir map.
  """
  def from_rust_json(json_str) when is_binary(json_str) do
    Jason.decode(json_str)
  end

  defp ifKeyword(opts, key, fun) when is_list(opts) do
    case Keyword.get(opts, key) do
      nil -> nil
      val -> fun.(val)
    end
  end
  defp ifKeyword(_opts, _key, _fun), do: nil
end
