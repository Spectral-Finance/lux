defmodule Lux.Integrations.SushiSwap do
  @moduledoc """
  Integration with S<<8011 characters removed to optimize context, read with space.chat.readLongMessage({id: 196, from: 0, to:10000})>>ring.split("/")
      {String.to_integer(p), String.to_integer(d)}
    end
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end