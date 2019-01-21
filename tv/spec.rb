require 'mqtt'

describe 'main.rb' do
  let(:client) { instance_double(MQTT::Client) }

  before(:all) do
    ENV['BROKER_HOST'] = 'broker-host'
  end

  before(:each) do
    allow_any_instance_of(Logger).to receive(:level=)
    allow_any_instance_of(Logger).to receive(:info)
    allow(MQTT::Client).to receive(:new).and_return(client)
    allow(client).to receive(:publish)
    allow(client).to receive(:connect)
    allow(client).to receive(:get)
  end

  after(:each) do
    Object.send(:remove_const, :BROKER_HOST)
  end

  it 'connects to the MQTT broker at BROKER_HOST' do
    mqtt_args = { host: 'broker-host',
                  will_topic: 'home/tv/available',
                  will_payload: 'false',
                  will_retain: true }
    expect(MQTT::Client).to receive(:new).with(mqtt_args).and_return(client)
    expect(client).to receive(:connect)
    expect(client).to receive(:get).with('home/tv/+')
    expect(client).to receive(:publish).with('home/tv/available',
                                             'true',
                                             retain: true)
    load 'main.rb'
  end

  context 'when the topic ends in setPower' do
    it 'sends the KEY_POWER command' do
      expect(client).to receive(:get).and_yield('home/tv/setPower', 'true')
      expect(Kernel).to receive(:system).with('irsend SEND_ONCE CT-90325 KEY_POWER')
      load 'main.rb'
    end
  end

  context 'when the topic ends in setVolume' do
    it 'sends KEY_VOLUMEUP twice if the message is "up"' do
      expect(client).to receive(:get).and_yield('home/tv/setVolume', 'up')
      expect(Kernel).to receive(:system)
                          .twice
                          .with('irsend SEND_ONCE CT-90325 KEY_VOLUMEUP')
      load 'main.rb'
    end

    it 'sends KEY_VOLUMEUP followed by KEY_VOLUMEDOWN if the message is "down"' do
      expect(client).to receive(:get).and_yield('home/tv/setVolume', 'down')
      expect(Kernel).to receive(:system)
                          .with('irsend SEND_ONCE CT-90325 KEY_VOLUMEUP')
                          .ordered
      expect(Kernel).to receive(:system)
                          .with('irsend SEND_ONCE CT-90325 KEY_VOLUMEDOWN')
                          .ordered
      load 'main.rb'
    end

    it 'does not send the initial KEY_VOLUMEUP if the command is repeated immediately' do
      expect(client).to receive(:get).and_yield('home/tv/setVolume', 'down')
                                     .and_yield('home/tv/setVolume', 'down')
      expect(Kernel).to receive(:system)
                          .with('irsend SEND_ONCE CT-90325 KEY_VOLUMEUP')
                          .ordered
      expect(Kernel).to receive(:system)
                          .with('irsend SEND_ONCE CT-90325 KEY_VOLUMEDOWN')
                          .twice
                          .ordered
      load 'main.rb'
    end
  end

  context 'when the topic ends in setChannel' do
    it 'sends KEY_CHANNELUP if the message is "up"' do
      expect(client).to receive(:get).and_yield('home/tv/setChannel', 'up')
      expect(Kernel).to receive(:system)
                          .with('irsend SEND_ONCE CT-90325 KEY_CHANNELUP')
      load 'main.rb'
    end

    it 'sends KEY_CHANNELDOWN if the message is "down"' do
      expect(client).to receive(:get).and_yield('home/tv/setChannel', 'down')
      expect(Kernel).to receive(:system)
                          .with('irsend SEND_ONCE CT-90325 KEY_CHANNELDOWN')
      load 'main.rb'
    end
  end

  context 'when the topic ends in setInput' do
    (0..4).each do |input|
      it "sends KEY_CYCLEWINDOWS followed by KEY_#{input} for input #{input}" do
        expect(client).to receive(:get).and_yield('home/tv/setInput', input.to_s)
        expect(Kernel).to receive(:system)
                            .with('irsend SEND_ONCE CT-90325 KEY_CYCLEWINDOWS')
        expect(Kernel).to receive(:sleep).with(0.5)
        expect(Kernel).to receive(:system)
                            .with("irsend SEND_ONCE CT-90325 KEY_#{input}")
        load 'main.rb'
      end
    end
  end
end
