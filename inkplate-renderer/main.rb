require 'async'
require 'set'
require 'mustache'
require 'mqtt'

$stdout.sync = true
Thread.abort_on_exception = true

$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

BROKER_HOST = ENV['BROKER_HOST']
TEMPLATE_FILE = ENV['TEMPLATE_FILE'] || './template.mustache'

class View < Mustache
  self.template_file = TEMPLATE_FILE

  def initialize
    @subscriptions = {}
    render
  end

  def topics
    @subscriptions.keys
  end

  def []=(topic, value)
    @subscriptions[topic] = value
  end

  def method_missing(method, *args)
    @subscriptions[method.to_s]
  end

  def respond_to?(method)
    if method.to_s.include?('/')
      @subscriptions[method.to_s] ||= nil
      true
    else
      super
    end
  end
end

$logger.info("host=#{BROKER_HOST} status=connecting")
client = MQTT::Client.new(host: BROKER_HOST,
                          will_topic: 'home/inkplate/renderer/available',
                          will_payload: 'false',
                          will_retain: true)
client.connect
$logger.info("host=#{BROKER_HOST} status=connected")

view = View.new
client.subscribe(Hash[view.topics.map { |topic| [topic, 1] }]) unless view.topics.empty?

Async do |task|
  last_render = nil

  client.get do |topic, message|
    $logger.info("topic=#{topic} message=#{message}")
    if message == 'true' || message == 'home'
      view[topic] = true
    elsif message == 'false' || message == 'not_home'
      view[topic] = nil
    elsif message == 'unknown'
      next
    else
      view[topic] = message
    end

    last_render.stop if last_render
    last_render = task.async do
      sleep 1
      client.publish('home/inkplate/displayList', view.render, qos: 2)
      $logger.info("published")
    end
  end
end
