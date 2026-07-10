defmodule Lux.Integrations.YouTube.Utils do
  @moduledoc """
  Utilities for YouTube integration, specifically handling key normalization and camelCasing.
  """

  @doc """
  Normalizes a map of parameters by converting all keys (and nested keys) to snake_case atoms.
  Handles string keys and camelCase keys.
  """
  def normalize_to_atoms(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      key_atom =
        cond do
          is_atom(k) ->
            k |> Atom.to_string() |> camel_to_snake() |> String.to_atom()
          is_binary(k) ->
            k |> camel_to_snake() |> String.to_atom()
          true ->
            k
        end
      Map.put(acc, key_atom, normalize_value(v))
    end)
  end

  def normalize_to_atoms(other), do: other

  defp normalize_value(v) when is_map(v), do: normalize_to_atoms(v)
  defp normalize_value(v) when is_list(v), do: Enum.map(v, &normalize_value/1)
  defp normalize_value(v), do: v

  @doc """
  Converts camelCase string to snake_case string.
  """
  def camel_to_snake(string) when is_binary(string) do
    string
    |> Macro.underscore()
  end

  @doc """
  Converts snake_case keys in a map to camelCase strings.
  Also applies common YouTube parameter alias mapping.
  """
  def to_youtube_query_params(params) when is_map(params) do
    params
    |> normalize_to_atoms()
    |> map_aliases()
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      camel_key = to_camel_case(Atom.to_string(k))
      Map.put(acc, camel_key, v)
    end)
  end

  defp map_aliases(params) do
    params
    # e.g., if video_id is present, but the API wants 'id'
    |> maybe_rename(:video_id, :id)
    |> maybe_rename(:broadcast_id, :id)
  end

  defp maybe_rename(map, old_key, new_key) do
    if Map.has_key?(map, old_key) and not Map.has_key?(map, new_key) do
      val = Map.get(map, old_key)
      map |> Map.delete(old_key) |> Map.put(new_key, val)
    else
      map
    end
  end

  @doc """
  Converts a string from snake_case to camelCase.
  """
  def to_camel_case(string) when is_binary(string) do
    case String.split(string, "_") do
      [first | rest] ->
        first <> Enum.map_join(rest, &String.capitalize/1)
      [] ->
        string
    end
  end
end
