defmodule PulseWeb.LogoController do
  use PulseWeb, :controller

  @cache_table :logo_cache
  @cache_ttl_ms :timer.hours(24)

  def show(conn, %{"symbol" => symbol}) do
    symbol = String.upcase(symbol)

    case fetch_logo(symbol) do
      {:ok, body, content_type} ->
        conn
        |> put_resp_content_type(content_type, nil)
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> send_resp(200, body)

      :error ->
        send_resp(conn, 404, "")
    end
  end

  defp fetch_logo(symbol) do
    ensure_cache_table()

    case lookup_cache(symbol) do
      {:ok, _body, _content_type} = hit -> hit
      :miss -> fetch_and_cache(symbol)
    end
  end

  defp ensure_cache_table do
    case :ets.whereis(@cache_table) do
      :undefined ->
        :ets.new(@cache_table, [:set, :public, :named_table])

      _ref ->
        :ok
    end
  end

  defp lookup_cache(symbol) do
    case :ets.lookup(@cache_table, symbol) do
      [{^symbol, body, content_type, inserted_at}] ->
        if System.monotonic_time(:millisecond) - inserted_at < @cache_ttl_ms do
          {:ok, body, content_type}
        else
          :ets.delete(@cache_table, symbol)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp fetch_and_cache(symbol) do
    service_url = Application.get_env(:pulse, :logo_service_url, "")
    api_key = Application.get_env(:pulse, :logo_service_api_key, "")

    url =
      "#{service_url}/api/v1/logos/#{symbol}?size=m&api_key=#{api_key}"
      |> String.to_charlist()

    case :httpc.request(:get, {url, []}, [timeout: 5_000, connect_timeout: 3_000], []) do
      {:ok, {{_http, 200, _status}, headers, body}} ->
        content_type =
          headers
          |> Enum.find_value("image/png", fn
            {~c"content-type", value} -> List.to_string(value)
            _ -> nil
          end)

        body = IO.iodata_to_binary(body)

        :ets.insert(
          @cache_table,
          {symbol, body, content_type, System.monotonic_time(:millisecond)}
        )

        {:ok, body, content_type}

      _ ->
        :error
    end
  end
end
