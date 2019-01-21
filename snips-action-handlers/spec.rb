require 'mqtt'
require 'json'

describe 'main.rb' do
  let(:client) { instance_double(MQTT::Client) }

  before(:all) do
    ENV['BROKER_HOST'] = 'broker-host'
  end

  before(:each) do
    allow_any_instance_of(Logger).to receive(:level=)
    allow_any_instance_of(Logger).to receive(:info)
    allow(MQTT::Client).to receive(:connect).and_yield(client)
    allow(client).to receive(:subscribe)
    allow(client).to receive(:publish)
    allow(client).to receive(:connect)
    allow(client).to receive(:get)
  end

  after(:each) do
    load 'main.rb'
    Object.send(:remove_const, :BROKER_HOST)
    Object.send(:remove_const, :PROBABILITY_THRESHOLD)
    Object.send(:remove_const, :CONFIRM_SOUND_EFFECT)
    Object.send(:remove_const, :ERROR_SOUND_EFFECT)
  end

  it 'connects to the MQTT broker at BROKER_HOST' do
    expect(MQTT::Client).to receive(:connect).with('broker-host').and_yield(client)
    expect(client).to receive(:subscribe).with('home/speakers/volume',
                                               'hermes/intent/+',
                                               'hermes/dialogueManager/sessionEnded')
  end

  context 'when the intent probability is above the threshold' do
    it 'plays a confirmation sound' do
      message = { siteId: 'projector-room',
                  sessionId: 'asdf',
                  intent: { probability: 0.8 },
                  slots: [] }.to_json
      sound = File.open('confirm.wav').read
      expect(client).to receive(:get).and_yield('hermes/intent/davesilva:someIntent',
                                                message)
      expect(client).to receive(:publish)
                          .with('hermes/audioServer/projector-room/playBytes/asdf',
                                sound)
    end
  end

  context 'when the intent probability is below the threshold' do
    it 'plays an error sound' do
      message = { siteId: 'projector-room',
                  sessionId: 'asdf',
                  intent: { probability: 0.4 },
                  slots: [] }.to_json
      sound = File.open('error.wav').read
      expect(client).to receive(:get).and_yield('hermes/intent/davesilva:someIntent',
                                                message)
      expect(client).to receive(:publish)
                          .with('hermes/audioServer/projector-room/playBytes/asdf',
                                sound)
    end
  end

  context 'when the dialogue manager returns an error' do
    it 'plays an error sound' do
      message = { siteId: 'projector-room',
                  sessionId: 'asdf',
                  termination: { reason: 'error' } }.to_json
      sound = File.open('error.wav').read
      expect(client).to receive(:get).and_yield('hermes/dialogueManager/sessionEnded',
                                                message)
      expect(client).to receive(:publish)
                          .with('hermes/audioServer/projector-room/playBytes/asdf',
                                sound)
    end
  end

  context 'when the topic ends in davesilva:volumeUp' do
    context 'and the siteId is "projector-room"' do
      it 'publishes on home/speakers/setVolume' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:volumeUp',
                                                  message)
        expect(client).to receive(:publish).with('home/speakers/setVolume', '2')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'modifies the previous volume' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('home/speakers/volume', '50')
                                       .and_yield('hermes/intent/davesilva:volumeUp',
                                                  message)
        expect(client).to receive(:publish).with('home/speakers/setVolume', '52')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'raises the volume by 1 if amount is "a little"' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'amount',
                              value: { value: 'a little' } }] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:volumeUp',
                                                  message)
        expect(client).to receive(:publish).with('home/speakers/setVolume', '1')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'raises the volume by 4 if amount is "a lot"' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'amount',
                              value: { value: 'a lot' } }] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:volumeUp',
                                                  message)
        expect(client).to receive(:publish).with('home/speakers/setVolume', '4')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'raises the volume by 8 if amount is "a whole lot"' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'amount',
                              value: { value: 'a whole lot' } }] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:volumeUp',
                                                  message)
        expect(client).to receive(:publish).with('home/speakers/setVolume', '8')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end

    context 'and the siteId is "tv-room"' do
      it 'publishes on home/tv/setVolume' do
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:volumeUp',
                                                  message)
        expect(client).to receive(:publish).with('home/tv/setVolume', 'up').twice
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end
  end

  context 'when the topic ends in davesilva:volumeDown' do
    context 'and the siteId is "projector-room"' do
      it 'does not go below 0' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:volumeDown',
                                                  message)
        expect(client).to receive(:publish).with('home/speakers/setVolume', '0')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'modifies the previous volume' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('home/speakers/volume', '50')
                                       .and_yield('hermes/intent/davesilva:volumeDown',
                                                  message)
        expect(client).to receive(:publish).with('home/speakers/setVolume', '48')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end

    context 'and the siteId is "tv-room"' do
      it 'publishes on home/tv/setVolume' do
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:volumeDown',
                                                  message)
        expect(client).to receive(:publish).with('home/tv/setVolume', 'down').twice
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end
  end

  context 'when the topic ends in davesilva:screenOn' do
    context 'and the siteId is "projector-room"' do
      it 'publishes on home/projector/setPower' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOn',
                                                  message)
        expect(client).to receive(:publish).with('home/projector/setPower', 'true')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'publishes on home/tv/setPower if device == "TV"' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'device', value: { value: 'TV' } }] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOn',
                                                  message)
        expect(client).to receive(:publish).with('home/tv/setPower', 'true')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end

    context 'and the siteId is "tv-room"' do
      it 'publishes on home/tv/setPower' do
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOn',
                                                  message)
        expect(client).to receive(:publish).with('home/tv/setPower', 'true')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'publishes on home/projector/setPower if device == "projector"' do
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'device', value: { value: 'projector' } }] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOn',
                                                  message)
        expect(client).to receive(:publish).with('home/projector/setPower', 'true')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end
  end

  context 'when the topic ends in davesilva:screenOff' do
    context 'and the siteId is "projector-room"' do
      it 'publishes on home/projector/setPower' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOff',
                                                  message)
        expect(client).to receive(:publish).with('home/projector/setPower', 'false')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'publishes on home/tv/setPower if device == "TV"' do
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'device',
                              value: { value: 'TV' } }] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOff',
                                                  message)
        expect(client).to receive(:publish).with('home/tv/setPower', 'false')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end

    context 'and the siteId is "tv-room"' do
      it 'publishes on home/tv/setPower' do
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOff',
                                                  message)
        expect(client).to receive(:publish).with('home/tv/setPower', 'false')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'publishes on home/projector/setPower if device == "projector"' do
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'device',
                              value: { value: 'projector' } }] }.to_json
        expect(client).to receive(:get).and_yield('hermes/intent/davesilva:screenOff',
                                                  message)
        expect(client).to receive(:publish).with('home/projector/setPower', 'false')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end
  end

  context 'when the topic ends in davesilva:switchVideoInput' do
    context 'and the siteId is projector-room' do
      it 'publishes on home/hdmiSwitch/setInput when given a number' do
        topic = 'hermes/intent/davesilva:switchVideoInput'
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'inputNumber',
                              value: { value: '1' } }] }.to_json
        expect(client).to receive(:get).and_yield(topic, message)
        expect(client).to receive(:publish).with('home/projector/setPower', 'true')
        expect(client).to receive(:publish).with('home/hdmiSwitch/setInput', '1')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'publishes on home/hdmiSwitch/setInput when given a device name' do
        topic = 'hermes/intent/davesilva:switchVideoInput'
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'inputName',
                              value: { value: 'Chromecast' } }] }.to_json
        expect(client).to receive(:get).and_yield(topic, message)
        expect(client).to receive(:publish).with('home/projector/setPower', 'true')
        expect(client).to receive(:publish).with('home/hdmiSwitch/setInput', '8')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'does not publish if not given a name or number' do
        topic = 'hermes/intent/davesilva:switchVideoInput'
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield(topic, message)
        expect(client).to_not receive(:publish).with('home/projector/setPower', 'true')
        expect(client).to_not receive(:publish).with('home/hdmiSwitch/setInput',
                                                     anything)
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'does not switch to an input number that is out of range' do
        topic = 'hermes/intent/davesilva:switchVideoInput'
        message = { siteId: 'projector-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'inputNumber',
                              value: { value: '100' } }] }.to_json
        expect(client).to receive(:get).and_yield(topic, message)
        expect(client).to_not receive(:publish).with('home/projector/setPower', 'true')
        expect(client).to_not receive(:publish).with('home/hdmiSwitch/setInput',
                                                     anything)
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end

    context 'and the siteId is tv-room' do
      it 'publishes on home/tv/setInput when given an input number' do
        topic = 'hermes/intent/davesilva:switchVideoInput'
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'inputNumber',
                              value: { value: '0' } }] }.to_json
        expect(client).to receive(:get).and_yield(topic, message)
        expect(client).to receive(:publish).with('home/tv/setInput', '0')
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'does not publish if not given an input number' do
        topic = 'hermes/intent/davesilva:switchVideoInput'
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [] }.to_json
        expect(client).to receive(:get).and_yield(topic, message)
        expect(client).to_not receive(:publish).with('home/tv/setInput', anything)
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end

      it 'does not switch to an input number that is out of range' do
        topic = 'hermes/intent/davesilva:switchVideoInput'
        message = { siteId: 'tv-room',
                    sessionId: 'asdf',
                    intent: { probability: 0.8 },
                    slots: [{ slotName: 'inputNumber',
                              value: { value: '5' } }] }.to_json
        expect(client).to receive(:get).and_yield(topic, message)
        expect(client).to_not receive(:publish).with('home/tv/setInput', anything)
        expect(client).to receive(:publish).with('hermes/dialogueManager/endSession',
                                                 { sessionId: 'asdf' }.to_json)
      end
    end
  end
end
