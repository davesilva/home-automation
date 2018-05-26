defmodule HdmiSwitch.MqttClient do
  use Hulaaki.Client

  alias HdmiSwitch.Main

  def on_connect_ack(message: message, state: state) do
    Main.on_connect(state.parent)
  end

  def on_subscribed_publish(message: message, state: state) do
    Main.on_receive_message(state.parent, message.topic, message.message)
  end
end
