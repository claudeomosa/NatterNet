defmodule Chat.ProxyServer do
  require Logger
  alias Chat.{BroadcastServer, ClientsStateAgent, TaskSupervisor}

  @moduledoc """
    This module has Logic to start the TCP server and handle client connections.
    It spawns proxy processes for each connected client by default on port 6666.
    It is responsible for validating and parsing client commands and communicating with the broadcast server (Chat.BroadcastServer).
  """

  defmodule State do
    defstruct [:port, :listen_socket, :clients, :nickname, :message_history]
  end

  def accept(port \\ 6666) do
    {:ok, listen_socket} = :gen_tcp.listen(port, [:binary, active: false, packet: :line, reuseaddr: true])
    Logger.info("Listening on port #{port}")
    {:ok, _pid} = BroadcastServer.start_link([])

    all_client_pids = []

    initial_state = %State{port: port, listen_socket: listen_socket, clients: %{}, nickname: nil, message_history: []}
    acceptor_loop(initial_state, all_client_pids)
  end

  def acceptor_loop(state, all_client_pids) do
    {:ok, client_socket} = :gen_tcp.accept(state.listen_socket)
    :gen_tcp.send(client_socket, "Welcome to the chat server!\nPlease set your nickname using the /NICK command.\n")
    {:ok, client_pid} = Task.Supervisor.start_child(TaskSupervisor, fn -> serve(client_socket, state, all_client_pids) end)
    ClientsStateAgent.add_client(client_pid, client_socket) # Add the client to the Agent
    :ok = :gen_tcp.controlling_process(client_socket, client_pid)

    send_message_history(client_socket, state.message_history)

    updated_state = %{state | message_history: state.message_history}
    acceptor_loop(updated_state, all_client_pids)
  end

  defp serve(socket, state, all_client_pids) do
    socket |> read_line(state, all_client_pids)
    serve(socket, state, all_client_pids)
  end

  defp read_line(socket, state, all_client_pids) do
    clients = state.clients
    case :gen_tcp.recv(socket, 0) do
      {:ok, line} ->
        Logger.info("Received: #{line}")
        if is_nil(state.nickname) do
          handle_nick(socket, line, state, all_client_pids)
        else
          parse_command(socket, line, state, all_client_pids)
        end
        {:error, :closed} ->
          Logger.info("Client disconnected")
          ClientsStateAgent.remove_client(self()) # Remove the client from the agent
          BroadcastServer.remove_nickname(state.nickname)
          {:ok, _} = :gen_tcp.close(socket)
          serve(socket, %{state | clients: Map.delete(clients, self())}, all_client_pids)
      {:error, reason} ->
        Logger.error("Error: #{reason}")
    end
  end

  defp parse_command(socket, line, state, all_client_pids) do
    [command | args] = String.split(line, " ", trim: true)
    case command do
      "/LIST" -> handle_list(socket, state)
      "/BC" -> handle_broadcast(socket, args, state, all_client_pids)
      "/MSG" -> handle_message(socket, hd(args), tl(args), state)
      "/NICK" -> handle_reset_nick(socket, hd(args), state, all_client_pids)
      _ -> send_error(socket, "Invalid command: #{command}")
    end
  end

  defp handle_list(socket, state) do
    send_response(socket, "Online users: #{
      BroadcastServer.get_all_nicknames() |> Enum.join(", ")
    }")
  end

  defp handle_nick(socket, line, state, _pids) do
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
                  updated_state = %{state | nickname: nickname}
                  new_clients = Map.put(state.clients, self(), socket)
                  updated_state = %{updated_state | clients: new_clients}
                  send_message_history(socket, updated_state.message_history)
                  serve(socket, updated_state, [])
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

  defp handle_reset_nick(socket, new_nickname, state, all_client_pids) do
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
                BroadcastServer.remove_nickname(state.nickname)
                updated_state = %{state | nickname: nickname}
                serve(socket, updated_state, all_client_pids)
              {:error, reason} ->
                send_response(socket, "Error: #{reason}")
            end
        end
    end
  end

  defp handle_broadcast(socket, message, state, _all_client_pids) do
    Logger.info("Broadcasting: #{message}")
    new_message_history = state.message_history ++ ["Broadcast from #{state.nickname}: #{message}"]
    BroadcastServer.broadcast(message)
    Enum.each(ClientsStateAgent.get_clients, fn {_client_pid, client_socket} ->
      send_response(client_socket, "Broadcast from socket #{state.nickname}: #{message}")
    end)
    updated_state = %{state | message_history: new_message_history}
    serve(socket, updated_state, [])
  end

  defp handle_message(socket, recipient_nickname, message, state) do
    Logger.info("Sending message to #{recipient_nickname}: #{message}")
    case BroadcastServer.get_pid_with_nickname(recipient_nickname) do
      [{_nickname, pid}] ->
        send_response(socket, "Message sent to #{recipient_nickname}: #{message}")
        send_response(
          ClientsStateAgent.get_client(pid),
          "Private Message from #{state.nickname}: #{message}"
        )
        updated_state = %{state | message_history: state.message_history ++ ["Message from #{state.nickname} to #{recipient_nickname}: #{message}"]}
        serve(socket, updated_state, [])
      _ ->
        send_response(socket, "Nickname #{recipient_nickname} not found")
        serve(socket, state, [])
    end
  end

  defp send_error(socket, message) do
    :gen_tcp.send(socket, "Error: #{message}\n")
  end

  defp send_response(socket, response) do
    :gen_tcp.send(socket, response <> "\n")
  end

  defp send_message_history(socket, message_history) do
    Enum.each(message_history, fn message ->
      send_response(socket, message)
    end)
  end
end
