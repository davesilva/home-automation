require 'mqtt'
require 'httparty'

$stdout.sync = true
Thread.abort_on_exception = true

BROKER_HOST = ENV['BROKER_HOST']
PROJECTOR_HOST = ENV['PROJECTOR_HOST']

# The projector does a weird thing where when it returns the
# source number to you it's different from the number you
# set. This maps those returned numbers back to the
# normal ones.
SOURCE_MAPPING = { 6 => 1, 21 => 2, 22 => 3 }

def parse_response(response)
  JSON.parse(response.to_s.gsub(/(\w*):/, '"\1":'), symbolize_names: true)
end

def projector_post(auth_token, data)
  HTTParty.post("http://#{PROJECTOR_HOST}/tgi/control.tgi",
                body: data,
                headers: { 'Cookie' => auth_token })
end

def projector_query(auth_token)
  parse_response(projector_post(auth_token, { 'QueryControl' => '' }))
end

def projector_login
  cookies = nil

  while cookies.nil?
    puts "host=#{PROJECTOR_HOST} status=logging_in"
    response = HTTParty.post("http://#{PROJECTOR_HOST}/tgi/login.tgi",
                             body: { "Username" => 1 })
    cookies = response.headers['Set-Cookie']&.split(';')
  end

  puts "host=#{PROJECTOR_HOST} status=logged_in"
  cookies.find { |cookie| cookie.start_with?('ATOP=') }
end

puts "host=#{BROKER_HOST} status=connecting"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "host=#{BROKER_HOST} status=connected"

  puts "host=#{PROJECTOR_HOST} status=connecting"
  auth_token = projector_login
  puts "host=#{PROJECTOR_HOST} status=connected"

  Thread.new do
    old_power, old_input = nil

    loop do
      response = projector_query(auth_token)

      power = response[:pwr] == '1'
      input = SOURCE_MAPPING[response[:src].to_i]

      client.publish('home/projector/power', power, retain: true) if power != old_power
      client.publish('home/projector/input', input, retain: true) if input != old_input

      old_power = power
      old_input = input

      sleep 2
    end
  end

  client.get('home/projector/+') do |topic, message|
    case topic.split('/').last
    when 'setInput'
      puts "topic=#{topic} input=#{message}"
      projector_post(auth_token, src: message)
    when 'setPower'
      puts "topic=#{topic} power=#{message}"
      if message == 'true'
        projector_post(auth_token, pwr: 'Power ON')
      else
        projector_post(auth_token, pwr: 'Power OFF')
        sleep 1
        projector_post(auth_token, pwr: 'Power OFF')
      end
    end
  end
end
