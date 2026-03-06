defmodule PulseWeb.PageControllerTest do
  use PulseWeb.ConnCase

  test "GET / renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Pulse"
    assert html_response(conn, 200) =~ "Real-time community dividend portfolio dashboard"
  end

  test "GET /p/:slug renders not found for missing portfolio", %{conn: conn} do
    conn = get(conn, ~p"/p/nonexistent")
    assert html_response(conn, 200) =~ "Portfolio not found"
  end
end
