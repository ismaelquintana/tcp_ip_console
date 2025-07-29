defmodule TcpIpConsoleTest do
  use ExUnit.Case
  doctest TcpIpConsole

  test "greets the world" do
    assert TcpIpConsole.hello() == :world
  end
end
