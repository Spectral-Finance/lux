defmodule Lux.Cargo.TOMLParser do
  @moduledoc """
  Cargo.toml parser and generator for Rust package management.

  Parses TOML-formatted Cargo.toml files and provides
  structured access to package metadata, dependencies, and features.
  """

  @doc """
  Parses a Cargo.toml file and returns a structured map.

  ## Examples

      iex> Lux.Cargo.TOMLParser.parse_file("Cargo.toml")
      {:ok, %{package: %{}, dependencies: %{}, dev_dependencies: %{}}}
  """
  @spec parse_file(Path.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, content} -> parse_content(content)
      {:error, _} = error -> error
    end
  end

  @doc """
  Parses TOML content string and returns a structured map.
  """
  @spec parse_content(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_content(content) do
    case Toml.parse(content) do
      {:ok, parsed} ->
        package = Map.get(parsed, "package", %{})
        dependencies = Map.get(parsed, "dependencies", %{})
        dev_dependencies = Map.get(parsed, "dev-dependencies", %{})
        features = Map.get(parsed, "features", %{})
        profile = Map.get(parsed, "profile", %{})

        {:ok, %{
          package: parse_package(package),
          dependencies: parse_dependencies(dependencies),
          dev_dependencies: parse_dependencies(dev_dependencies),
          features: features,
          profile: profile
        }}

      {:error, reason} ->
        {:error, "TOML parse error: #{inspect(reason)}"}
    end
  end

  @doc """
  Generates a Cargo.toml file from a structured map.
  """
  @spec generate(map()) :: String.t()
  def generate(%{package: pkg, dependencies: deps, dev_dependencies: dev_deps} = data) do
    lines = ["[package]"]

    lines =
      Enum.reduce(pkg, lines, fn {key, value}, acc ->
        ["#{key} = #{toml_value(value)}" | acc]
      end)

    lines =
      if deps do
        ["[dependencies]" | lines] ++
          Enum.map(deps, fn {name, config} ->
            "#{name} = #{toml_dep(config)}"
          end)
      else
        lines
      end

    lines =
      if dev_deps do
        ["[dev-dependencies]" | lines] ++
          Enum.map(dev_deps, fn {name, config} ->
            "#{name} = #{toml_dep(config)}"
          end)
      else
        lines
      end

    if features = Map.get(data, :features) do
      ["[features]" | lines] ++
        Enum.map(features, fn {name, vals} ->
          "#{name} = [#{Enum.map(vals, &inspect/1) |> Enum.join(", ")}]"
        end)
    else
      lines
    end
    |> Enum.reverse()
    |> Enum.join("\n")
    |> then(&(&1 <> "\n"))
  end

  defp parse_package(pkg) when is_map(pkg) do
    Map.take(pkg, ~w[name version edition authors description license repository homepage documentation readme categories keywords]]
  end

  defp parse_package(_), do: %{}

  defp parse_dependencies(deps) when is_map(deps) do
    deps
    |> Enum.map(fn {name, config} ->
      {name,
       case config do
         %{version: v, git: g} -> %{version: v, git: g}
         %{version: v} = c -> c
         v when is_binary(v) -> %{version: v}
         _ -> %{}
       end}
    end)
    |> Map.new()
  end

  defp parse_dependencies(_), do: %{}

  defp toml_dep(%{version: v, git: g, branch: b}) do
    "\"#{v}\", git = \"#{g}\", branch = \"#{b}\""
  end

  defp toml_dep(%{version: v, git: g}) do
    "\"#{v}\", git = \"#{g}\""
  end

  defp toml_dep(%{version: v}) do
    "\"#{v}\""
  end

  defp toml_dep(v) when is_binary(v) do
    "\"#{v}\""
  end

  defp toml_dep(_), do: "\"*\""

  defp toml_value(v) when is_binary(v) do
    "\"#{v}\""
  end

  defp toml_value(v) when is_number(v) do
    to_string(v)
  end

  defp toml_value(v) when is_list(v) do
    "[#{Enum.map(v, &inspect/1) |> Enum.join(", ")}]"
  end

  defp toml_value(v) when is_boolean(v) do
    if v, do: "true", else: "false"
  end

  defp toml_value(v) when is_map(v) do
    "{#{Enum.map(v, fn {k, val} -> "\"#{k}\" = #{toml_value(val)}" end) |> Enum.join(", ")}}"
  end

  defp toml_value(v), do: inspect(v)
end
