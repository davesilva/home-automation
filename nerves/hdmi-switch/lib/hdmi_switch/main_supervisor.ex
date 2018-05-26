defmodule HdmiSwitch.MainSupervisor do
  use Supervisor

  alias HdmiSwitch.Main

  def start_link(_options) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok), do: Supervisor.init([Main], strategy: :one_for_one)
end
