defmodule PulseWeb.Components.StockLogo do
  use Phoenix.Component

  attr :symbol, :string, required: true
  attr :size, :integer, default: 56

  def stock_logo(assigns) do
    service_url = Application.get_env(:pulse, :logo_service_url, "")
    api_key = Application.get_env(:pulse, :logo_service_api_key, "")

    assigns =
      assign(assigns,
        logo_url: logo_url(assigns.symbol, service_url, api_key),
        has_service: service_url != "" and api_key != ""
      )

    ~H"""
    <div
      class="rounded-xl overflow-hidden flex-shrink-0 bg-base-300"
      style={"width: #{@size}px; height: #{@size}px"}
    >
      <img
        :if={@has_service}
        src={@logo_url}
        alt={@symbol}
        class="w-full h-full object-contain"
        onerror="this.style.display='none';this.nextElementSibling.style.display='flex'"
      />
      <div
        class="w-full h-full items-center justify-center text-base-content/60 font-bold text-sm"
        style={if @has_service, do: "display:none", else: "display:flex"}
      >
        {String.slice(@symbol, 0, 2)}
      </div>
    </div>
    """
  end

  defp logo_url(symbol, service_url, api_key) do
    "#{service_url}/api/v1/logos/#{String.upcase(symbol)}?size=m&api_key=#{api_key}"
  end
end
