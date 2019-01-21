require 'mqtt'
require 'httparty'

describe 'main.rb' do
  let(:client) { instance_double(MQTT::Client) }
  let(:login_url) { 'http://projector-host/tgi/login.tgi' }
  let(:login_opts) { { body: { 'Username' => 1 }, timeout: 5 } }
  let(:login_response) { instance_double(HTTParty::Response) }
  let(:control_url) { 'http://projector-host/tgi/control.tgi' }
  let(:auth_token) { 'ATOP=asdf' }

  before(:all) do
    ENV['BROKER_HOST'] = 'broker-host'
    ENV['PROJECTOR_HOST'] = 'projector-host'
  end

  before(:each) do
    allow_any_instance_of(Logger).to receive(:level=)
    allow_any_instance_of(Logger).to receive(:info)
    allow(Thread).to receive(:new)
    allow(MQTT::Client).to receive(:new).and_return(client)
    allow(client).to receive(:connect)
    allow(client).to receive(:get)
    allow(HTTParty).to receive(:post).with(login_url, login_opts)
                                     .and_return(login_response)
    login_headers = { 'Set-Cookie' => auth_token }
    allow(login_response).to receive(:headers).and_return(login_headers)
  end

  after(:each) do
    load 'main.rb'
    Object.send(:remove_const, :BROKER_HOST)
    Object.send(:remove_const, :PROJECTOR_HOST)
    Object.send(:remove_const, :SOURCE_MAPPING)
  end

  it 'connects to the MQTT broker at BROKER_HOST' do
    mqtt_args = { host: 'broker-host',
                  will_topic: 'home/projector/available',
                  will_payload: 'false',
                  will_retain: true }
    expect(MQTT::Client).to receive(:new).with(mqtt_args).and_return(client)
    expect(client).to receive(:connect)
    expect(client).to receive(:get).with('home/projector/+')
  end

  it 'continues trying to log in to PROJECTOR_HOST until it receives a cookie' do
    response = instance_double(HTTParty::Response)
    expect(HTTParty).to receive(:post).twice
                                      .with(login_url, login_opts)
                                      .and_return(response)
    expect(response).to receive(:headers).and_return({},
                                                     { 'Set-Cookie' => 'ATOP=asdf' })
  end

  context 'when the topic ends in setInput' do
    it 'POSTs the input number as the src param' do
      control_opts = { body: { src: '1' },
                       headers: { 'Cookie' => auth_token },
                       timeout: 5 }
      expect(HTTParty).to receive(:post).with(control_url, control_opts)
      expect(client).to receive(:get).and_yield('home/projector/setInput', '1')
    end
  end

  context 'when the topic ends in setPower' do
    it 'POSTs "Power ON" if the message is "true"' do
      control_opts = { body: { pwr: 'Power ON' },
                       headers: { 'Cookie' => auth_token },
                       timeout: 5 }
      expect(HTTParty).to receive(:post).with(control_url, control_opts)
      expect(client).to receive(:get).and_yield('home/projector/setPower', 'true')
    end

    it 'POSTs "Power OFF" twice with a sleep in between if the message is "false"' do
      control_opts = { body: { pwr: 'Power OFF' },
                       headers: { 'Cookie' => auth_token },
                       timeout: 5 }
      expect(HTTParty).to receive(:post).with(control_url, control_opts).twice
      expect(Kernel).to receive(:sleep).with(1)
      expect(client).to receive(:get).and_yield('home/projector/setPower', 'false')
    end
  end

  context 'when the topic ends in setBrightness' do
    it 'passes a message on the brightness_queue' do
      brightness_queue = instance_double(Queue)
      expect(Queue).to receive(:new).and_return(brightness_queue)
      expect(brightness_queue).to receive(:push).with(60)
      expect(client).to receive(:get).and_yield('home/projector/setBrightness', '60')
    end
  end

  context 'polling the projector' do
    let(:query_opts) { { body: { 'QueryControl' => '' },
                         headers: { 'Cookie' => auth_token },
                         timeout: 5 } }
    before(:each) do
      allow(Kernel).to receive(:sleep)
    end

    it 'publishes power, input, and brightness only if they have changed' do
      # Yes, it's not real JSON
      query_response = '{pwr:"1",src:"6",bri:"50"}'
      expect(HTTParty).to receive(:post).with(control_url, query_opts)
                                        .and_return(query_response)
                                        .twice
      expect(client).to receive(:publish).twice.with('home/projector/available',
                                                     'true',
                                                     retain: true)
      expect(client).to receive(:publish).once.with('home/projector/power',
                                                    'true',
                                                    retain: true)
      expect(client).to receive(:publish).once.with('home/projector/input',
                                                    '1',
                                                    retain: true)
      expect(client).to receive(:publish).once.with('home/projector/brightness',
                                                    '50',
                                                    retain: true)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield.and_yield
    end

    it 'POSTs "bria" if power is on and desired_brightness > brightness' do
      allow(client).to receive(:publish)
      brightness_queue = instance_double(Queue)
      expect(Queue).to receive(:new).and_return(brightness_queue)
      expect(brightness_queue).to receive(:pop).and_return(60)

      query_response = '{pwr:"1",src:"6",bri:"50"}'
      expect(HTTParty).to receive(:post).with(control_url, query_opts)
                                        .and_return(query_response)

      control_opts = { body: { bria: '' },
                       headers: { 'Cookie' => auth_token },
                       timeout: 5 }
      expect(HTTParty).to receive(:post).with(control_url, control_opts)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield
      expect(Kernel).to receive(:sleep).with(0.1)
    end

    it 'POSTs "brid" if power is on and desired_brightness < brightness' do
      allow(client).to receive(:publish)
      brightness_queue = instance_double(Queue)
      expect(Queue).to receive(:new).and_return(brightness_queue)
      expect(brightness_queue).to receive(:pop).and_return(50)

      query_response = '{pwr:"1",src:"6",bri:"60"}'
      expect(HTTParty).to receive(:post).with(control_url, query_opts)
                            .and_return(query_response)

      control_opts = { body: { brid: '' },
                       headers: { 'Cookie' => auth_token },
                       timeout: 5 }
      expect(HTTParty).to receive(:post).with(control_url, control_opts)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield
      expect(Kernel).to receive(:sleep).with(0.1)
    end

    it 'does not POST if desired_brightness == brightness' do
      allow(client).to receive(:publish)
      brightness_queue = instance_double(Queue)
      expect(Queue).to receive(:new).and_return(brightness_queue)
      expect(brightness_queue).to receive(:pop).and_return(50)

      query_response = '{pwr:"1",src:"6",bri:"50"}'
      expect(HTTParty).to receive(:post).with(control_url, query_opts)
                                        .and_return(query_response)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield
      expect(Kernel).to receive(:sleep).with(2)
    end

    it 'does not POST if power is off' do
      allow(client).to receive(:publish)
      brightness_queue = instance_double(Queue)
      expect(Queue).to receive(:new).and_return(brightness_queue)
      expect(brightness_queue).to receive(:pop).and_return(60)

      query_response = '{pwr:"0",src:"6",bri:"50"}'
      expect(HTTParty).to receive(:post).with(control_url, query_opts)
                                        .and_return(query_response)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield
      expect(Kernel).to receive(:sleep).with(2)
    end

    it 'publishes "false" for the projector availability if the read times out' do
      expect(HTTParty).to receive(:post).with(control_url, query_opts)
                                        .and_raise(Net::OpenTimeout)
      expect(client).to receive(:publish).with('home/projector/available',
                                               'false',
                                               retain: true)
      expect(Thread).to receive(:new).and_yield
      expect(Kernel).to receive(:loop).and_yield
    end
  end
end
