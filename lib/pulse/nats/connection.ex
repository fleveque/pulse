defmodule Pulse.Nats.Connection do
  @moduledoc """
  Manages the NATS connection using Gnat.

  Starts a supervised connection to the NATS server and makes it
  available via a registered name for other processes to use.
  """
  require Logger

  def child_spec(_opts) do
    connection_settings = Application.get_env(:pulse, :nats, [])

    %{
      id: __MODULE__,
      start:
        {Gnat.ConnectionSupervisor, :start_link,
         [
           %{
             name: :nats,
             connection_settings: [
               %{
                 host: Keyword.get(connection_settings, :host, "localhost"),
                 port: Keyword.get(connection_settings, :port, 4222)
               }
             ]
           }
         ]},
      type: :supervisor
    }
  end
end
