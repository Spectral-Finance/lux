defmodule LuxApp.Repo do
  use Ecto.Repo,
    otp_app: :lux_app,
    adapter: Ecto.Adapters.Postgres
end
