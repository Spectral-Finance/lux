defmodule Lux.Integrations.MultiChain.Cache do
  @moduledoc "Simple in-memory cache."
  defstruct data:%{},ttl:30
  @spec new() :: %__MODULE__{}
  def new(ttl=30), do: %__MODULE__{ttl:ttl}
  @spec get(%__MODULE__{},String.t()) :: any()|nil
  def get(c,key), do: c.data[key]|>then(&(&1&&if DateTime.compare(DateTime.utc_now(),&1.expires_at)==:lt,do:&1.value,else:nil))
  @spec put(%__MODULE__{},String.t(),any()) :: %__MODULE__{}
  def put(c,key,val), do: %__MODULE__{c|data:Map.put(c.data,key,%{value:val,expires_at:DateTime.utc_now()|>DateTime.add(c.ttl,:second)})}
end