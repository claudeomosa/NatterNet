package client;

import java.io.*;
import java.net.Socket;
import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        String host = "localhost";
        int port = 6666;

        if (args.length >= 2) {
            host = args[0];
            port = Integer.parseInt(args[1]);
        } else if (args.length == 1) {
            host = args[0];
        }

        try (Socket socket = new Socket(host, port);
             BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
             BufferedWriter out = new BufferedWriter(new OutputStreamWriter(socket.getOutputStream()));
             Scanner userInput = new Scanner(System.in)) {

            System.out.println("Connected to the Elixir chat server");

            while (true) {
                String response = in.readLine();
                if (response != null) {
                    System.out.println("Server Response: " + response);
                }

                String userCommand = userInput.nextLine();
                if (userCommand == null) {
                    break;
                }

                out.write(userCommand);
                out.newLine();
                out.flush();
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
