defmodule Lux.Cargo.VersionManager do
  @moduledoc """
  Cargo version management system.

  Handles version parsing, comparison, and constraint checking
  for Rust package dependencies.
  """

  @doc """
  Parses a version string into components.

  ## Examples

      iex> Lux.Cargo.VersionManager.parse("1.2.3")
      {:ok, %{major: 1, minor: 2, patch: 3}}
  """
  @spec parse(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse(version) do
    case Regex.run(~r/^(\d+)\.(\d+)\.(\d+)/, version) do
      [_, major, minor, patch] ->
        {:ok, %{
          major: String.to_integer(major),
          minor: String.to_integer(minor),
          patch: String.to_integer(patch),
          original: version
        }}

      _ ->
        {:error, "Invalid version format: #{version}"}
    end
  end

  @doc """
  Checks if a version satisfies a constraint.

  Supports: ^, ~, =, >=, <=, >, <, *
  """
  @spec satisfies?(String.t(), String.t()) :: boolean()
  def satisfies?(version, constraint) do
    with {:ok, ver} <- parse(version) do
      do_satisfies?(ver, constraint)
    else
      _ -> false
    end
  end

  defp do_satisfies?(%{major: m, minor: mi, patch: p}, "*" ), do: true
  defp do_satisfies?(%{major: m, minor: mi, patch: p}, "=" <> c), do: parse(c) == {:ok, %{major: m, minor: mi, patch: p}}
  defp do_satisfies?(%{major: m, minor: mi, patch: p}, "^" <> c) do
    {:ok, constrained} = parse(c)
    m == constrained.major
  end
  defp do_satisfies?(%{major: m, minor: mi, patch: p}, "~" <> c) do
    {:ok, constrained} = parse(c)
    m == constrained.major && mi == constrained.minor
  end
  defp do_satisfies?(_, _), do: false

  @doc """
  Gets the latest compatible version from a list.
  """
  @spec latest_compatible(String.t(), [String.t()]) :: String.t() | nil
  def latest_compatible(constraint, versions) do
    versions
    |> Enum.filter(&satisfies?(&1, constraint))
    |> Enum.sort(&version_gte?/2)
    |> List.first()
  end

  defp version_gte?(v1, v2) do
    with {:ok, a} <- parse(v1),
         {:ok, b} <- parse(v2) do
      a.major > b.major or
        (a.major == b.major and a.minor > b.minor) or
        (a.major == b.major and a.minor == b.minor and a.patch >= b.patch)
    else
      _ -> false
    end
  end
end
