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
                          will_topic: 'home/speakers/available',
                          will_payload: 'false',
                          will_retain: true)
client.connect('speakers')
$logger.info("host=#{BROKER_HOST} status=connected")
arduino_serial = SerialPort.new(SERIAL_PORT)
client.publish('home/speakers/available', 'true', retain: true)

last_heartbeat = Time.now
power = false
volume_initialized = false

Thread.new do
  Kernel.loop do
    begin
      arduino_serial.each_line do |line|
        (message, value) = line.split

        next if message.nil?

        if last_heartbeat < 30.seconds.ago
          client.publish('home/speakers/available', 'true', retain: true)
          last_heartbeat = Time.now
        end

        if message == 'ON'
          client.publish('home/speakers/power', 'true', retain: true)
          power = true
        elsif message == 'OFF'
          client.publish('home/speakers/power', 'false', retain: true)
          power = false
        elsif message == 'SET_VOLUME'
          client.publish('home/speakers/volume', value, retain: true)
          $logger.info("volume=#{value}")
          volume_initialized = true
        elsif message == 'INVALID_VOLUME'
          $logger.error("invalid_volume=#{value}")
        end
      end
    rescue => e
      $logger.error(e)
      client.publish('home/speakers/available', 'false', retain: true)
      arduino_serial = SerialPort.new(SERIAL_PORT)
    end
  end
end

client.get('home/speakers/+') do |topic, message|
  case topic.split('/').last
  when 'setVolume'
    $logger.info("topic=#{topic} volume=#{message}")
    arduino_serial.write(message + "\n")

    if message == "0"
      arduino_serial.write("off\n")
    else
      arduino_serial.write("on\n") unless power
    end
  when 'setPower'
    $logger.info("topic=#{topic} power=#{message}")
  when 'volume'
    unless volume_initialized
      $logger.info("topic=#{topic} initial_volume=#{message}")
      arduino_serial.write(message + "\n")
    end
  end
end
