defmodule Lux.Repo do
  use Ecto.Repo,
    otp_app: :lux,
    adapter: Ecto.Adapters.Postgres
end
