defmodule Chat.ProxyServer do
  require Logger
  alias Chat.BroadcastServer
  @moduledoc """
    This module has Logic to start the TCP server and handle client connections
    It Spawns proxy processes for each connected client by default on port 6666
    It is responsible for Validating and parssing client commands, and communicate with the broadcast server (Chat.BroadcastServer)
  """
  defmodule State do
    defstruct [:port, :listen_socket]
  end

  def start_link(opts) do
    spawn_link(__MODULE__, :init, [opts])
  end

  def init(opts) do
    port = Keyword.get(opts, :port, 6666)
    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, active: false, packet: :line, reuseaddr: true])
    Logger.info("Listening on port #{port}")
    {:ok, chat_pid} = BroadcastServer.start_link([])
    acceptor_loop(listen_socket)
  end

  def acceptor_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    :gen_tcp.send(client, "Welcome to the chat server!\n")
    # from next line, accept a command "/NICK <nickname>" this sets a nickname for the client, and users Chat.BroadcastServer.set_nickname/2 to set the nickname
    # a loop to listen to the client's commands and parse them
    # first line after welcome to the chat server should be "/NICK <nickname>", else should request user to select nickname first
    # if the command is "/NICK <nickname>", it should set the nickname for the client and send a message to the client "Nickname set to <nickname>"

    serve(client)

    acceptor_loop(socket)
  end

  defp serve(socket) do
    socket
    |> read_line()

    serve(socket)
  end

  defp read_line(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, line} ->
        Logger.info("Received: #{line}")
        parse_command(socket, line)
      {:error, :closed} ->
        Logger.info("Client disconnected")
      {:error, reason} ->
        Logger.error("Error: #{reason}")
    end
  end

  defp parse_command(socket, line) do
    [command | args] = String.split(line, " ", trim: true)
    case command do
      "/LIST" -> handle_list(socket)
      "/NICK" -> handle_nick(socket, hd(args))
      "/BC" -> handle_broadcast(socket, args)
      "/MSG" -> handle_message(socket, hd(args), tl(args))
      _ -> send_error(socket, "Invalid command: #{command}")
    end
  end

  defp handle_list(socket) do
    Logger.info("Listing all nicknames")
    send_response(socket, "Online users: #{
      Chat.BroadcastServer.get_all_nicknames()
      |> Enum.join(", ")

      }")
  end

  # defp handle_nick(socket, nickname) do
  #   nickname = String.trim(nickname)
  #   case BroadcastServer.set_nickname(nickname, self()) do
  #     :ok -> send_response(socket, "Nickname set to '#{nickname}'")
  #     {:error, reason} -> send_response(socket, "Error: #{reason}")
  #   end
  # end

  defp handle_nick(socket, nickname) do
    nickname = String.trim(nickname)
    case Chat.BroadcastServer.get_all_nicknames() do
      nicknames ->
        case Enum.member?(nicknames, nickname) do
          true ->
            send_response(socket, "Nickname '#{nickname}' already taken")
          false ->
            case Chat.BroadcastServer.set_nickname(nickname, self()) do
              {:ok, nickname} ->
                send_response(socket, "Nickname set to '#{nickname}'")
              {:error, reason} ->
                send_response(socket, "Error: #{reason}")
            end
        end
    end
  end


  defp handle_broadcast(socket, message) do
    Logger.info("Broadcasting: #{message}")
    BroadcastServer.broadcast(message)
    send_response(socket, "Broadcast: #{message}")
  end

  defp handle_message(socket, nickname, message) do
    Logger.info("Sending message to #{nickname}: #{message}")
    BroadcastServer.send_message(nickname, message)
    send_response(socket, "Message sent to #{nickname}: #{message}")
  end

  defp send_error(socket, message) do
    :gen_tcp.send(socket, "Error: #{message}\n")
  end

  defp send_response(socket, response) do
    :gen_tcp.send(socket, response <> "\n")
  end



end
