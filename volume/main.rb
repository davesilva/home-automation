require 'mqtt'
require 'httparty'

BROKER_HOST = ENV['BROKER_HOST']
VOLUME_HOST = ENV['VOLUME_HOST']

def publish_speaker_data(client)
  data = HTTParty.get("http://#{VOLUME_HOST}/speakers")
  client.publish('home/speakers/power', data['power'], retain: true)
  client.publish('home/speakers/volume', data['volume'], retain: true)
end

def update_speakers(body)
  HTTParty.post("http://#{VOLUME_HOST}/speakers", body: body)
end

puts "host=#{BROKER_HOST} status=connecting"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "host=#{BROKER_HOST} status=connected"

  Thread.new do
    loop do
      publish_speaker_data(client)
      sleep 5
    end
  end

  client.get('home/speakers/+') do |topic, message|
    case topic.split('/').last
    when 'setPower'
      power = message == 'true'
      puts "topic=#{topic} power=#{power}"
      update_speakers(power: power)
      publish_speaker_data(client)
    when 'setVolume'
      volume = message.to_i
      puts "topic=#{topic} volume=#{volume}"
      update_speakers(power: true, volume: volume)
      publish_speaker_data(client)
    end
  end
end
