require 'mqtt'
require 'json'

$stdout.sync = true
Thread.abort_on_exception = true

BROKER_HOST = ENV['BROKER_HOST']

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

@input = nil
@input_volume = {}

def send_device_message(client, device, endpoint, message)
  $logger.info("device=#{device} endpoint=#{endpoint} message=#{message}")
  client.publish("home/#{device}/#{endpoint}", message.to_s)
end

def persist_input_volume(client, input, volume)
  client.publish("home/state/input/#{input.to_s}/lastVolume", volume.to_s, retain: true)
end

def input_number(input_name)
  case input_name
  when 'Steam Link' then 1
  when 'XBox One' then 2
  when 'Switch' then 3
  when 'PS4' then 7
  when 'Chromecast' then 8
  end
end

$logger.info("host=#{BROKER_HOST} status=connecting")
client = MQTT::Client.connect(BROKER_HOST)
$logger.info("host=#{BROKER_HOST} status=connected")

client.subscribe('home/speakers/volume',
                 'home/projector/power',
                 'home/hdmiSwitch/input',
                 'home/state/input/+/lastVolume')

client.get do |topic, message|
  body = JSON.parse(message) rescue nil
  topic_last = topic.split('/').last

  if topic_last == 'volume'
    if !@input.nil? && body != 0
      persist_input_volume(client, @input, body)
    end

    $logger.info("volume=#{body}")
  elsif topic_last == 'lastVolume'
    input = topic.split('/')[3].to_i
    $logger.info("input=#{input} lastVolume=#{body}")
    @input_volume[input] = body
  elsif topic_last == 'input'
    @input = body
    $logger.info("input=#{@input}")

    if !@input_volume[@input].nil?
      send_device_message(client, 'speakers', 'setVolume', @input_volume[@input])
    end
  elsif topic == 'home/projector/power'
    if body == true
      $logger.info("projector=on")
      if !@input.nil? && !@input_volume[@input].nil?
        send_device_message(client, 'speakers', 'setVolume', @input_volume[@input])
      end
    else
      $logger.info("projector=off")
      send_device_message(client, 'speakers', 'setVolume', 0)
    end
  end
end
