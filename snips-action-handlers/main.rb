require 'mqtt'
require 'httparty'

$stdout.sync = true
Thread.abort_on_exception = true

BROKER_HOST = ENV['BROKER_HOST']

volume = 0

def end_session(client, session_id)
  client.publish('hermes/dialogueManager/endSession', { sessionId: session_id }.to_json)
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

puts "host=#{BROKER_HOST} status=connecting"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "host=#{BROKER_HOST} status=connected"

  client.subscribe('home/speakers/volume', 'hermes/intent/#')

  client.get do |topic, message|
    case topic.split('/').last
    when 'volume'
      volume = message.to_i
      puts "Volume: #{volume}"
    when 'davesilva:volumeUp'
      body = JSON.parse(message)
      slots = extract_slots(body)
      amount = exact_amount(slots['amount'])

      client.publish('home/speakers/setVolume', volume + amount)
      end_session(client, body['sessionId'])
    when 'davesilva:volumeDown'
      body = JSON.parse(message)
      slots = extract_slots(body)
      amount = exact_amount(slots['amount'])

      client.publish('home/speakers/setVolume', volume - amount)
      end_session(client, body['sessionId'])
    when 'davesilva:screenOn'
      body = JSON.parse(message)

      client.publish('home/projector/setPower', true)
      end_session(client, body['sessionId'])
    when 'davesilva:screenOff'
      body = JSON.parse(message)

      client.publish('home/projector/setPower', false)
      end_session(client, body['sessionId'])
    when 'davesilva:switchVideoInput'
      body = JSON.parse(message)
      slots = extract_slots(body)
      input = slots['inputNumber']&.to_i || input_number(slots['inputName'])

      if input && input >= 1 && input <= 8
        client.publish('home/projector/setPower', true)
        client.publish('home/hdmiSwitch/setInput', input)
        end_session(client, body['sessionId'])
      end
    end
  end
end
