defmodule Lux.Rust.Types.SchemaGenerator do
  @moduledoc """
  Generates idiomatic Rust struct and enum definitions with Serde attributes
  from Elixir schemas and maps.
  """

  @doc """
  Generates a Rust struct definition from an Elixir map or schema.
  """
  @spec generate_struct(String.t(), map(), keyword()) :: String.t()
  def generate_struct(struct_name, fields, opts \\ []) do
    camel_name = Macro.camelize(struct_name)
    rename_all = Keyword.get(opts, :rename_all, "snake_case")

    field_lines =
      Enum.map(fields, fn {field_name, field_type} ->
        rust_field = to_snake_case(to_string(field_name))
        rust_type = map_type_to_rust(field_type)
        "    pub #{rust_field}: #{rust_type},"
      end)
      |> Enum.join("\n")

    """
    #[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
    #[serde(rename_all = "#{rename_all}")]
    pub struct #{camel_name} {
    #{field_lines}
    }
    """
    |> String.trim_trailing()
  end

  @doc """
  Generates a Rust enum definition from a list of variant names or tuples.
  """
  @spec generate_enum(String.t(), list(), keyword()) :: String.t()
  def generate_enum(enum_name, variants, opts \\ []) do
    camel_name = Macro.camelize(enum_name)
    tag_style = Keyword.get(opts, :tag_style, :untagged)

    tag_attr =
      case tag_style do
        :internal -> ~s(#[serde(tag = "type")])
        :adjacent -> ~s(#[serde(tag = "type", content = "payload")])
        :untagged -> ~s(#[serde(untagged)])
      end

    variant_lines =
      Enum.map(variants, fn
        {variant, type} ->
          "    #{Macro.camelize(to_string(variant))}(#{map_type_to_rust(type)}),"

        variant ->
          "    #{Macro.camelize(to_string(variant))},"
      end)
      |> Enum.join("\n")

    """
    #[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
    #{tag_attr}
    pub enum #{camel_name} {
    #{variant_lines}
    }
    """
    |> String.trim_trailing()
  end

  defp map_type_to_rust(:integer), do: "i64"
  defp map_type_to_rust("integer"), do: "i64"
  defp map_type_to_rust(:float), do: "f64"
  defp map_type_to_rust("float"), do: "f64"
  defp map_type_to_rust(:number), do: "f64"
  defp map_type_to_rust("number"), do: "f64"
  defp map_type_to_rust(:boolean), do: "bool"
  defp map_type_to_rust("boolean"), do: "bool"
  defp map_type_to_rust(:string), do: "String"
  defp map_type_to_rust("string"), do: "String"
  defp map_type_to_rust(:binary), do: "Vec<u8>"
  defp map_type_to_rust({:array, inner}), do: "Vec<#{map_type_to_rust(inner)}>"
  defp map_type_to_rust({:list, inner}), do: "Vec<#{map_type_to_rust(inner)}>"
  defp map_type_to_rust({:option, inner}), do: "Option<#{map_type_to_rust(inner)}>"
  defp map_type_to_rust({:map, k, v}), do: "std::collections::HashMap<#{map_type_to_rust(k)}, #{map_type_to_rust(v)}>"
  defp map_type_to_rust(other) when is_binary(other), do: other
  defp map_type_to_rust(_), do: "serde_json::Value"

  defp to_snake_case(str), do: Macro.underscore(str)
end
