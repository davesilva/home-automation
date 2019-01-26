const MIN_VOLUME = 0;
const MAX_VOLUME = 70;

const client = window.mqtt.connect('mqtt://192.168.1.8:9001');

const app = new Vue({
  el: '#main',
  data: {
    speakers: {
      available: false,
      power: false,
      volume: 0
    },
    projector: {
      available: false,
      power: false,
      input: 1
    },
    hdmiSwitch: {
      available: false,
      input: 1
    },
    tv: {
      available: false
    }
  },
  methods: {
    setProjectorPower: power => {
      app.projector.power = power;
      client.publish('home/projector/setPower', String(power));
    },
    setSpeakerVolume: event => {
      app.speakers.volume = Number(event.target.value);
      client.publish('home/speakers/setVolume', event.target.value);
    },
    speakerVolumeUp: () => {
      const volume = Math.min(app.speakers.volume + 1, MAX_VOLUME);
      app.speakers.volume = volume;
      client.publish('home/speakers/setVolume', String(volume));
    },
    speakerVolumeDown: () => {
      const volume = Math.max(app.speakers.volume - 1, MIN_VOLUME);
      app.speakers.volume = volume;
      client.publish('home/speakers/setVolume', String(volume));
    },
    setHdmiSwitchInput: input => {
      app.hdmiSwitch.input = input;
      client.publish('home/hdmiSwitch/input', String(input));
    },
    sendTV: (topic, message) => {
      client.publish(`home/tv/${topic}`, message);
    }
  }
});

client.on('connect', () => client.subscribe('home/#'));

client.on('message', (topic, message) => {
  console.log(`${topic}: ${message}`);

  switch (topic) {
  case 'home/speakers/power':
    app.speakers.power = String(message) === 'true';
    break;
  case 'home/speakers/volume':
    app.speakers.volume = Number(message);
    break;
  case 'home/speakers/available':
    app.speakers.available = String(message) === 'true';
    break;
  case 'home/projector/power':
    app.projector.power = String(message) === 'true';
    break;
  case 'home/projector/input':
    app.projector.input = Number(message);
    break;
  case 'home/projector/available':
    app.projector.available = String(message) === 'true';
    break;
  case 'home/hdmiSwitch/input':
    app.hdmiSwitch.input = Number(message);
    break;
  case 'home/hdmiSwitch/available':
    app.hdmiSwitch.available = String(message) === 'true';
    break;
  case 'home/tv/available':
    app.tv.available = String(message) === 'true';
    break;
  }
});