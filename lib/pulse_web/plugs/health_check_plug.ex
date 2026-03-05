defmodule PulseWeb.HealthCheckPlug do
  @moduledoc """
  Responds to /up with 200 OK for Kamal proxy health checks.

  Placed early in the endpoint pipeline so it runs before force_ssl
  and other plugs that might redirect or block the request.
  """
  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(%{path_info: ["up"]} = conn, _opts) do
    conn |> send_resp(200, "ok") |> halt()
  end

  def call(conn, _opts), do: conn
end
