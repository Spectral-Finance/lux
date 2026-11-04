defmodule Lux.Rust.TypeSystem do
  @moduledoc """
  Advanced Type System Mapping and Bidirectional Serde Serialization between
  Elixir and Rust (`Spectral-Finance/lux#101`).

  Provides:
  - Primitive and generic type mapping (`elixir_to_rust_type/1`)
  - Custom struct and enum type definitions (`define_struct/4`, `define_enum/4`)
  - Serde Rust code generation (`generate_serde_rust_code/1`)
  - Bidirectional serialization and deserialization (`to_rust_payload/2`, `from_rust_payload/2`)
  """

  @registry_table :lux_rust_type_registry

  @primitive_mappings %{
    :i8 => "i8",
    :i16 => "i16",
    :i32 => "i32",
    :i64 => "i64",
    :i128 => "i128",
    :u8 => "u8",
    :u16 => "u16",
    :u32 => "u32",
    :u64 => "u64",
    :u128 => "u128",
    :usize => "usize",
    :f32 => "f32",
    :f64 => "f64",
    :bool => "bool",
    :string => "String",
    :binary => "Vec<u8>",
    :atom => "String",
    :any => "serde_json::Value"
  }

  defp ensure_registry do
    case :ets.whereis(@registry_table) do
      :undefined -> :ets.new(@registry_table, [:named_table, :public, :set, read_concurrency: true])
      _ -> @registry_table
    end
  end

  @doc """
  Maps an Elixir/Lux type specification to its canonical Rust/Serde type signature.
  """
  def elixir_to_rust_type(type) when is_atom(type) do
    case Map.get(@primitive_mappings, type) do
      nil ->
        ensure_registry()
        case :ets.lookup(@registry_table, type) do
          [{^type, %{rust_name: rust_name}}] -> {:ok, rust_name}
          [] -> {:error, {:unknown_type, type}}
        end

      rust_str ->
        {:ok, rust_str}
    end
  end

  def elixir_to_rust_type({:vec, inner}) do
    with {:ok, inner_rs} <- elixir_to_rust_type(inner) do
      {:ok, "Vec<#{inner_rs}>"}
    end
  end

  def elixir_to_rust_type({:option, inner}) do
    with {:ok, inner_rs} <- elixir_to_rust_type(inner) do
      {:ok, "Option<#{inner_rs}>"}
    end
  end

  def elixir_to_rust_type({:result, ok_t, err_t}) do
    with {:ok, ok_rs} <- elixir_to_rust_type(ok_t),
         {:ok, err_rs} <- elixir_to_rust_type(err_t) do
      {:ok, "Result<#{ok_rs}, #{err_rs}>"}
    end
  end

  def elixir_to_rust_type({:hashmap, key_t, val_t}) do
    with {:ok, key_rs} <- elixir_to_rust_type(key_t),
         {:ok, val_rs} <- elixir_to_rust_type(val_t) do
      {:ok, "std::collections::HashMap<#{key_rs}, #{val_rs}>"}
    end
  end

  def elixir_to_rust_type({:tuple, types}) when is_list(types) do
    results = Enum.map(types, &elixir_to_rust_type/1)
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      inner = results |> Enum.map(fn {:ok, t} -> t end) |> Enum.join(", ")
      {:ok, "(#{inner})"}
    else
      Enum.find(results, &match?({:error, _}, &1))
    end
  end

  def elixir_to_rust_type(other), do: {:error, {:unsupported_type_spec, other}}

  @doc """
  Registers a custom Rust struct definition with field types and Serde options.
  """
  def define_struct(type_id, rust_name, fields, opts \\ []) when is_atom(type_id) and is_list(fields) do
    ensure_registry()

    definition = %{
      kind: :struct,
      id: type_id,
      rust_name: rust_name,
      fields: fields,
      rename_all: Keyword.get(opts, :rename_all, "snake_case")
    }

    :ets.insert(@registry_table, {type_id, definition})
    {:ok, definition}
  end

  @doc """
  Registers a custom Rust enum definition supporting unit, tuple, and struct variants.
  """
  def define_enum(type_id, rust_name, variants, opts \\ []) when is_atom(type_id) and is_list(variants) do
    ensure_registry()

    definition = %{
      kind: :enum,
      id: type_id,
      rust_name: rust_name,
      variants: variants,
      tag: Keyword.get(opts, :tag, "type"),
      content: Keyword.get(opts, :content, "data")
    }

    :ets.insert(@registry_table, {type_id, definition})
    {:ok, definition}
  end

  @doc """
  Generates the Rust source definition with `#[derive(Debug, Clone, Serialize, Deserialize)]`
  for a registered custom struct or enum.
  """
  def generate_serde_rust_code(type_id) when is_atom(type_id) do
    ensure_registry()

    case :ets.lookup(@registry_table, type_id) do
      [{^type_id, %{kind: :struct} = defn}] ->
        fields_code =
          Enum.map_join(defn.fields, "\n", fn {fname, ftype} ->
            {:ok, rs_type} = elixir_to_rust_type(ftype)
            "    pub #{fname}: #{rs_type},"
          end)

        code = """
        #[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
        #[serde(rename_all = "#{defn.rename_all}")]
        pub struct #{defn.rust_name} {
        #{fields_code}
        }
        """

        {:ok, String.trim(code)}

      [{^type_id, %{kind: :enum} = defn}] ->
        variants_code =
          Enum.map_join(defn.variants, "\n", fn
            {vname, :unit} ->
              "    #{vname},"

            {vname, {:tuple, inner_types}} ->
              inner_rs =
                inner_types
                |> Enum.map(fn t ->
                  {:ok, r} = elixir_to_rust_type(t)
                  r
                end)
                |> Enum.join(", ")

              "    #{vname}(#{inner_rs}),"

            {vname, {:struct, vfields}} ->
              vf_str =
                Enum.map_join(vfields, ", ", fn {k, t} ->
                  {:ok, r} = elixir_to_rust_type(t)
                  "#{k}: #{r}"
                end)

              "    #{vname} { #{vf_str} },"
          end)

        code = """
        #[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
        #[serde(tag = "#{defn.tag}", content = "#{defn.content}")]
        pub enum #{defn.rust_name} {
        #{variants_code}
        }
        """

        {:ok, String.trim(code)}

      [] ->
        {:error, {:type_not_registered, type_id}}
    end
  end

  @doc """
  Validates and converts an Elixir term into a Serde-compatible payload according to `type_spec`.
  """
  def to_rust_payload(value, type_spec) do
    with {:ok, normalized} <- normalize_to_rust(value, type_spec),
         {:ok, json} <- Jason.encode(normalized) do
      {:ok, %{payload: normalized, json: json}}
    end
  end

  @doc """
  Deserializes and converts a Rust/Serde JSON or map payload back into a typed Elixir structure.
  """
  def from_rust_payload(raw, type_spec) when is_binary(raw) do
    with {:ok, decoded} <- Jason.decode(raw) do
      from_rust_payload(decoded, type_spec)
    end
  end

  def from_rust_payload(decoded, type_spec) do
    denormalize_from_rust(decoded, type_spec)
  end

  defp normalize_to_rust(val, t) when t in [:i8, :i16, :i32, :i64, :i128] and is_integer(val), do: {:ok, val}
  defp normalize_to_rust(val, t) when t in [:u8, :u16, :u32, :u64, :u128, :usize] and is_integer(val) and val >= 0, do: {:ok, val}
  defp normalize_to_rust(val, t) when t in [:f32, :f64] and is_number(val), do: {:ok, val * 1.0}
  defp normalize_to_rust(val, :bool) when is_boolean(val), do: {:ok, val}
  defp normalize_to_rust(val, :string) when is_binary(val), do: {:ok, val}
  defp normalize_to_rust(val, :atom) when is_atom(val), do: {:ok, Atom.to_string(val)}
  defp normalize_to_rust(val, :any), do: {:ok, val}

  defp normalize_to_rust(nil, {:option, _inner}), do: {:ok, nil}
  defp normalize_to_rust(val, {:option, inner}), do: normalize_to_rust(val, inner)

  defp normalize_to_rust(list, {:vec, inner}) when is_list(list) do
    results = Enum.map(list, &normalize_to_rust(&1, inner))
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, v} -> v end)}
    else
      {:error, :invalid_vec_element}
    end
  end

  defp normalize_to_rust(map, {:hashmap, k_type, v_type}) when is_map(map) do
    Enum.reduce_while(map, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, nk} <- normalize_to_rust(k, k_type),
           {:ok, nv} <- normalize_to_rust(v, v_type) do
        {:cont, {:ok, Map.put(acc, to_string(nk), nv)}}
      else
        err -> {:halt, err}
      end
    end)
  end

  defp normalize_to_rust(tuple, {:tuple, types}) when is_tuple(tuple) do
    elems = Tuple.to_list(tuple)
    if length(elems) == length(types) do
      pairs = Enum.zip(elems, types)
      results = Enum.map(pairs, fn {e, t} -> normalize_to_rust(e, t) end)
      if Enum.all?(results, &match?({:ok, _}, &1)) do
        {:ok, Enum.map(results, fn {:ok, v} -> v end)}
      else
        {:error, :invalid_tuple_element}
      end
    else
      {:error, :tuple_arity_mismatch}
    end
  end

  defp normalize_to_rust(map, type_id) when is_atom(type_id) and is_map(map) do
    ensure_registry()

    case :ets.lookup(@registry_table, type_id) do
      [{^type_id, %{kind: :struct, fields: fields}}] ->
        Enum.reduce_while(fields, {:ok, %{}}, fn {fname, ftype}, {:ok, acc} ->
          raw_val = Map.get(map, fname, Map.get(map, Atom.to_string(fname)))
          case normalize_to_rust(raw_val, ftype) do
            {:ok, nval} -> {:cont, {:ok, Map.put(acc, Atom.to_string(fname), nval)}}
            err -> {:halt, err}
          end
        end)

      [{^type_id, %{kind: :enum, variants: variants, tag: tag, content: content}}] ->
        variant_name = Map.get(map, :variant) || Map.get(map, "variant")
        data = Map.get(map, :data) || Map.get(map, "data")

        case Enum.find(variants, fn {vname, _} -> to_string(vname) == to_string(variant_name) end) do
          {vname, :unit} ->
            {:ok, %{tag => to_string(vname)}}

          {vname, {:tuple, inner_types}} ->
            with {:ok, norm_tuple} <- normalize_to_rust(data, {:tuple, inner_types}) do
              {:ok, %{tag => to_string(vname), content => norm_tuple}}
            end

          {vname, {:struct, vfields}} ->
            res =
              Enum.reduce_while(vfields, {:ok, %{}}, fn {fk, ft}, {:ok, acc} ->
                v = Map.get(data || %{}, fk, Map.get(data || %{}, Atom.to_string(fk)))
                case normalize_to_rust(v, ft) do
                  {:ok, nv} -> {:cont, {:ok, Map.put(acc, Atom.to_string(fk), nv)}}
                  err -> {:halt, err}
                end
              end)

            with {:ok, norm_struct} <- res do
              {:ok, %{tag => to_string(vname), content => norm_struct}}
            end

          nil ->
            {:error, {:unknown_enum_variant, variant_name}}
        end

      [] ->
        {:error, {:type_not_registered, type_id}}
    end
  end

  defp normalize_to_rust(val, type_spec), do: {:error, {:type_mismatch, val, type_spec}}

  defp denormalize_from_rust(nil, {:option, _inner}), do: {:ok, nil}
  defp denormalize_from_rust(val, {:option, inner}), do: denormalize_from_rust(val, inner)

  defp denormalize_from_rust(val, {:vec, inner}) when is_list(val) do
    results = Enum.map(val, &denormalize_from_rust(&1, inner))
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(results, fn {:ok, v} -> v end)}
    else
      {:error, :invalid_vec_payload}
    end
  end

  defp denormalize_from_rust(val, {:tuple, types}) when is_list(val) do
    if length(val) == length(types) do
      results =
        Enum.zip(val, types)
        |> Enum.map(fn {v, t} -> denormalize_from_rust(v, t) end)

      if Enum.all?(results, &match?({:ok, _}, &1)) do
        {:ok, results |> Enum.map(fn {:ok, v} -> v end) |> List.to_tuple()}
      else
        {:error, :invalid_tuple_payload}
      end
    else
      {:error, :tuple_arity_mismatch}
    end
  end

  defp denormalize_from_rust(val, :atom) when is_binary(val), do: {:ok, String.to_atom(val)}

  defp denormalize_from_rust(map, type_id) when is_atom(type_id) and is_map(map) do
    ensure_registry()

    case :ets.lookup(@registry_table, type_id) do
      [{^type_id, %{kind: :struct, fields: fields}}] ->
        Enum.reduce_while(fields, {:ok, %{}}, fn {fname, ftype}, {:ok, acc} ->
          raw_val = Map.get(map, Atom.to_string(fname), Map.get(map, fname))
          case denormalize_from_rust(raw_val, ftype) do
            {:ok, dval} -> {:cont, {:ok, Map.put(acc, fname, dval)}}
            err -> {:halt, err}
          end
        end)

      [{^type_id, %{kind: :enum, variants: variants, tag: tag, content: content}}] ->
        vname_str = Map.get(map, tag)
        raw_content = Map.get(map, content)

        case Enum.find(variants, fn {vn, _} -> to_string(vn) == to_string(vname_str) end) do
          {vn, :unit} ->
            {:ok, %{variant: vn, data: nil}}

          {vn, {:tuple, inner_types}} ->
            with {:ok, tup} <- denormalize_from_rust(raw_content, {:tuple, inner_types}) do
              {:ok, %{variant: vn, data: tup}}
            end

          {vn, {:struct, vfields}} ->
            res =
              Enum.reduce_while(vfields, {:ok, %{}}, fn {fk, ft}, {:ok, acc} ->
                rv = Map.get(raw_content || %{}, Atom.to_string(fk), Map.get(raw_content || %{}, fk))
                case denormalize_from_rust(rv, ft) do
                  {:ok, dv} -> {:cont, {:ok, Map.put(acc, fk, dv)}}
                  err -> {:halt, err}
                end
              end)

            with {:ok, st} <- res do
              {:ok, %{variant: vn, data: st}}
            end

          nil ->
            {:error, {:unknown_enum_variant, vname_str}}
        end

      [] ->
        {:ok, map}
    end
  end

  defp denormalize_from_rust(val, _primitive), do: {:ok, val}
end
