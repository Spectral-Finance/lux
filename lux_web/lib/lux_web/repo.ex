defmodule LuxWeb.Repo do
  use Ecto.Repo,
    otp_app: :lux_web,
    adapter: Ecto.Adapters.Postgres
end
