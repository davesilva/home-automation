require 'mqtt'
require 'httparty'

describe 'main.rb' do
  let(:client) { instance_double(MQTT::Client) }

  before(:all) do
    ENV['BROKER_HOST'] = 'broker-host'
    ENV['VOLUME_HOST'] = 'volume-host'
  end

  before(:each) do
    allow_any_instance_of(Logger).to receive(:level=)
    allow_any_instance_of(Logger).to receive(:info)
    allow(Thread).to receive(:new)
    allow(MQTT::Client).to receive(:new).and_return(client)
    allow(HTTParty).to receive(:get)
    allow(HTTParty).to receive(:post)
    allow(client).to receive(:connect)
    allow(client).to receive(:get)
  end

  after(:each) do
    Object.send(:remove_const, :BROKER_HOST)
    Object.send(:remove_const, :VOLUME_HOST)
  end

  it 'connects to the MQTT broker at BROKER_HOST' do
    mqtt_args = { host: 'broker-host',
                  will_topic: 'home/speakers/available',
                  will_payload: 'false',
                  will_retain: true }
    expect(MQTT::Client).to receive(:new).with(mqtt_args).and_return(client)
    expect(client).to receive(:connect)
    expect(client).to receive(:get).with('home/speakers/+')
    load 'main.rb'
  end

  context 'when the topic ends in setPower' do
    it 'makes a POST request to the speakers when the message is "true"' do
      expect(client).to receive(:get).and_yield('home/speakers/setPower', 'true')
      expect(HTTParty).to receive(:post).with('http://volume-host/speakers',
                                              body: { power: true },
                                              timeout: 5)
      load 'main.rb'
    end

    it 'makes a POST request to the speakers when the message is "false"' do
      expect(client).to receive(:get).and_yield('home/speakers/setPower', 'false')
      expect(HTTParty).to receive(:post).with('http://volume-host/speakers',
                                              body: { power: false },
                                              timeout: 5)
      load 'main.rb'
    end
  end

  context 'when the topic ends in setVolume' do
    it 'makes a POST request to the speakers with the new volume' do
      expect(client).to receive(:get).and_yield('home/speakers/setVolume', '45')
      expect(HTTParty).to receive(:post).with('http://volume-host/speakers',
                                              body: { power: true, volume: 45 },
                                              timeout: 5)
      load 'main.rb'
    end
  end

  context 'polling the speakers' do
    before(:each) do
      allow(Kernel).to receive(:sleep)
    end

    it 'publishes the power state and volume only if they have changed' do
      expect(HTTParty).to receive(:get).and_return({ 'power' => true, 'volume' => 50 },
                                                   { 'power' => true, 'volume' => 50 })
      expect(client).to receive(:publish).twice.with('home/speakers/available',
                                                     'true',
                                                     retain: true)
      expect(client).to receive(:publish).once.with('home/speakers/power',
                                                    'true',
                                                    retain: true)
      expect(client).to receive(:publish).once.with('home/speakers/volume',
                                                    '50',
                                                    retain: true)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield.and_yield
      load 'main.rb'
    end

    it 'publishes "false" for the speaker availability if the read times out' do
      expect(HTTParty).to receive(:get).and_raise(Net::OpenTimeout)
      expect(client).to receive(:publish).with('home/speakers/available',
                                               'false',
                                               retain: true)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield
      load 'main.rb'
    end
  end
end
