defmodule PulseWeb.Plugs.SetLocale do
  @moduledoc """
  Plug that sets the Gettext locale from cookie or Accept-Language header.
  """
  import Plug.Conn

  @supported_locales ~w(en es)
  @default_locale "en"
  @cookie_key "pulse-lang"

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      get_locale_from_cookie(conn) ||
        get_locale_from_header(conn) ||
        @default_locale

    Gettext.put_locale(PulseWeb.Gettext, locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end

  defp get_locale_from_cookie(conn) do
    conn
    |> fetch_cookies()
    |> Map.get(:cookies, %{})
    |> Map.get(@cookie_key)
    |> validate_locale()
  end

  defp get_locale_from_header(conn) do
    conn
    |> get_req_header("accept-language")
    |> List.first()
    |> parse_accept_language()
  end

  defp parse_accept_language(nil), do: nil

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn part ->
      part |> String.split(";") |> List.first() |> String.split("-") |> List.first()
    end)
    |> Enum.find_value(&validate_locale/1)
  end

  defp validate_locale(nil), do: nil

  defp validate_locale(locale) do
    lang = locale |> String.downcase() |> String.trim()
    if lang in @supported_locales, do: lang, else: nil
  end
end
