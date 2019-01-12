require 'mqtt'
require 'httparty'

$stdout.sync = true
Thread.abort_on_exception = true

BROKER_HOST = ENV['BROKER_HOST']
PROBABILITY_THRESHOLD = 0.6
CONFIRM_SOUND_EFFECT = File.open('confirm.wav').read
ERROR_SOUND_EFFECT = File.open('error.wav').read

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

  client.subscribe('home/speakers/volume',
                   'hermes/intent/#',
                   'hermes/dialogueManager/sessionEnded')

  client.get do |topic, message|
    body = JSON.parse(message) rescue nil
    topic_second = topic.split('/')[1]
    topic_last = topic.split('/').last

    if topic_last == 'volume'
      volume = body
      puts "Volume: #{volume}"
    elsif topic_second == 'intent' &&
          body['intent']['probability'] > PROBABILITY_THRESHOLD
      sound_topic = "hermes/audioServer/#{body['siteId']}/playBytes/#{body['sessionId']}"
      client.publish(sound_topic, CONFIRM_SOUND_EFFECT)

      case topic_last
      when 'davesilva:volumeUp'
        slots = extract_slots(body)
        amount = exact_amount(slots['amount'])

        if body['siteId'] == 'projector-room'
          client.publish('home/speakers/setVolume', volume + amount)
        elsif body['siteId'] == 'tv-room'
          amount.times { client.publish('home/tv/setVolume', 'up') }
        end

        end_session(client, body['sessionId'])
      when 'davesilva:volumeDown'
        slots = extract_slots(body)
        amount = exact_amount(slots['amount'])

        if body['siteId'] == 'projector-room'
          client.publish('home/speakers/setVolume', volume - amount)
        elsif body['siteId'] == 'tv-room'
          amount.times { client.publish('home/tv/setVolume', 'down') }
        end

        end_session(client, body['sessionId'])
      when 'davesilva:screenOn'
        slots = extract_slots(body)

        if slots['device'] == 'projector' ||
           (slots['device'].nil? && body['siteId'] == 'projector-room')
          client.publish('home/projector/setPower', true)
        elsif slots['device'] == 'TV' ||
              (slots['device'].nil? && body['siteId'] == 'tv-room')
          client.publish('home/tv/setPower', true)
        end

        end_session(client, body['sessionId'])
      when 'davesilva:screenOff'
        slots = extract_slots(body)

        if slots['device'] == 'projector' ||
           (slots['device'].nil? && body['siteId'] == 'projector-room')
          client.publish('home/projector/setPower', false)
        elsif slots['device'] == 'TV' ||
              (slots['device'].nil? && body['siteId'] == 'tv-room')
          client.publish('home/tv/setPower', false)
        end

        end_session(client, body['sessionId'])
      when 'davesilva:switchVideoInput'
        slots = extract_slots(body)

        if body['siteId'] == 'projector-room'
          input = slots['inputNumber']&.to_i || input_number(slots['inputName'])

          if input && input >= 1 && input <= 8
            client.publish('home/projector/setPower', true)
            client.publish('home/hdmiSwitch/setInput', input)
          end
        elsif body['siteId'] == 'tv-room'
          input = slots['inputNumber']&.to_i

          if input && input >= 0 && input <= 4
            client.publish('home/tv/setInput', input)
          end
        end

        end_session(client, body['sessionId'])
      end
    elsif topic_second == 'intent' ||
          (topic_second == 'dialogueManager' &&
           body['termination']['reason'] == 'error')
      sound_topic = "hermes/audioServer/#{body['siteId']}/playBytes/#{body['sessionId']}"
      client.publish(sound_topic, ERROR_SOUND_EFFECT)
    end
  end
end
