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

  def accept(port \\ 6666) do
    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, active: false, packet: :line, reuseaddr: true])
    Logger.info("Listening on port #{port}")
    {:ok, pid} = BroadcastServer.start_link([])
    acceptor_loop(listen_socket)
  end


  def acceptor_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    :gen_tcp.send(client, "Welcome to the chat server!\nPlease set your nickname using the /NICK command.\n")
    {:ok, pid} = Task.Supervisor.start_child(Chat.TaskSupervisor, fn -> serve(client, nil) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    acceptor_loop(socket)
  end

  defp serve(socket, nickname) do
    socket
    |> read_line(nickname)
    serve(socket, nickname)
  end


  defp read_line(socket, nickname) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, line} ->
        Logger.info("Received: #{line}")
        if is_nil(nickname) do
          handle_nick(socket, line)
        else
          parse_command(socket, line, nickname)
        end
      {:error, :closed} ->
        Logger.info("Client disconnected")
      {:error, reason} ->
        Logger.error("Error: #{reason}")
    end
  end


  defp parse_command(socket, line, nickname) do
    [command | args] = String.split(line, " ", trim: true)
    case command do
      "/LIST" -> handle_list(socket)
      "/BC" -> handle_broadcast(socket, args)
      "/MSG" -> handle_message(socket, hd(args), tl(args))
      "/NICK" -> handle_reset_nick(socket, hd(args), nickname)
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

  defp handle_nick(socket, line) do
    [command, new_nickname] = String.split(line, " ", trim: true)
    if command == "/NICK" and new_nickname != "" do
      new_nickname = String.trim(new_nickname)
      case BroadcastServer.get_all_nicknames() do
        nicknames ->
          case Enum.member?(nicknames, new_nickname) do
            true ->
              send_response(socket, "Nickname '#{new_nickname}' already taken. Please choose another nickname.")
              :ok
            false ->
              case BroadcastServer.set_nickname(new_nickname, self()) do
                {:ok, nickname} ->
                  send_response(socket, "Nickname set to '#{nickname}'")
                  serve(socket, nickname)
                {:error, reason} ->
                  send_response(socket, "Error: #{reason}")
              end
          end
      end
    else
      send_response(socket, "Please set your nickname using the /NICK command.")
      :ok
    end
  end

  def handle_reset_nick(socket, new_nickname, old_nickname) do
    new_nickname = String.trim(new_nickname)
    case BroadcastServer.get_all_nicknames() do
      nicknames ->
        case Enum.member?(nicknames, new_nickname) do
          true ->
            send_response(socket, "Nickname '#{new_nickname}' already taken. Please choose another nickname.")
            :ok
          false ->
            case BroadcastServer.set_nickname(new_nickname, self()) do
              {:ok, nickname} ->
                send_response(socket, "Nickname Changed to '#{nickname}'")
                BroadcastServer.remove_nickname(old_nickname)
                serve(socket, nickname)
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
