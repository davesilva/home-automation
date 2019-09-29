require 'mqtt'
require 'json'

$stdout.sync = true
Thread.abort_on_exception = true

BROKER_HOST = ENV['BROKER_HOST']
PROBABILITY_THRESHOLD = 0.6
CONFIRM_SOUND_EFFECT = File.open('confirm.wav').read

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

class DeviceUnavailableError < StandardError
  attr_reader :device

  def initialize(device)
    @device = device
    super(friendly_message)
  end

  private

  def friendly_message
    case device
    when 'projector'
      %Q(
        The projector control is offline. Make sure the ethernet cable
        on the projector is plugged in all the way.
      )
    when 'hdmiSwitch'
      %Q(
        The H D M I switch control is offline. Make sure the Raspberry Pi
        in the red case is powered on and connected to the H D M I switch.
      )
    when 'speakers'
      %Q(
        The volume control is offline. Make sure the black volume control
        box next to the subwoofer is powered on and the ethernet cable
        is connected.
      )
    when 'tv'
      %Q(
        The TV control is offline. Make sure the Raspberry Pi in front
        of the TV is receiving power.
      )
    end
  end
end

@volume = 0
@availability = Hash.new(false)

def end_session(client, body, text = nil, success = true)
  site_id = body['siteId']
  session_id = body['sessionId']

  if success
    sound_topic = "hermes/audioServer/#{site_id}/playBytes/#{session_id}"
    client.publish(sound_topic, CONFIRM_SOUND_EFFECT)
  end

  client.publish('hermes/dialogueManager/endSession', { sessionId: session_id, text: text }.to_json)
end

def send_device_message(client, device, endpoint, message)
  if !@availability[device]
    $logger.error("device=#{device} status=unavailable")
    raise DeviceUnavailableError.new(device)
  else
    $logger.info("device=#{device} endpoint=#{endpoint} message=#{message}")
    client.publish("home/#{device}/#{endpoint}", message)
  end
end

def extract_slots(body)
  Hash[body['slots'].map { |slot| [slot['slotName'], slot['value']['value']] }]
end

def exact_amount(qualitative_amount)
  case qualitative_amount
  when 'a little' then 1
  when nil then 2
  when 'a lot' then 4
  when 'a whole lot' then 8
  end
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
                 'home/+/available',
                 'hermes/intent/+',
                 'hermes/dialogueManager/sessionEnded')

client.get do |topic, message|
  body = JSON.parse(message) rescue nil
  topic_second = topic.split('/')[1]
  topic_last = topic.split('/').last

  if topic_last == 'volume'
    @volume = body
    $logger.info("volume=#{@volume}")
  elsif topic_last == 'available'
    @availability[topic_second] = message == 'true'
  elsif topic_second == 'intent' &&
      body['intent']['confidenceScore'] > PROBABILITY_THRESHOLD

    case topic_last
    when 'davesilva:volumeUp'
      slots = extract_slots(body)
      amount = exact_amount(slots['amount'])

      if body['siteId'] == 'projector-room'
        send_device_message(client, 'speakers', 'setVolume', (@volume + amount).to_s)
        end_session(client, body)
      elsif body['siteId'] == 'tv-room'
        amount.times { send_device_message(client, 'tv', 'setVolume', 'up') }
        end_session(client, body)
      end
    when 'davesilva:volumeDown'
      slots = extract_slots(body)
      amount = exact_amount(slots['amount'])

      if body['siteId'] == 'projector-room'
        new_volume = @volume - amount < 0 ? 0 : @volume - amount
        send_device_message(client, 'speakers', 'setVolume', new_volume.to_s)
        end_session(client, body)
      elsif body['siteId'] == 'tv-room'
        amount.times { send_device_message(client, 'tv', 'setVolume', 'down') }
        end_session(client, body)
      end
    when 'davesilva:screenOn'
      slots = extract_slots(body)

      if slots['device'] == 'projector' ||
         (slots['device'].nil? && body['siteId'] == 'projector-room')
        send_device_message(client, 'projector', 'setPower', 'true')
        end_session(client, body)
      elsif slots['device'] == 'TV' ||
            (slots['device'].nil? && body['siteId'] == 'tv-room')
        send_device_message(client, 'tv', 'setPower', 'true')
        end_session(client, body)
      end
    when 'davesilva:screenOff'
      slots = extract_slots(body)

      if slots['device'] == 'projector' ||
         (slots['device'].nil? && body['siteId'] == 'projector-room')
        send_device_message(client, 'projector', 'setPower', 'false')
        end_session(client, body)
      elsif slots['device'] == 'TV' ||
            (slots['device'].nil? && body['siteId'] == 'tv-room')
        send_device_message(client, 'tv', 'setPower', 'false')
        end_session(client, body)
      end
    when 'davesilva:switchVideoInput'
      slots = extract_slots(body)

      if body['siteId'] == 'projector-room'
        input = slots['inputNumber']&.to_i || input_number(slots['inputName'])

        if input && input >= 1 && input <= 8
          send_device_message(client, 'projector', 'setPower', 'true')
          send_device_message(client, 'hdmiSwitch', 'setInput', input.to_s)
          end_session(client, body)
        end
      elsif body['siteId'] == 'tv-room'
        input = slots['inputNumber']&.to_i

        if input && input >= 0 && input <= 4
          send_device_message(client, 'tv', 'setInput', input.to_s)
          end_session(client, body)
        end
      end
    end
  elsif topic_second == 'intent'
    end_session(client, body, "I didn't quite catch that.", false)
  elsif topic_second == 'dialogueManager' && body['termination']['reason'] == 'error'
    end_session(client, body, 'There was an unexpected error in the snips dialogue manager.', false)
  end

rescue DeviceUnavailableError => e
  end_session(client, body, e.message, false)
end
