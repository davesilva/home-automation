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
                          will_topic: 'home/laundry/available',
                          will_payload: 'false',
                          will_retain: true)
client.connect
$logger.info("host=#{BROKER_HOST} status=connected")

washing_machine_last_running = nil
washing_machine_last_stopped = nil
dryer_last_running = nil
dryer_last_stopped = nil

washing_machine_values = []
dryer_values = []

Kernel.loop do
  begin
    arduino_serial = SerialPort.new(SERIAL_PORT)
    client.publish('home/laundry/available', 'true', retain: true)

    arduino_serial.each_line do |line|
      (washing_machine, dryer) = line.split.map(&:to_f)

      next if washing_machine.nil? || dryer.nil?

      washing_machine_values.push(washing_machine)
      washing_machine_values.shift if washing_machine_values.length > 20
      washing_machine_avg = (washing_machine_values.sum / washing_machine_values.length).round(2)

      dryer_values.push(dryer)
      dryer_values.shift if dryer_values.length > 20
      dryer_avg = (dryer_values.sum / dryer_values.length).round(2)

      $logger.info("washing_machine=#{washing_machine} dryer=#{dryer} washing_machine_avg=#{washing_machine_avg} dryer_avg=#{dryer_avg}")
      if washing_machine_avg > 0.3
        washing_machine_last_running = Time.now
        client.publish('home/laundry/washingMachine/running', 'true', retain: true)
      else
        washing_machine_last_stopped = Time.now
        if washing_machine_last_running.nil? || washing_machine_last_running < 30.seconds.ago
          client.publish('home/laundry/washingMachine/running', 'false', retain: true)
        end
      end

      if dryer_avg > 0.5
        dryer_last_running = Time.now
        if dryer_last_stopped.nil? || dryer_last_stopped < 30.seconds.ago
          client.publish('home/laundry/dryer/running', 'true', retain: true)
        end
      else
        dryer_last_stopped = Time.now
        if dryer_last_running.nil? || dryer_last_running < 30.seconds.ago
          client.publish('home/laundry/dryer/running', 'false', retain: true)
        end
      end
    end
  rescue => e
    $logger.error(e)
    client.publish('home/laundry/available', 'false', retain: true)
  end
end
