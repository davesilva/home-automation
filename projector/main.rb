require 'mqtt'
require 'httparty'

$stdout.sync = true
Thread.abort_on_exception = true

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

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

def projector_post(auth_token, data, retry_count=0)
  HTTParty.post("http://#{PROJECTOR_HOST}/tgi/control.tgi",
                body: data,
                headers: { 'Cookie' => auth_token },
                timeout: 5)
rescue Net::OpenTimeout, Net::ReadTimeout, Errno::EHOSTUNREACH, Errno::ECONNRESET
  if retry_count > 4
    raise UnavailableError
  else
    Kernel.sleep(retry_count + 1)
    projector_post(auth_token, data, retry_count + 1)
  end
end

def projector_query(auth_token)
  parse_response(projector_post(auth_token, { 'QueryControl' => '' }))
end

def projector_login
  cookies = nil

  while cookies.nil?
    $logger.info("host=#{PROJECTOR_HOST} status=logging_in")
    response = HTTParty.post("http://#{PROJECTOR_HOST}/tgi/login.tgi",
                             body: { "Username" => 1 },
                             timeout: 5)
    cookies = response.headers['Set-Cookie']&.split(';')
  end

  $logger.info("host=#{PROJECTOR_HOST} status=logged_in")
  cookies.find { |cookie| cookie.start_with?('ATOP=') }
end

class UnavailableError < RuntimeError
end

$logger.info("host=#{BROKER_HOST} status=connecting")
client = MQTT::Client.new(host: BROKER_HOST,
                          will_topic: 'home/projector/available',
                          will_payload: 'false',
                          will_retain: true)
client.connect
$logger.info("host=#{BROKER_HOST} status=connected")

$logger.info("host=#{PROJECTOR_HOST} status=connecting")
auth_token = projector_login
$logger.info("host=#{PROJECTOR_HOST} status=connected")

brightness_queue = Queue.new

home_assistant_device_config = {
  identifiers: ['projector'],
  name: 'Projector',
  model: 'P6500',
  manufacturer: 'Acer'
}
home_assistant_availability_config = [
  {
    topic: 'home/projector/available',
    payload_available: 'true',
    payload_not_available: 'false',
  }
]
home_assistant_power_config = {
  name: 'Projector',
  command_topic: 'home/projector/setPower',
  state_topic: 'home/projector/power',
  payload_on: 'true',
  payload_off: 'false',
  unique_id: 'projector_power',
  icon: 'mdi:projector',
  optimistic: true,
  qos: 2,
  availability: home_assistant_availability_config,
  device: home_assistant_device_config
}
client.publish('homeassistant/switch/projector/config', home_assistant_power_config.to_json, retain: true)

home_assistant_input_config = {
  name: 'Projector Input',
  command_topic: 'home/projector/setInput',
  state_topic: 'home/projector/input',
  payload_on: 'true',
  payload_off: 'false',
  options: ['1', '2', '3'],
  unique_id: 'projector_input',
  icon: 'mdi:video_input_hdmi',
  optimistic: true,
  qos: 2,
  availability: home_assistant_availability_config,
  device: home_assistant_device_config
}
client.publish('homeassistant/select/projector_input/config', home_assistant_input_config.to_json, retain: true)

Thread.new do
  old_power, old_input, old_brightness = nil
  desired_brightness = nil
  sleep_time = 2

  Kernel.loop do
    begin
      response = projector_query(auth_token)
      client.publish('home/projector/available', 'true', retain: true)

      power = response[:pwr] == '1'
      input = SOURCE_MAPPING[response[:src].to_i]
      brightness = response[:bri].to_i
      desired_brightness = brightness_queue.pop(true) rescue desired_brightness

      if power != old_power
        client.publish('home/projector/power', power.to_s, retain: true)
      end

      if input != old_input
        client.publish('home/projector/input', input.to_s, retain: true)
      end

      if brightness != old_brightness
        client.publish('home/projector/brightness', brightness.to_s, retain: true)
      end

      if power && desired_brightness && desired_brightness != brightness
        if desired_brightness < brightness
          projector_post(auth_token, brid: '')
        else
          projector_post(auth_token, bria: '')
        end
        sleep_time = 0.1
      else
        sleep_time = 2
      end

      old_power = power
      old_input = input
      old_brightness = brightness
    rescue UnavailableError
      client.publish('home/projector/available', 'false', retain: true)
    end

    Kernel.sleep sleep_time
  end
end

client.get('home/projector/+') do |topic, message|
  case topic.split('/').last
  when 'setInput'
    $logger.info("topic=#{topic} input=#{message}")
    projector_post(auth_token, src: message)
  when 'setPower'
    $logger.info("topic=#{topic} power=#{message}")
    if message == 'true'
      projector_post(auth_token, pwr: 'Power ON')
    else
      projector_post(auth_token, pwr: 'Power OFF')
      Kernel.sleep 1
      projector_post(auth_token, pwr: 'Power OFF')
    end
  when 'setBrightness'
    $logger.info("topic=#{topic} brightness=#{message}")
    brightness_queue.push(message.to_i)
  end
end
