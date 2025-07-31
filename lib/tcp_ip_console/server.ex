defmodule TcpIpConsole.Server do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    {:ok, listen_socket} =
      :gen_tcp.listen(port, [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true
      ])

    Logger.info("Accepting connections on port #{port}")

    Task.start_link(fn -> accept_loop(listen_socket) end)

    {:ok, %{listen: listen_socket}}
  end

  defp accept_loop(listen_socket) do
    Logger.info("Accept loop!!!")
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    Logger.info("Client #{inspect(:inet.peername(socket))} connected.")

    serve_client(socket)

    accept_loop(listen_socket)
  end

  defp serve_client(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, line} ->
        resp = handle_line(line)
        :gen_tcp.send(socket, resp)
        serve_client(socket)

      {:error, :closed} ->
        Logger.info("Client disconnected")
        :gen_tcp.close(socket)
    end
  end

  defp handle_line(line) do
    line
    |> String.trim_trailing("\n")
    |> String.trim_trailing("\r")
    |> String.split()
    |> handle_command()
    |> then(fn text -> text <> "\n" end)
  end

  defp handle_command([]), do: "ERROR empty command"
  defp handle_command(["TIME"]), do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp handle_command(_unknown), do: "ERROR unknown command"
end
