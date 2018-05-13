require 'mqtt'
require 'rubyserial'

BROKER_HOST = ENV['BROKER_HOST']
SERIAL_DEVICE = ENV['SERIAL_DEVICE']

SERIAL_PORT = Serial.new(SERIAL_DEVICE, 19200)


puts "Attempting to connect to #{BROKER_HOST}"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "Connected to #{BROKER_HOST}"

  Thread.new do
    loop do
      status = ''
      status += SERIAL_PORT.read(10) while !status.end_with?("\r\n")

      if status.start_with?('Input:')
        input = status.match(/^Input: port(.)\r\n/)[1]
        client.publish('home/hdmiSwitch/input', input, retain: true)

        puts "Current input: #{input}"
      end
    end
  end

  SERIAL_PORT.write("read\r\n")

  client.get('home/hdmiSwitch/setInput') do |_, message|
    SERIAL_PORT.write("swi0#{message}\r\n")
    sleep 1
    SERIAL_PORT.write("read\r\n")
  end
end
