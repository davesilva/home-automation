defmodule HdmiSwitch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  @target Mix.Project.config()[:target]

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HdmiSwitch.Supervisor]
    Process.sleep(10000)
    Supervisor.start_link(children(@target), opts)
  end

  # List all child processes to be supervised
  def children("host") do
    [
      # Starts a worker by calling: HdmiSwitch.Worker.start_link(arg)
      # {HdmiSwitch.Worker, arg},
    ]
  end

  def children(_target) do
    [
      HdmiSwitch.MainSupervisor
    ]
  end
end
