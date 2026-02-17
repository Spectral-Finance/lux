defmodule Lux.Rust.Test do
  @moduledoc """
  Handles Rust testing integration for Lux.
  """

  def run_tests(repo_path) do
    System.cmd("cargo", ["test"], cd: Path.join(repo_path, "native/lux_rust"))
  end
end
