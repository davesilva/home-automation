require 'mqtt'
require 'httparty'

BROKER_HOST = ENV['BROKER_HOST']
VOLUME_HOST = ENV['VOLUME_HOST']

def get_speaker_data
  HTTParty.get("http://#{VOLUME_HOST}/speakers")
end

def update_speakers(body)
  HTTParty.post("http://#{VOLUME_HOST}/speakers", body: body)
end

puts "host=#{BROKER_HOST} status=connecting"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "host=#{BROKER_HOST} status=connected"

  Thread.new do
    old_power, old_volume = nil

    loop do
      response = get_speaker_data

      power = response['power']
      volume = response['volume']

      client.publish('home/speakers/power', power, retain: true) if power != old_power
      client.publish('home/speakers/volume', volume, retain: true) if volume != old_volume

      old_power = power
      old_volume = volume

      sleep 2
    end
  end

  client.get('home/speakers/+') do |topic, message|
    case topic.split('/').last
    when 'setPower'
      power = message == 'true'
      puts "topic=#{topic} power=#{power}"
      update_speakers(power: power)
    when 'setVolume'
      volume = message.to_i
      puts "topic=#{topic} volume=#{volume}"
      update_speakers(power: true, volume: volume)
    end
  end
end
