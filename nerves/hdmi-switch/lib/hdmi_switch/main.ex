defmodule HdmiSwitch.Main do
  use GenServer, start: {__MODULE__, :start_link, []}, restart: :transient

  alias HdmiSwitch.MqttClient

  def start_link do
    IO.puts("Main Starting...")
    GenServer.start_link(__MODULE__, %{}, [])
  end

  def init(%{}) do
    IO.puts("Inside init")
    {:ok, mqtt_client} = MqttClient.start_link(%{parent: self()})
    {:ok, uart} = Nerves.UART.start_link()

    Process.send_after(self(), :connect, 2000)
    IO.puts("Finished init")

    {:ok, %{mqtt_client: mqtt_client, uart: uart, input: 0}}
  end

  def on_connect(pid) do
    IO.puts("On connect")
    Kernel.send(pid, :connected)
  end

  def poll_switch do
    Process.send_after(self(), :poll_switch, 2000)
  end

  def on_receive_message(pid, topic, message) do
    Kernel.send(pid, %{topic: topic, message: message})
  end

  def handle_info(:connect, state) do
    IO.puts("About to connect MQTT")

    :ok =
      MqttClient.connect(
        state.mqtt_client,
        client_id: "hdmi-switch",
        host: "192.168.1.8",
        port: 1883
      )

    :ok =
      MqttClient.publish(
        state.mqtt_client,
        topic: "home/hdmiSwitch/debug/mqtt",
        dup: 0,
        message: "connected",
        qos: 0,
        retain: 0
      )

    IO.puts("About to connect UART")

    :ok =
      Nerves.UART.open(
        state.uart,
        "ttyUSB0",
        speed: 19200,
        active: true,
        framing: {Nerves.UART.Framing.Line, separator: "\r\n"}
      )

    :ok =
      MqttClient.publish(
        state.mqtt_client,
        topic: "home/hdmiSwitch/debug/uart",
        dup: 0,
        message: "connected",
        qos: 0,
        retain: 0
      )

    IO.puts("Connected")

    {:noreply, state}
  end

  def handle_info(:connected, state) do
    MqttClient.subscribe(state.mqtt_client, topics: ["home/hdmiSwitch/setInput"], qoses: [1])
    :ok = Nerves.UART.write(state.uart, "swmode default")

    poll_switch()
    {:noreply, state}
  end

  def handle_info(:poll_switch, state) do
    :ok = Nerves.UART.write(state.uart, "read")
    poll_switch()

    {:noreply, state}
  end

  def handle_info({:nerves_uart, _port, message}, state) do
    case message do
      "swi0" <> <<input::bytes-size(1)>> <> " Command OK" ->
        publish_input(input, state)

      "Input: port" <> <<input::bytes-size(1)>> ->
        publish_input(input, state)

      message ->
        {:noreply, state}
    end
  end

  def handle_info(%{topic: "home/hdmiSwitch/setInput", message: message}, state) do
    :ok = Nerves.UART.write(state.uart, "swi0#{message}")

    {:noreply, state}
  end

  defp publish_input(input, state = %{input: old_input}) when input != old_input do
    :ok =
      MqttClient.publish(
        state.mqtt_client,
        topic: "home/hdmiSwitch/input",
        dup: 0,
        message: input,
        qos: 1,
        retain: 1
      )

    {:noreply, %{state | input: input}}
  end

  defp publish_input(_input, state) do
    {:noreply, state}
  end
end
