defmodule PulseWeb.PageControllerTest do
  use PulseWeb.ConnCase

  test "GET / renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Pulse"
    assert html_response(conn, 200) =~ "Community dividend portfolio dashboard"
  end
end
