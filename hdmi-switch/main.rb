require 'mqtt'
require 'serialport'
require 'active_support/all'

BROKER_HOST = ENV['BROKER_HOST']
SERIAL_PORT = ENV['SERIAL_PORT']

$stdout.sync = true
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

$logger.info("host=#{BROKER_HOST} status=connecting")
client = MQTT::Client.new(host: BROKER_HOST,
                          will_topic: 'home/hdmiSwitch/available',
                          will_payload: 'false',
                          will_retain: true)
client.connect('hdmi-switch')
$logger.info("host=#{BROKER_HOST} status=connected")

# Set baud rate to 19200 because the SerialPort gem can't do it
system("stty -F #{SERIAL_PORT} 19200")
serial = SerialPort.new(SERIAL_PORT)

lastInput = 0
last_heartbeat = Time.now - 1.minute

Thread.new do
  Kernel.loop do
    Kernel.sleep 5
    serial.write("read\r\n")
    if last_heartbeat < 1.minute.ago
      client.publish('home/hdmiSwitch/available', 'false', retain: true)
    end
  end
end

Thread.new do
  Kernel.loop do
    begin
      serial.write("swmode default\r\n")

      serial.each_line do |line|
        $logger.debug(line)

        if line.start_with?('swi')
          input = /swi0(\d)/.match(line)[1].to_i
          client.publish('home/hdmiSwitch/input', input, retain: true)
          $logger.info("input=#{input}")
          lastInput = input
        elsif line.start_with?('Input:')
          input = /Input: port(\d)/.match(line)[1].to_i

          if input != lastInput
            client.publish('home/hdmiSwitch/input', input, retain: true)
            $logger.info("input=#{input}")
            lastInput = input
          end
        else
          next
        end

        if last_heartbeat < 30.seconds.ago
          client.publish('home/hdmiSwitch/available', 'true', retain: true)
          last_heartbeat = Time.now
        end
      end
    rescue => e
      $logger.error(e)
      client.publish('home/hdmiSwitch/available', 'false', retain: true)
      serial = SerialPort.new(SERIAL_PORT, baud: 19200)
    end
  end
end

client.get('home/hdmiSwitch/+') do |topic, message|
  case topic.split('/').last
  when 'setInput'
    $logger.info("topic=#{topic} input=#{message}")
    serial.write("swi0#{message}\r\n")
  end
end
