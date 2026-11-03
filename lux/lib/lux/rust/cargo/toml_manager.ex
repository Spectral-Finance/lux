defmodule Lux.Rust.Cargo.TomlManager do
  @moduledoc """
  Utilities for reading, parsing, modifying, and serializing `Cargo.toml` files.
  """

  @doc """
  Parses a Cargo.toml file into a map of sections and dependencies.
  """
  @spec parse_file(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, content} ->
        parse_string(content)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses raw Cargo.toml string.
  """
  @spec parse_string(String.t()) :: {:ok, map()}
  def parse_string(content) do
    lines = String.split(content, ~r/\r?\n/)

    {parsed, _current_section} =
      Enum.reduce(lines, {%{"package" => %{}, "dependencies" => %{}, "features" => %{}}, nil}, fn line, {acc, cur_sec} ->
        trimmed = String.trim(line)

        cond do
          trimmed == "" or String.starts_with?(trimmed, "#") ->
            {acc, cur_sec}

          String.starts_with?(trimmed, "[") and String.ends_with?(trimmed, "]") ->
            sec = String.slice(trimmed, 1..-2//1)
            new_acc = Map.put_new(acc, sec, %{})
            {new_acc, sec}

          cur_sec != nil and String.contains?(trimmed, "=") ->
            [key, val] = String.split(trimmed, "=", parts: 2)
            k = String.trim(key)
            v = parse_value(String.trim(val))
            sec_map = Map.get(acc, cur_sec, %{})
            updated_sec = Map.put(sec_map, k, v)
            {Map.put(acc, cur_sec, updated_sec), cur_sec}

          true ->
            {acc, cur_sec}
        end
      end)

    {:ok, parsed}
  end

  @doc """
  Adds or updates a dependency in a `Cargo.toml` file content.
  """
  @spec add_dependency_to_content(String.t(), String.t(), map() | String.t()) :: String.t()
  def add_dependency_to_content(content, crate_name, spec) do
    dep_line = format_dep_line(crate_name, spec)
    lines = String.split(content, ~r/\r?\n/)

    # Check if crate is already present
    already_present =
      Enum.any?(lines, fn l ->
        trimmed = String.trim(l)
        String.starts_with?(trimmed, "#{crate_name} =") or String.starts_with?(trimmed, "#{crate_name}=")
      end)

    if already_present do
      lines
      |> Enum.map(fn l ->
        trimmed = String.trim(l)
        if String.starts_with?(trimmed, "#{crate_name} =") or String.starts_with?(trimmed, "#{crate_name}=") do
          dep_line
        else
          l
        end
      end)
      |> Enum.join("\n")
    else
      # Insert under [dependencies]
      {updated_lines, _found} =
        Enum.reduce(lines, {[], false}, fn line, {acc, found_dep} ->
          trimmed = String.trim(line)
          if trimmed == "[dependencies]" do
            {[dep_line, line | acc], true}
          else
            {[line | acc], found_dep}
          end
        end)

      Enum.reverse(updated_lines) |> Enum.join("\n")
    end
  end

  @doc """
  Removes a dependency from a `Cargo.toml` file content.
  """
  @spec remove_dependency_from_content(String.t(), String.t()) :: String.t()
  def remove_dependency_from_content(content, crate_name) do
    content
    |> String.split(~r/\r?\n/)
    |> Enum.reject(fn l ->
      trimmed = String.trim(l)
      String.starts_with?(trimmed, "#{crate_name} =") or String.starts_with?(trimmed, "#{crate_name}=")
    end)
    |> Enum.join("\n")
  end

  defp format_dep_line(crate_name, version) when is_binary(version) do
    ~s(#{crate_name} = "#{version}")
  end

  defp format_dep_line(crate_name, opts) when is_map(opts) do
    fields =
      Enum.map(opts, fn
        {k, v} when is_binary(v) -> ~s(#{k} = "#{v}")
        {k, v} when is_list(v) ->
          items = Enum.map_join(v, ", ", &~s("#{&1}"))
          ~s(#{k} = [#{items}])
        {k, v} when is_boolean(v) -> ~s(#{k} = #{v})
      end)
      |> Enum.join(", ")

    "#{crate_name} = { #{fields} }"
  end

  defp parse_value(val) do
    cond do
      String.starts_with?(val, "\"") and String.ends_with?(val, "\"") ->
        String.slice(val, 1..-2//1)

      String.starts_with?(val, "{") and String.ends_with?(val, "}") ->
        inner = String.slice(val, 1..-2//1)
        inner
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.reduce(%{}, fn part, acc ->
          case String.split(part, "=", parts: 2) do
            [k, v] -> Map.put(acc, String.trim(k), parse_value(String.trim(v)))
            _ -> acc
          end
        end)

      String.starts_with?(val, "[") and String.ends_with?(val, "]") ->
        inner = String.slice(val, 1..-2//1)
        inner
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&parse_value/1)

      val == "true" -> true
      val == "false" -> false
      true -> val
    end
  end
end
