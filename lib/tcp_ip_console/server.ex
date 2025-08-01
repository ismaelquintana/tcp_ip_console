defmodule TcpIpConsole.Server do
  @moduledoc false
  use GenServer
  require Logger

  @menu """
  === TCP-CLI menu =========================================
  TIME        -> UTC ISO-8601 timestamp
  UPTIME      -> seconds since boot
  GET         -> get data in list
  ECHO text…  -> repeats the text
  HELP        -> show this menu again
  CLEAR/CLS   -> clear screen
  QUIT        -> close connection
  ==========================================================
  """

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

  @impl true
  def handle_cast({:push, element}, state) do
    case Map.get(state, :comandos) do
      nil -> Map.put(state, :comandos, [element])
      values -> Map.put(state, :comandos, [element | values])
    end

    # new_state = [element | state]
    {:noreply, state}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def push(element) do
    GenServer.cast(__MODULE__, {:push, element})
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  defp accept_loop(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    Logger.info("Client #{inspect(:inet.peername(socket))} connected.")

    :gen_tcp.send(socket, banner())
    serve_client(socket)

    accept_loop(listen_socket)
  end

  defp serve_client(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, line} ->
        resp = line |> sanitize() |> handle_command()
        :gen_tcp.send(socket, resp <> "\n")
        if resp == "BYE", do: :gen_tcp.close(socket), else: serve_client(socket)

      {:error, :closed} ->
        Logger.info("Client disconnected")
        :gen_tcp.close(socket)
    end
  end

  defp sanitize(line), do: line |> String.trim() |> String.upcase()

  defp handle_command(""), do: @menu
  defp handle_command("HELP"), do: @menu
  defp handle_command("QUIT"), do: "BYE"
  defp handle_command("EXIT"), do: "BYE"
  defp handle_command(command) when command in ["CLEAR", "CLS"], do: "\e[2J\e[H" <> @menu
  defp handle_command("TIME"), do: DateTime.utc_now() |> DateTime.to_iso8601()
  # defp handle_command("UPTIME"), do: "up #{System.system_time(:second) - boot_time()} s"
  defp handle_command("UPTIME"), do: "up #{boot_time()} "
  defp handle_command("PUSH " <> elemento), do: push(elemento)
  defp handle_command("GET"), do: "datos: #{inspect(get())} "
  defp handle_command("PID"), do: "pid: #{inspect(Kernel.self())}"
  defp handle_command("ECHO " <> rest), do: String.trim(rest)
  defp handle_command("ECHO"), do: "(nothing to echo)"
  defp handle_command(_unknown), do: "ERROR unknown command"

  defp banner, do: "\nWelcome to TCP-CLI\n" <> @menu

  defp boot_time do
    {boot_ms, _} = :erlang.statistics(:wall_clock)

    # seconds
    seconds = System.system_time(:second) - div(boot_ms, 1000)
    # minutes
    div(seconds, 60)
  end
end
