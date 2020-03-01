require 'mqtt'

BROKER_HOST = ENV['BROKER_HOST']

$stdout.sync = true
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

def send_command(command)
  Kernel.system("irsend SEND_ONCE CT-90325 #{command}")
end

$logger.info("host=#{BROKER_HOST} status=connecting")
client = MQTT::Client.new(host: BROKER_HOST,
                          will_topic: 'home/tv/available',
                          will_payload: 'false',
                          will_retain: true)
client.connect
$logger.info("host=#{BROKER_HOST} status=connected")

# Show as unavailable if the lircd socket does not exist
Thread.new do
  Kernel.loop do
    begin
      if File.socket?('/var/run/lirc/lircd')
        client.publish('home/projector/available', 'true', retain: true)
      else
        raise RuntimeError.new('Lircd socket not found')
      end

    rescue
      client.publish('home/projector/available', 'false', retain: true)
      Kernel.system('systemctl stop lircd.socket')
      Kernel.system('systemctl start lircd.socket')
    end

    Kernel.sleep 60
  end
end

last_volume_command_at = 0

client.get('home/tv/+') do |topic, message|
  case topic.split('/').last
  when 'setInput'
    $logger.info("topic=#{topic} input=#{message}")
    send_command('KEY_CYCLEWINDOWS')
    Kernel.sleep 0.5
    case message
    when '0' then send_command('KEY_0')
    when '1' then send_command('KEY_1')
    when '2' then send_command('KEY_2')
    when '3' then send_command('KEY_3')
    when '4' then send_command('KEY_4')
    end
  when 'setVolume'
    $logger.info("topic=#{topic} volume=#{message}")
    if (Time.now - last_volume_command_at).to_f > 5.0
      send_command('KEY_VOLUMEUP')
    end
    last_volume_command_at = Time.now

    if message == 'up'
      send_command('KEY_VOLUMEUP')
    else
      send_command('KEY_VOLUMEDOWN')
    end
  when 'setChannel'
    $logger.info("topic=#{topic} channel=#{message}")
    case message
    when 'up' then send_command('KEY_CHANNELUP')
    when 'down' then send_command('KEY_CHANNELDOWN')
    end
  when 'setPower'
    $logger.info("topic=#{topic} power=#{message}")
    send_command('KEY_POWER')
  end
end
