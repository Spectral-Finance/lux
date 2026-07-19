defmodule Lux.Cargo.Toml do
  @moduledoc """
  Minimal TOML decoder/encoder supporting the subset of TOML used by
  `Cargo.toml` manifests.

  This avoids introducing an external TOML dependency for the Cargo
  integration. It supports flat and nested tables (`[package]`,
  `[dependencies.serde]`), string/integer/float/boolean values, inline
  tables, and arrays.
  """

  @doc """
  Decodes a TOML string into a nested map.

  Returns `{:ok, map}` or `{:error, reason}`.
  """
  @spec decode(String.t()) :: {:ok, map()} | {:error, String.t()}
  def decode(toml) when is_binary(toml) do
    lines = String.split(toml, "\n")

    {result, _} =
      Enum.reduce(lines, {%{}, []}, fn line, {acc, table_path} ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" or String.starts_with?(trimmed, "#") ->
            {acc, table_path}

          String.starts_with?(trimmed, "[") ->
            {acc, parse_table_header(trimmed)}

          String.contains?(trimmed, "=") ->
            {acc, table_path} = assign_key_value(acc, table_path, trimmed)
            {acc, table_path}

          true ->
            {acc, table_path}
        end
      end)

    {:ok, result}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Encodes a nested map into a TOML string.

  Returns `{:ok, toml}` or `{:error, reason}`.
  """
  @spec encode(map()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(map) when is_map(map) do
    top_level =
      Enum.flat_map(Map.to_list(map), fn {key, value} ->
        if is_map(value) do
          []
        else
          ["#{encode_key(key)} = #{encode_value(value)}"]
        end
      end)

    tables =
      Enum.flat_map(Map.to_list(map), fn {key, value} ->
        if is_map(value) do
          render_table([key], value)
        else
          []
        end
      end)

    sections =
      [top_level | tables]
      |> Enum.reject(&(&1 == []))
      |> Enum.intersperse([""])

    {:ok, Enum.join(sections, "\n") <> "\n"}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp parse_table_header(header) do
    inner = String.trim(header, "[]")
    String.split(inner, ".")
  end

  defp assign_key_value(acc, table_path, line) do
    [key_str, value_str] = String.split(line, "=", parts: 2)
    key = String.trim(key_str)
    value = parse_value(String.trim(value_str))

    path = table_path ++ [key]
    {put_in_path(acc, path, value), table_path}
  end

  defp put_in_path(map, [key], value) do
    Map.put(map, key, value)
  end

  defp put_in_path(map, [key | rest], value) do
    Map.update(map, key, %{}, fn child ->
      put_in_path(child, rest, value)
    end)
  end

  defp render_table(path, map) when is_map(map) do
    header = "[" <> Enum.join(path, ".") <> "]"

    scalar_lines =
      Enum.flat_map(Map.to_list(map), fn {key, value} ->
        if is_map(value) do
          []
        else
          ["#{encode_key(key)} = #{encode_value(value)}"]
        end
      end)

    nested =
      Enum.flat_map(Map.to_list(map), fn {key, value} ->
        if is_map(value) do
          render_table(path ++ [key], value)
        else
          []
        end
      end)

    [["", header | scalar_lines] | Enum.map(nested, fn lines -> ["", "" | lines] end)]
  end

  defp encode_key(key) when is_atom(key), do: to_string(key)
  defp encode_key(key) when is_binary(key), do: key

  defp encode_value(value) when is_binary(value), do: inspect(value)
  defp encode_value(value) when is_boolean(value), do: to_string(value)
  defp encode_value(value) when is_integer(value), do: to_string(value)
  defp encode_value(value) when is_float(value), do: to_string(value)

  defp encode_value(value) when is_list(value) do
    items = Enum.map(value, &encode_value/1)
    "[" <> Enum.join(items, ", ") <> "]"
  end

  defp encode_value(value) when is_map(value) do
    items =
      Enum.map(Map.to_list(value), fn {k, v} ->
        "#{encode_key(k)} = #{encode_value(v)}"
      end)

    "{#{Enum.join(items, ", ")}}"
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value(str) when is_binary(str) do
    cond do
      String.starts_with?(str, "\"") ->
        parse_string(str)

      String.starts_with?(str, "[") ->
        parse_array(str)

      String.starts_with?(str, "{") ->
        parse_inline_table(str)

      Regex.match?(~r/^-?\d+\.\d+$/, str) ->
        String.to_float(str)

      Regex.match?(~r/^-?\d+$/, str) ->
        String.to_integer(str)

      true ->
        str
    end
  end

  defp parse_string(str) do
    trimmed = String.trim(str, "\"")
    String.replace(trimmed, "\\n", "\n")
  end

  defp parse_array(str) do
    inner = String.trim(str, "[]")
    inner
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_value/1)
  end

  defp parse_inline_table(str) do
    inner = String.trim(str, "{}")
    inner
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(%{}, fn pair, acc ->
      [k, v] = String.split(pair, "=", parts: 2)
      Map.put(acc, String.trim(k), parse_value(String.trim(v)))
    end)
  end
end
