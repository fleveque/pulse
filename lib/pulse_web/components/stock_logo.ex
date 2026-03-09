defmodule PulseWeb.Components.StockLogo do
  use Phoenix.Component

  attr :symbol, :string, required: true
  attr :size, :integer, default: 56

  def stock_logo(assigns) do
    assigns = assign(assigns, :logo_url, "/logos/#{String.upcase(assigns.symbol)}")

    ~H"""
    <div
      class="rounded-xl overflow-hidden flex-shrink-0 bg-base-300"
      style={"width: #{@size}px; height: #{@size}px"}
    >
      <img
        src={@logo_url}
        alt={@symbol}
        class="w-full h-full object-contain"
        onerror="this.style.display='none';this.nextElementSibling.style.display='flex'"
      />
      <div
        class="w-full h-full items-center justify-center text-base-content/60 font-bold text-sm"
        style="display:none"
      >
        {String.slice(@symbol, 0, 2)}
      </div>
    </div>
    """
  end
end
