defmodule Lux.Rust.Cargo do
  @moduledoc """
  Handles Cargo.toml management for Lux Rust components.
  """

  def add_dependency(repo_path, name, version) do
    path = Path.join([repo_path, "native/lux_rust/Cargo.toml"])
    content = File.read!(path)
    if String.contains?(content, "#{name} =") do
      {:error, :already_exists}
    else
      new_content = String.replace(content, "[dependencies]", "[dependencies]\n#{name} = \"#{version}\"")
      File.write!(path, new_content)
      {:ok, :added}
    end
  end

  def build(repo_path) do
    System.cmd("mix", ["compile"], cd: repo_path)
  end
end
