defmodule PulseWeb.Live.Hooks.SetLocale do
  @moduledoc """
  LiveView on_mount hook that sets the Gettext locale from connect params.
  """
  import Phoenix.Component, only: [assign: 3]

  @supported_locales ~w(en es)
  @default_locale "en"

  def on_mount(:default, _params, session, socket) do
    locale =
      get_locale_from_params(socket) ||
        Map.get(session, "locale") ||
        @default_locale

    locale = if locale in @supported_locales, do: locale, else: @default_locale

    Gettext.put_locale(PulseWeb.Gettext, locale)

    {:cont, assign(socket, :locale, locale)}
  end

  defp get_locale_from_params(socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.LiveView.get_connect_params(socket)["locale"]
    end
  end
end
