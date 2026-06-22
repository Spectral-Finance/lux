defmodule Lux.Integrations.EventMonitor.Subscriber do
  @moduledoc "Subscription ID generation."
  @spec generate_id() :: String.t()
  def generate_id, do: "sub_#{:crypto.strong_rand_bytes(16)|>Base.hex_encode32(padding:false)}"
end