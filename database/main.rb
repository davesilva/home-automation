require 'bundler/setup'
require 'mqtt'
require 'active_record'
require 'mini_record'

$stdout.sync = true
Thread.abort_on_exception = true

DATABASE_PATH = 'db/database.db'
BROKER_HOST = ENV['BROKER_HOST']

ActiveRecord::Base.logger = Logger.new(File.open('database.log', 'w'))

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: DATABASE_PATH
)

class DetectedSlot < ActiveRecord::Base
  field :raw_value, as: :text
  field :value, as: :text
  field :name, as: :text

  belongs_to :detected_intent
end

class DetectedIntent < ActiveRecord::Base
  field :session_id, as: :text
  field :site_id, as: :text
  field :input, as: :text
  field :intent_name, as: :text
  field :intent_probability, as: :decimal

  has_many :detected_slots

  def self.create_from_json(json)
    data = JSON.parse(json)
    intent = DetectedIntent.create(session_id: data['sessionId'],
                                   site_id: data['siteId'],
                                   input: data['input'],
                                   intent_name: data['intent']['intentName'],
                                   intent_probability: data['intent']['probability'])
    intent.detected_slots << data['slots'].map do |slot|
      DetectedSlot.create(name: slot['slotName'],
                          value: slot['value']['value'],
                          raw_value: slot['rawValue'])
    end

    intent
  end
end

ActiveRecord::Base.auto_upgrade!

puts "host=#{BROKER_HOST} status=connecting"
MQTT::Client.connect(BROKER_HOST) do |client|
  puts "host=#{BROKER_HOST} status=connected"

  client.subscribe('hermes/intent/#')

  client.get do |topic, message|
    DetectedIntent.create_from_json(message)
  end
end
