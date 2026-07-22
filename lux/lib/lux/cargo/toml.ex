defmodule Lux.Cargo.Toml do
  @moduledoc """
  A robust native Elixir parser and encoder for Cargo.toml structures.
  Supports arrays, inline tables, dotted keys, and basic string escaping.
  """

  @spec decode(String.t()) :: {:ok, map()} | {:error, String.t()}
  def decode(toml_str) when is_binary(toml_str) do
    lines = String.split(toml_str, "\n")

    try do
      {result, _} =
        Enum.reduce(lines, {%{}, []}, fn line, {acc, section} ->
          line = String.trim(line)

          cond do
            line == "" or String.starts_with?(line, "#") ->
              {acc, section}

            String.starts_with?(line, "[[") and String.ends_with?(line, "]]") ->
              sec_name = String.slice(line, 2..(String.length(line) - 3)) |> String.trim()
              sec_path = parse_section_path(sec_name)
              updated_acc = append_to_array_of_tables(acc, sec_path)
              {updated_acc, sec_path ++ [:last]}

            String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
              sec_name = String.slice(line, 1..(String.length(line) - 2)) |> String.trim()
              sec_path = parse_section_path(sec_name)
              updated_acc = ensure_section_exists(acc, sec_path)
              {updated_acc, sec_path}

            String.contains?(line, "=") ->
              [k, v] = String.split(line, "=", parts: 2)
              key = String.trim(k)
              val = parse_value(String.trim(v))
              updated_acc = put_in_section(acc, section, key, val)
              {updated_acc, section}

            true ->
              {acc, section}
          end
        end)

      {:ok, result}
    rescue
      e -> {:error, "TOML parsing failed: #{inspect(e)}"}
    end
  end

  @spec encode(map()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(map) when is_map(map) do
    try do
      lines = encode_map(map, [])
      {:ok, Enum.join(lines, "\n") <> "\n"}
    rescue
      e -> {:error, "TOML encoding failed: #{inspect(e)}"}
    end
  end

  defp parse_section_path(sec_name) do
    sec_name
    |> String.split(".")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp ensure_section_exists(acc, path) do
    put_in_path(acc, path, %{})
  end

  defp append_to_array_of_tables(acc, path) do
    current = get_in_path(acc, path) || []
    put_in_path(acc, path, current ++ [%{}])
  end

  defp put_in_section(acc, [], key, val) do
    Map.put(acc, key, val)
  end

  defp put_in_section(acc, section, key, val) do
    path = resolve_section_path(acc, section)
    update_in_path(acc, path, fn map -> Map.put(map || %{}, key, val) end)
  end

  defp resolve_section_path(acc, section) do
    if List.last(section) == :last do
      parent_path = Enum.drop(section, -1)
      list = get_in_path(acc, parent_path) || []
      parent_path ++ [length(list) - 1]
    else
      section
    end
  end

  defp get_in_path(map, path) do
    get_in(map, Enum.map(path, &Access.key(&1, nil)))
  end

  defp put_in_path(map, path, value) do
    case path do
      [] -> map
      [h | t] ->
        current = Map.get(map, h, %{})
        Map.put(map, h, put_in_path(current, t, value))
    end
  end

  defp update_in_path(map, path, fun) do
    case path do
      [] -> map
      [h] when is_integer(h) ->
        List.update_at(map, h, fun)
      [h] ->
        Map.update(map, h, fun.(nil), fun)
      [h | t] when is_integer(h) ->
        List.update_at(map, h, &update_in_path(&1, t, fun))
      [h | t] ->
        current = Map.get(map, h, %{})
        Map.put(map, h, update_in_path(current, t, fun))
    end
  end

  defp parse_value(str) do
    str = String.trim(str)

    cond do
      String.starts_with?(str, "\"") and String.ends_with?(str, "\"") ->
        str
        |> String.slice(1..(String.length(str) - 2))
        |> String.replace("\\\"", "\"")
        |> String.replace("\\n", "\n")
        |> String.replace("\\\\", "\\")

      String.starts_with?(str, "[") and String.ends_with?(str, "]") ->
        str
        |> String.slice(1..(String.length(str) - 2))
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&parse_value/1)

      String.starts_with?(str, "{") and String.ends_with?(str, "}") ->
        str
        |> String.slice(1..(String.length(str) - 2))
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.reduce(%{}, fn pair, acc ->
          case String.split(pair, "=", parts: 2) do
            [k, v] -> Map.put(acc, String.trim(k), parse_value(String.trim(v)))
            _ -> acc
          end
        end)

      str == "true" -> true
      str == "false" -> false

      Regex.match?(~r/^-?\d+\.\d+$/, str) ->
        String.to_float(str)

      Regex.match?(~r/^-?\d+$/, str) ->
        String.to_integer(str)

      true ->
        str
    end
  end

  defp encode_map(map, parent_keys) do
    {simple, complex} =
      map
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.split_with(fn {_, v} -> not is_map(v) and not is_list(v) end)

    simple_lines = Enum.map(simple, fn {k, v} -> "#{k} = #{encode_val(v)}" end)

    complex_lines =
      Enum.flat_map(complex, fn
        {k, v} when is_map(v) ->
          header = "[" <> Enum.join(parent_keys ++ [k], ".") <> "]"
          ["", header] ++ encode_map(v, parent_keys ++ [k])

        {k, v} when is_list(v) ->
          if Enum.all?(v, &is_map/1) do
            Enum.flat_map(v, fn item ->
              header = "[[" <> Enum.join(parent_keys ++ [k], ".") <> "]]"
              ["", header] ++ encode_map(item, parent_keys ++ [k])
            end)
          else
            ["#{k} = #{encode_val(v)}"]
          end
      end)

    simple_lines ++ complex_lines
  end

  defp encode_val(val) do
    cond do
      is_binary(val) ->
        escaped =
          val
          |> String.replace("\\", "\\\\")
          |> String.replace("\"", "\\\"")
          |> String.replace("\n", "\\n")

        "\"#{escaped}\""

      is_boolean(val) -> to_string(val)
      is_integer(val) -> to_string(val)
      is_float(val) -> to_string(val)
      is_list(val) ->
        "[" <> (Enum.map(val, &encode_val/1) |> Enum.join(", ")) <> "]"

      is_map(val) ->
        pairs =
          val
          |> Enum.sort_by(fn {k, _} -> k end)
          |> Enum.map(fn {k, v} -> "#{k} = #{encode_val(v)}" end)

        "{ " <> Enum.join(pairs, ", ") <> " }"

      true ->
        inspect(val)
    end
  end
end
