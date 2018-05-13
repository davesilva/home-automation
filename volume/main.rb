require 'mqtt'
require 'httparty'

BROKER_HOST = ENV['BROKER_HOST']
VOLUME_HOST = ENV['VOLUME_HOST']

def publish_speaker_data(client)
  data = HTTParty.get("http://#{VOLUME_HOST}/speakers")
  client.publish('home/speakers/power', data['power'], retain: true)
  client.publish('home/speakers/volume', data['volume'], retain: true)
end

puts "Attempting to connect to #{BROKER_HOST}"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "Connected to #{BROKER_HOST}"

  client.get('home/speakers/setVolume') do |_, message|
    HTTParty.post("http://#{VOLUME_HOST}/speakers", body: { volume: message.to_i,
                                                            power: true })
    publish_speaker_data(client)
  end

  client.get('home/speakers/setPower') do |_, message|
    HTTParty.post("http://#{VOLUME_HOST}/speakers", body: { power: message == 'true' })
    publish_speaker_data(client)
  end
end
