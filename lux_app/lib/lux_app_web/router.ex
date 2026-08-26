defmodule LuxAppWeb.Router do
  use LuxAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LuxAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  pipeline :auth_required do
    plug LuxAppWeb.Plugs.RequireAuth
  end

  pipeline :admin_required do
    plug LuxAppWeb.Plugs.RequireAuth, role: "admin"
  end

  scope "/", LuxAppWeb do
    pipe_through :browser

    live "/", NodeEditorLive
  end

  scope "/api", LuxAppWeb do
    pipe_through :api

    scope "/auth" do
      get "/nonce", AuthController, :nonce
      post "/verify", AuthController, :verify
      post "/logout", AuthController, :logout
    end

    # Authenticated User API routes
    scope "/secure" do
      pipe_through [:auth_required]
      
      get "/profile", ProfileController, :show
    end

    # Authenticated Admin API routes (RBAC Enforcement)
    scope "/admin" do
      pipe_through [:admin_required]

      get "/dashboard", AdminController, :index
    end
  end

  if Application.compile_env(:lux_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LuxAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
