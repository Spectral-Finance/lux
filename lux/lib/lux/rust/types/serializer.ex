defmodule Lux.Rust.Types.Serializer do
  @moduledoc """
  Bidirectional serialization and deserialization between Elixir data structures
  (including custom structs and tagged tuples/enums) and Rust Serde JSON representations.
  """

  @doc """
  Serializes an Elixir term into a Serde-compatible map or JSON string.
  """
  @spec serialize(term(), keyword()) :: {:ok, term()} | {:error, term()}
  def serialize(term, opts \\ []) do
    format = Keyword.get(opts, :format, :map)

    converted = to_serde_compatible(term)

    case format do
      :map ->
        {:ok, converted}

      :json ->
        case Jason.encode(converted) do
          {:ok, json_str} -> {:ok, json_str}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Deserializes a Serde payload (map or JSON string) back into Elixir terms.
  """
  @spec deserialize(term(), keyword()) :: {:ok, term()} | {:error, term()}
  def deserialize(payload, opts \\ [])

  def deserialize(json_str, opts) when is_binary(json_str) do
    case Jason.decode(json_str) do
      {:ok, decoded} -> deserialize(decoded, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  def deserialize(map, _opts) when is_map(map) do
    cond do
      Map.has_key?(map, "__struct__") ->
        struct_name = Map.get(map, "__struct__")
        fields = Map.delete(map, "__struct__") |> deserialize_map_fields()

        case resolve_struct_module(struct_name) do
          {:ok, mod} ->
            atom_fields = Map.new(fields, fn {k, v} -> {String.to_atom(k), v} end)
            {:ok, struct(mod, atom_fields)}

          :error ->
            # Return as tagged struct map if module cannot be resolved
            {:ok, Map.put(fields, :__struct__, struct_name)}
        end

      Map.has_key?(map, "__enum__") ->
        variant = Map.get(map, "__enum__")
        payload = Map.get(map, "payload")

        atom_variant = String.to_atom(variant)

        if payload != nil do
          {:ok, {atom_variant, from_serde_compatible(payload)}}
        else
          {:ok, atom_variant}
        end

      true ->
        {:ok, deserialize_map_fields(map)}
    end
  end

  def deserialize(list, _opts) when is_list(list) do
    {:ok, Enum.map(list, &from_serde_compatible/1)}
  end

  def deserialize(primitive, _opts), do: {:ok, primitive}

  # Helpers
  def to_serde_compatible(nil), do: nil
  def to_serde_compatible(val) when is_boolean(val), do: val
  def to_serde_compatible(val) when is_integer(val), do: val
  def to_serde_compatible(val) when is_float(val), do: val
  def to_serde_compatible(val) when is_binary(val), do: val

  def to_serde_compatible(val) when is_atom(val) do
    # Represent standalone atom as unit enum variant
    %{
      "__enum__" => Atom.to_string(val)
    }
  end

  def to_serde_compatible({variant, payload}) when is_atom(variant) do
    # Tagged tuple enum: {:ok, data} or {:error, reason}
    %{
      "__enum__" => Atom.to_string(variant),
      "payload" => to_serde_compatible(payload)
    }
  end

  def to_serde_compatible(%{__struct__: struct_mod} = struct_val) do
    fields =
      struct_val
      |> Map.from_struct()
      |> Map.new(fn {k, v} -> {Atom.to_string(k), to_serde_compatible(v)} end)

    Map.put(fields, "__struct__", inspect(struct_mod))
  end

  def to_serde_compatible(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      key = if is_atom(k), do: Atom.to_string(k), else: to_string(k)
      {key, to_serde_compatible(v)}
    end)
  end

  def to_serde_compatible(list) when is_list(list) do
    Enum.map(list, &to_serde_compatible/1)
  end

  def to_serde_compatible(other), do: inspect(other)

  defp from_serde_compatible(val) when is_map(val) do
    case deserialize(val) do
      {:ok, res} -> res
      _ -> val
    end
  end
  defp from_serde_compatible(val) when is_list(val) do
    Enum.map(val, &from_serde_compatible/1)
  end
  defp from_serde_compatible(other), do: other

  defp deserialize_map_fields(map) do
    Map.new(map, fn {k, v} -> {k, from_serde_compatible(v)} end)
  end

  defp resolve_struct_module(mod_str) when is_binary(mod_str) do
    mod_str
    |> String.split(".")
    |> Module.concat()
    |> Code.ensure_loaded()
    |> case do
      {:module, m} -> {:ok, m}
      _ -> :error
    end
  end
  defp resolve_struct_module(_), do: :error
end
