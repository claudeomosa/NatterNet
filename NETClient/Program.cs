using System;
using System.IO;
using System.Net.Sockets;
using System.Threading;

namespace NETClient
{
    class Program
    {
        static void Main(string[] args)
        {
            string host = "localhost";
            int port = 6666;

            if (args.Length >= 2)
            {
                host = args[0];
                port = int.Parse(args[1]);
            }
            else if (args.Length == 1)
            {
                host = args[0];
            }

            try
            {
                using (TcpClient client = new TcpClient(host, port))
                using (NetworkStream stream = client.GetStream())
                using (StreamReader reader = new StreamReader(stream))
                using (StreamWriter writer = new StreamWriter(stream))
                {
                    writer.AutoFlush = true;
                    Console.WriteLine("Connected to the Elixir chat server");

                    // a thread to listen to server responses
                    Thread responseThread = new Thread(() =>
                    {
                        try
                        {
                            while (true)
                            {
                                string response = reader.ReadLine();
                                if (response != null)
                                {
                                    Console.WriteLine("=> " + response);
                                }
                                else
                                {
                                    throw new Exception("Server has closed the connection");
                                }
                            }
                        }
                        catch (Exception e)
                        {
                            Console.WriteLine("Error: " + e.Message);
                        }
                    });

                    responseThread.Start();

                    // read commands from the user and send them to the server
                    while (true)
                    {
                        string userInput = Console.ReadLine();
                        if (string.IsNullOrEmpty(userInput))
                        {
                            break;
                        }

                        writer.WriteLine(userInput);
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"Failed to connect: {e.Message}");
            }
        }
    }
}
