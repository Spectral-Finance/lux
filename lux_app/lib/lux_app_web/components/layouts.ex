defmodule LuxAppWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use LuxAppWeb, :controller` and
  `use LuxAppWeb, :live_view`.
  """
  use LuxAppWeb, :html

  embed_templates "layouts/*"
end
