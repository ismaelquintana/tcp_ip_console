defmodule TcpIpConsole.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4040")

    children = [
      {TcpIpConsole.Server, port: port}
    ]

    opts = [strategy: :one_for_one, name: TcpIpConsole.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
