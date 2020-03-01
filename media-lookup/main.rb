require 'mqtt'
require 'rspotify'
require 'json'

$stdout.sync = true
Thread.abort_on_exception = true

BROKER_HOST = ENV['BROKER_HOST']
CLIENT_ID = ENV['CLIENT_ID']
CLIENT_SECRET = ENV['CLIENT_SECRET']
PROBABILITY_THRESHOLD = 0.6

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

def end_session(client, body, text = nil, success = true)
  site_id = body['siteId']
  session_id = body['sessionId']

  if success
    text = "[[sound:confirm]] #{text}"
  end

  client.publish('hermes/dialogueManager/endSession', { sessionId: session_id, text: text }.to_json)
end

def extract_slots(body)
  slots = {}
  body['slots'].each do |slot|
    slots[slot['slotName']] ||= []
    slots[slot['slotName']] += [slot['value']['value']]
  end
  slots
end

def extract_platform(slots)
  if slots['platform'].nil?
    case extract_media_type(slots)
    when :music_video
      :youtube
    else
      :spotify
    end
  elsif slots['platform'].include?('Spotify')
    :spotify
  elsif slots['platform'].include?('YouTube')
    :youtube
  elsif slots['platform'].include?('MIDI')
    :midi
  else
    :unknown
  end
end

def extract_media_type(slots)
  if slots['mediaType'].nil?
    :any
  elsif slots['mediaType'].include?('song')
    :song
  elsif slots['mediaType'].include?('artist')
    :artist
  elsif slots['mediaType'].include?('album')
    :album
  elsif slots['mediaType'].include?('playlist')
    :playlist
  elsif slots['mediaType'].include?('music video')
    :music_video
  else
    :unknown
  end
end

RSpotify.authenticate(CLIENT_ID, CLIENT_SECRET)

$logger.info("host=#{BROKER_HOST} status=connecting")
client = MQTT::Client.connect(BROKER_HOST)
$logger.info("host=#{BROKER_HOST} status=connected")

client.subscribe('hermes/intent/+',
                 'hermes/dialogueManager/sessionEnded')

client.get do |topic, message|
  body = JSON.parse(message) rescue nil
  topic_second = topic.split('/')[1]
  topic_last = topic.split('/').last

  if topic_second == 'intent' &&
      body['intent']['confidenceScore'] > PROBABILITY_THRESHOLD

    case topic_last
    when 'davesilva:playMedia'
      slots = extract_slots(body)

      platform = extract_platform(slots)
      media_type = extract_media_type(slots)

      if platform == :spotify
        search_type = { any: 'track,artist,album',
                        song: 'track',
                        artist: 'artist',
                        album: 'album',
                        playlist: 'playlist' }[media_type]
        media_entity = (slots['mediaEntity'] || []).join(' ')
        results = RSpotify::Base.search(media_entity, search_type)
        client.publish('home/media/spotify/pause', '')
        client.publish('home/media/spotify/playSong', results[0].uri)
        end_session(client, body)
      end
    end
  end

rescue RestClient::BadRequest => e
  puts e.message
  end_session(client, body, 'There was an error from the Spotify API', false)
end
