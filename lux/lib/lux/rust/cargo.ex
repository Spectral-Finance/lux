defmodule Lux.Rust.Cargo do
  @moduledoc """
  Gerenciamento de pacotes Cargo e integração de build para Rust no ecossistema Lux.
  Atende aos requisitos da Issue #100 ($300).
  """

  @type manifest :: %{
          package: %{
            name: String.t(),
            version: String.t(),
            edition: String.t(),
            description: String.t() | nil,
            authors: [String.t()]
          },
          dependencies: %{optional(String.t()) => String.t() | map()},
          dev_dependencies: %{optional(String.t()) => String.t() | map()},
          features: %{optional(String.t()) => [String.t()]}
        }

  @doc "Cria um novo manifesto Cargo.toml em memória."
  @spec new_manifest(String.t(), keyword()) :: manifest()
  def new_manifest(name, opts \\ []) do
    %{
      package: %{
        name: name,
        version: Keyword.get(opts, :version, "0.1.0"),
        edition: Keyword.get(opts, :edition, "2021"),
        description: Keyword.get(opts, :description, "Lux Rust Native Module"),
        authors: Keyword.get(opts, :authors, [])
      },
      dependencies: Keyword.get(opts, :dependencies, %{}),
      dev_dependencies: Keyword.get(opts, :dev_dependencies, %{}),
      features: Keyword.get(opts, :features, %{})
    }
  end

  @doc "Adiciona dependência ao manifesto ou salva direto em arquivo."
  def add_dependency(%{} = manifest, dep_name, dep_spec) do
    updated_deps = Map.put(manifest.dependencies, dep_name, dep_spec)
    {:ok, %{manifest | dependencies: updated_deps}}
  end

  def add_dependency(project_dir, dep_name, dep_spec) when is_binary(project_dir) do
    toml_path = Path.join(project_dir, "Cargo.toml")
    with {:ok, content} <- File.read(toml_path),
         {:ok, manifest} <- parse_manifest(content),
         {:ok, updated_manifest} <- add_dependency(manifest, dep_name, dep_spec),
         :ok <- File.write(toml_path, to_toml(updated_manifest)) do
      {:ok, updated_manifest}
    end
  end

  @doc "Remove dependência do manifesto."
  def remove_dependency(%{} = manifest, dep_name) do
    {:ok, %{manifest | dependencies: Map.delete(manifest.dependencies, dep_name)}}
  end

  @doc "Serializa o manifesto para TOML válido."
  def to_toml(manifest) do
    pkg = manifest.package
    lines = [
      "[package]",
      "name = \"#{pkg.name}\"",
      "version = \"#{pkg.version}\"",
      "edition = \"#{pkg.edition}\""
    ]

    lines = if pkg.description, do: lines ++ ["description = \"#{pkg.description}\""], else: lines
    lines = if Enum.any?(pkg.authors), do: lines ++ ["authors = #{inspect(pkg.authors)}"], else: lines

    dep_lines =
      Enum.map(manifest.dependencies, fn
        {name, version} when is_binary(version) ->
          "#{name} = \"#{version}\""
        {name, %{} = opts} ->
          opts_str =
            opts
            |> Enum.map(fn {k, v} -> "#{k} = #{inspect(v)}" end)
            |> Enum.join(", ")
          "#{name} = { #{opts_str} }"
      end)

    (lines ++ ["", "[dependencies]"] ++ dep_lines)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  @doc "Lê e extrai dependências e pacote do Cargo.toml."
  def parse_manifest(toml_string) do
    name = Regex.run(~r/name\s*=\s*"([^"]+)"/, toml_string) |> Enum.at(1, "unnamed")
    version = Regex.run(~r/version\s*=\s*"([^"]+)"/, toml_string) |> Enum.at(1, "0.1.0")
    edition = Regex.run(~r/edition\s*=\s*"([^"]+)"/, toml_string) |> Enum.at(1, "2021")

    deps =
      case Regex.run(~r/\[dependencies\](.*?)(?:\[|\z)/s, toml_string) do
        [_, deps_block] ->
          deps_block
          |> String.split("\n")
          |> Enum.reduce(%{}, fn line, acc ->
            trimmed = String.trim(line)
            if String.starts_with?(trimmed, "#") or trimmed == "" do
              acc
            else
              case Regex.run(~r/^\s*([a-zA-Z0-9_\-]+)\s*=\s*"([^"]+)"/, trimmed) do
                [_, d_name, d_ver] -> Map.put(acc, d_name, d_ver)
                _ -> acc
              end
            end
          end)
        _ -> %{}
      end

    {:ok, %{
      package: %{name: name, version: version, edition: edition, description: nil, authors: []},
      dependencies: deps,
      dev_dependencies: %{},
      features: %{}
    }}
  end

  def build(project_dir, opts \\ []) do
    args = ["build"] ++ if(Keyword.get(opts, :release, false), do: ["--release"], else: [])
    run_cargo(project_dir, args, opts)
  end

  def test(project_dir, opts \\ []), do: run_cargo(project_dir, ["test"], opts)
  def check(project_dir, opts \\ []), do: run_cargo(project_dir, ["check"], opts)

  defp run_cargo(project_dir, args, opts) do
    cache_dir = Keyword.get(opts, :cache_dir)
    env = Keyword.get(opts, :env, [])
    env = if cache_dir, do: [{"CARGO_HOME", Path.expand(cache_dir)} | env], else: env

    case System.cmd("cargo", args, cd: project_dir, env: env, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, {code, output}}
    end
  rescue
    e in ErlangError -> {:error, "Executável do Cargo não encontrado: #{inspect(e)}"}
  end
end
