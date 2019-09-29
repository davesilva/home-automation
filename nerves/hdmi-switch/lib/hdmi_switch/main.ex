defmodule HdmiSwitch.Main do
  use Connection
  require Logger

  alias HdmiSwitch.MqttClient

  def start_link do
    Logger.info("Main Starting...")
    Connection.start_link(__MODULE__, %{}, [])
  end

  @impl true
  def init(%{}) do
    Logger.info("Inside init")
    {:ok, mqtt_client} = MqttClient.start_link(%{parent: self()})
    {:ok, uart} = Nerves.UART.start_link()

    Logger.info("Finished init")

    {:connect, :init, %{mqtt_client: mqtt_client, uart: uart, input: 0, read_state: :unacked}}
  end

  def on_connect(pid) do
    Logger.info("On connect")
    Kernel.send(pid, :connected)
  end

  def poll_switch do
    Process.send_after(self(), :poll_switch, 2000)
  end

  def on_receive_message(pid, topic, message) do
    Kernel.send(pid, %{topic: topic, message: message})
  end

  @impl true
  def connect(_, state) do
    Logger.info("About to connect MQTT and UART")

    with :ok <- MqttClient.connect(
        state.mqtt_client,
        client_id: "hdmi-switch",
        host: "192.168.1.8",
        port: 1883,
        will_topic: "home/hdmiSwitch/available",
        will_message: "false",
        will_qos: 0,
        will_retain: 1,
        keep_alive: 15
      ),
      :ok <- Nerves.UART.open(
        state.uart,
        "ttyUSB0",
        speed: 19200,
        active: true,
        framing: {Nerves.UART.Framing.Line, separator: "\r\n"}
      ),
      :ok <- Nerves.UART.write(state.uart, "swmode default")
    do
      Logger.info("Connected")
      {:ok, state}
    else
      _ -> {:backoff, 1000, state}
    end
  end

  @impl true
  def disconnect(error, state) do
    Logger.info("Disconnect")
    Logger.error(error)
    {:backoff, 1000, state}
  end

  @impl true
  def handle_info(:connected, state) do
    with :ok <- MqttClient.subscribe(state.mqtt_client, topics: ["home/hdmiSwitch/setInput"], qoses: [1])
    do
      poll_switch()
      {:noreply, state}
    else
      {:error, error} -> {:disconnect, error, state}
    end
  end

  @impl true
  def handle_info(:poll_switch, state = %{read_state: :sent}) do
    publish_available("false", state)
    handle_info(:poll_switch, %{state | read_state: :unacked})
  end

  @impl true
  def handle_info(:poll_switch, state) do
    case Nerves.UART.write(state.uart, "read") do
      :ok ->
        poll_switch()
        {:noreply, %{state | read_state: :sent}}
      {:error, error} ->
        {:disconnect, error, state}
    end
  end

  @impl true
  def handle_info({:nerves_uart, _port, message}, state) do
    case message do
      "swi0" <> <<input::bytes-size(1)>> <> " Command OK" ->
        publish_input(input, state)

      "Input: port" <> <<input::bytes-size(1)>> ->
        publish_input(input, %{state | read_state: :acked})

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(%{topic: "home/hdmiSwitch/setInput", message: message}, state) do
    case Nerves.UART.write(state.uart, "swi0#{message}") do
      :ok -> {:noreply, state}
      {:error, error} -> {:disconnect, error, state}
    end
  end

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  defp publish_available(message, state) do
    case MqttClient.publish(
        state.mqtt_client,
        topic: "home/hdmiSwitch/available",
        dup: 0,
        message: message,
        qos: 0,
        retain: 1
      )
    do
      :ok -> {:noreply, state}
      {:error, error} -> {:disconnect, error, state}
    end
  end

  defp publish_input(input, state = %{input: old_input}) when input != old_input do
    with :ok <- MqttClient.publish(
        state.mqtt_client,
        topic: "home/hdmiSwitch/input",
        dup: 0,
        message: input,
        qos: 1,
        retain: 1
      ),
      {:noreply, state} <- publish_available("true", state)
    do
      {:noreply, %{state | input: input}}
    else
      {:error, error} -> {:disconnect, error, state}
    end
  end

  defp publish_input(_input, state) do
    publish_available("true", state)
  end
end
