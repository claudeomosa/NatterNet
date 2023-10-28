# NatterNet
## Elixir TCP chat app with a simple Java client

This project implements a chat server in Elixir, consisting of a broadcast server (`Chat.BroadcastServer`) and a proxy server (`Chat.ProxyServer`) to handle client connections via `TCP`. The project also includes a simple Java client for connecting to the Elixir servers.

## Demo
[Screencast from 28-10-23 09:29:00.webm](https://github.com/claudeomosa/NatterNet/assets/56362108/5fe56219-4efd-4205-b944-8e96f44a6797)



## Elixir Server


### Chat.BroadcastServer
- This module manages client nicknames.
- Uses ETS tables for state management.
- Supports commands: 
	* `/LIST`
	*  `/NICK <nickname>`
	*  `/BC <message>`
	*  `/MSG <nickname> <message>`.
- Ensures valid nicknames (alphanumeric, underscores, max 12 characters).
- Clients need to set a nickname to interact.

### Chat.ProxyServer
- Accepts external client connections via TCP (`:gen_tcp`).
- Creates proxy processes to interact with the broadcast server.
- Parses and validates client commands.
- Reduces the broadcast server's workload.
- Sends messages and error responses to external clients.

## Running the Elixir Servers

1. Clone the repository:

```bash
git clone git@github.com:claudeomosa/NatterNet.git
cd chat
cd server
```
2. Start the server:

```elixir
iex -S mix
```
The application is structured with a supervision strategy, so when you run the above command, it defaults to starting the server on port `6666` for incoming client connections.
To start on a different port run the following and provide a port number:
```elixir
PORT=7777 iex -S mix
```

## Usage with netcat or telnet
Run the following command to connect to the server, use the port you provided or `6666` if you used the default:
```bash
nc localhost 6666
```
or with telnet
```bash
telnet localhost 6666
```

## Java Client

- Connects to the server for user interaction.
- Accepts hostname and port as command-line arguments (defaults: "localhost", 6666).
- Sends user commands and displays replies.
- Terminates when the user enters an end-of-file key.

To compile and run the Java client, open a new terminal and run the following command on the root directory:

```bash
javac client/Main.java
java client.Main [hostname] [port]
```

## Usage with Java client

1. Connect a Java client to the Elixir server.
2. Use commands 
	* `/LIST`
	* `/NICK <nickname>`
	* `/BC <message>`
	* `/MSG <nickname> <message>`.
3. Follow the valid nickname format for setting a nickname.

## Notes

- Ensure that Elixir and Java are installed on your system.
- The Elixir servers will print "debugging" information for testing and debugging purposes.
- The Elixir broadcast server uses `ETS` tables for state management, ensuring recovery from brief crashes.

Feel free to explore and modify the code to suit your requirements.

---
