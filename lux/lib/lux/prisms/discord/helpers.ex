defmodule Lux.Prisms.Discord.Helpers do
  @moduledoc false

  def validate_string(params, key, default \\ nil) do
    case get_param(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      nil when default != nil -> {:ok, default}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  def validate_number(params, key, default \\ nil) do
    case get_param(params, key) do
      value when is_number(value) -> {:ok, value}
      value when is_binary(value) ->
        case Float.parse(value) do
          {num, ""} -> {:ok, num}
          _ -> {:error, "Missing or invalid #{key}"}
        end
      nil when default != nil -> {:ok, default}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  def validate_integer(params, key, opts \\ []) do
    min = Keyword.get(opts, :min, nil)
    max = Keyword.get(opts, :max, nil)

    case get_param(params, key) do
      value when is_integer(value) ->
        cond do
          min != nil and value < min -> {:error, "#{key} must be >= #{min}"}
          max != nil and value > max -> {:error, "#{key} must be <= #{max}"}
          true -> {:ok, value}
        end
      nil when Keyword.has_key?(opts, :default) ->
        {:ok, Keyword.get(opts, :default)}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  def validate_boolean(params, key, default \\ false) do
    case get_param(params, key) do
      value when is_boolean(value) -> {:ok, value}
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      nil when default != nil -> {:ok, default}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  def validate_list(params, key, default \\ []) do
    case get_param(params, key) do
      value when is_list(value) -> {:ok, value}
      nil when default != nil -> {:ok, default}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  def validate_string_list(params, key, opts \\ []) do
    min = Keyword.get(opts, :min, 1)
    max = Keyword.get(opts, :max, :infinity)

    case get_param(params, key) do
      values when is_list(values) ->
        valid_size? =
          length(values) >= min and
            (max == :infinity or length(values) <= max)

        if valid_size? and Enum.all?(values, &(is_binary(&1) and &1 != "")) do
          {:ok, values}
        else
          {:error, "Missing or invalid #{key}"}
        end

      _ ->
        {:error, "Missing or invalid #{key}"}
    end
  end

  def optional(params, key, default \\ nil), do: {:ok, get_param(params, key, default)}

  def non_empty_payload(payload) do
    if map_size(payload) > 0, do: {:ok, payload}, else: {:error, "At least one update field is required"}
  end

  def take_optional(params, keys) do
    Enum.reduce(keys, %{}, fn key, acc ->
      case get_param(params, key) do
        nil -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  def client_opts(params, opts \\ %{}) do
    params
    |> take_optional([:plug, :max_retries, :retry_sleep, :retry_base_delay_ms])
    |> Map.merge(opts)
    |> maybe_add_audit_reason(params)
  end

  defp maybe_add_audit_reason(opts, params) do
    case get_param(params, :reason) do
      reason when is_binary(reason) and reason != "" ->
        headers = Map.get(opts, :headers, [])
        Map.put(opts, :headers, [{"X-Audit-Log-Reason", URI.encode_www_form(reason)} | headers])

      _ ->
        opts
    end
  end

  defp get_param(params, key, default \\ nil) do
    Map.get(params, key, Map.get(params, Atom.to_string(key), default))
  end
end