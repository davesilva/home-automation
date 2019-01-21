require 'mqtt'
require 'httparty'

$stdout.sync = true
Thread.abort_on_exception = true

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

BROKER_HOST = ENV['BROKER_HOST']
VOLUME_HOST = ENV['VOLUME_HOST']

def get_speaker_data
  HTTParty.get("http://#{VOLUME_HOST}/speakers", timeout: 5)
end

def update_speakers(body)
  HTTParty.post("http://#{VOLUME_HOST}/speakers", body: body, timeout: 5)
end

$logger.info("host=#{BROKER_HOST} status=connecting")
client = MQTT::Client.new(host: BROKER_HOST,
                          will_topic: 'home/speakers/available',
                          will_payload: 'false',
                          will_retain: true)
client.connect
$logger.info("host=#{BROKER_HOST} status=connected")

Thread.new do
  old_power, old_volume = nil

  Kernel.loop do
    begin
      response = get_speaker_data
      client.publish('home/speakers/available', 'true', retain: true)

      power = response['power']
      volume = response['volume']

      client.publish('home/speakers/power', power.to_s, retain: true) if power != old_power
      client.publish('home/speakers/volume', volume.to_s, retain: true) if volume != old_volume

      old_power = power
      old_volume = volume
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::EHOSTUNREACH
      client.publish('home/speakers/available', 'false', retain: true)
    end

    Kernel.sleep 2
  end
end

client.get('home/speakers/+') do |topic, message|
  case topic.split('/').last
  when 'setPower'
    power = message == 'true'
    $logger.info("topic=#{topic} power=#{power}")
    update_speakers(power: power)
  when 'setVolume'
    volume = message.to_i
    $logger.info("topic=#{topic} volume=#{volume}")
    update_speakers(power: true, volume: volume)
  end
end
