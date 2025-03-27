defmodule RateLimiter do
  @moduledoc false
  use Hammer, backend: :ets
end
