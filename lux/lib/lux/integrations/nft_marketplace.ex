defmodule Lux.Integrations.NFTMarketplace do
  @moduledoc """
  Integration with NFT marketplace data aggregation, supporting major platf<<8281 characters removed to optimize context, read with space.chat.readLongMessage({id: 198, from: 0, to:10000})>>rror -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp parse_integer(val) when is_integer(val), do: val
  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> 0
    end
  end
  defp parse_integer(_), do: 0
end