require 'mqtt'
require 'httparty'

BROKER_HOST = ENV['BROKER_HOST']
PROJECTOR_HOST = ENV['PROJECTOR_HOST']

def projector_post(auth_token, data)
  HTTParty.post("http://#{PROJECTOR_HOST}/tgi/control.tgi",
                body: data,
                headers: { 'Cookie' => auth_token })
end

def projector_query(auth_token)
  response = projector_post(auth_token, { 'QueryControl' => '' })
  puts response
  puts response['pwr']
end

def projector_login
  response = HTTParty.post("http://#{PROJECTOR_HOST}/tgi/login.tgi",
                           body: { "Username" => 1 })
  cookies = response.headers['Set-Cookie']&.split(';')
  cookies&.find { |cookie| cookie.start_with?('ATOP=') }
end

puts "Attempting to connect to #{BROKER_HOST}"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "Connected to #{BROKER_HOST}"

  puts "Attempting to connect to projector at #{PROJECTOR_HOST}"
  auth_token = projector_login
  puts "Connected to #{PROJECTOR_HOST}"

  Thread.new do
    loop do
      projector_query(auth_token)
      sleep 2
    end
  end

  client.get('home/projector/setInput') do |_, message|
    projector_post(auth_token, src: message)
  end

  client.get('home/projector/setPower') do |_, message|
    if message == 'true'
      projector_post(auth_token, pwr: 'Power ON')
    else
      projector_post(auth_token, pwr: 'Power OFF')
    end
  end
end
