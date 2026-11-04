defmodule Lux.Integrations.Cargo do
  @moduledoc """
  Cargo package management integration for Lux.
  """

  def generate_toml(name, version, dependencies \\ %{}) do
    """
    [package]
    name = "#{name}"
    version = "#{version}"
    edition = "2021"

    [dependencies]
    #{Enum.map(dependencies, fn {k, v} -> "#{k} = \"#{v}\"" end) |> Enum.join("\n")}
    """
  end

  def build(path) do
    case System.cmd("cargo", ["build", "--release"], cd: path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  def resolve_dependencies(path) do
    case System.cmd("cargo", ["fetch"], cd: path) do
      {_, 0} -> :ok
      {err, _} -> {:error, err}
    end
  end
end