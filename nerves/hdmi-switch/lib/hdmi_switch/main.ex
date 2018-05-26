defmodule HdmiSwitch.Main do
  use GenServer, start: {__MODULE__, :start_link, []}, restart: :transient

  alias HdmiSwitch.MqttClient

  def start_link do
    IO.puts "Main Starting..."
    GenServer.start_link(__MODULE__, %{}, [])
  end

  def init(%{}) do
    IO.puts "Inside init"
    {:ok, mqtt_client} = MqttClient.start_link(%{parent: self()})
    {:ok, uart} = Nerves.UART.start_link

    Process.send_after(self(), :connect, 200)
    IO.puts "Finished init"

    {:ok, %{mqtt_client: mqtt_client, uart: uart}}
  end

  def on_connect(pid) do
    IO.puts "On connect"
    Kernel.send(pid, :connected)
  end

  def on_receive_message(pid, channel, message) do
    Kernel.send(pid, %{channel: channel, message: message})
  end

  def handle_info(:connect, state) do
    IO.puts "About to connect MQTT"
    :ok = MqttClient.connect(state.mqtt_client, client_id: "hdmi-switch", host: "192.168.1.8", port: 1883)
    IO.puts "About to connect UART"
    :ok = Nerves.UART.open(state.uart, "ttyUSB0", speed: 19200, active: false, framing: {Nerves.UART.Framing.Line, separator: "\r\n"})
    IO.puts "Connected"

    {:noreply, state}
  end

  def handle_info(:connected, state) do
    MqttClient.subscribe(state.mqtt_client, topics: ["home/hdmiSwitch/setInput"], qoses: [1])
    {:noreply, state}
  end

  def handle_info(%{channel: "home/hdmiSwitch/setInput", message: message}, state) do
    :ok = Nerves.UART.write(state.uart, "swi0#{message}")
    {:ok, _reply} = Nerves.UART.read(state.uart)
    :ok = MqttClient.publish(state.mqtt_client, topic: "home/hdmiSwitch/input", dup: 0, message: message, qos: 1, retain: 1)
    {:noreply, state}
  end

  def handle_info(data, state) do
    IO.inspect(data.channel)
    IO.inspect(data.message)
    {:noreply, state}
  end
end
