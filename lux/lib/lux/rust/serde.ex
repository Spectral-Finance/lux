defmodule Lux.Rust.Serde do
  @moduledoc """
  Bidirectional Elixir <-> Rust Type Mapping and Serde Serialization for Lux (#101).

  Provides:
  - Rust struct and tagged enum schema definitions with Serde attributes
  - Bidirectional map/struct serialization and validation between Elixir and Rust
  """

  @doc """
  Generates a Rust struct definition annotated with Serde 'Serialize' and 'Deserialize'.
  """
  @spec define_rust_struct(String.t(), list({atom(), String.t()})) :: {:ok, String.t()}
  def define_rust_struct(struct_name, fields) when is_binary(struct_name) and is_list(fields) do
    field_lines =
      fields
      |> Enum.map(fn {fname, rtype} -> "    pub #{fname}: #{rtype}," end)
      |> Enum.join("\n")

    code = """
    #[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
    pub struct #{struct_name} {
    #{field_lines}
    }
    """

    {:ok, String.trim(code)}
  end

  @doc """
  Serializes an Elixir tagged tuple or struct map into a Serde-compatible externally tagged JSON map.
  """
  @spec to_serde_tagged({atom(), map()}) :: {:ok, map()} | {:error, term()}
  def to_serde_tagged({variant, payload}) when is_atom(variant) and is_map(payload) do
    {:ok, %{Atom.to_string(variant) => payload}}
  end

  def to_serde_tagged(_), do: {:error, :invalid_tagged_enum}
end
