const _ = require('lodash');
const Mopidy = require('mopidy');
const MQTT = require('async-mqtt');
const { once } = require('events');

const { MOPIDY_HOST, MQTT_BROKER } = process.env;

const connect = () => {
  const mopidy = new Mopidy({
    webSocketUrl: `ws://${MOPIDY_HOST}:6680/mopidy/ws/`
  });

  return Promise.all([
    MQTT.connectAsync(`mqtt://${MQTT_BROKER}`),
    once(mopidy, 'state:online').then(_.constant(mopidy))
  ]);
};

connect().then(([mqttClient, mopidy]) => {
  console.log('Connected');

  mqttClient.subscribe('home/media/spotify/#');

  mopidy.on('event', console.log);
  mopidy.on('error', console.error);

  mqttClient.on('message', async (topic, message) => {
    console.log(topic)
    switch (_.last(topic.split('/'))) {
    case 'playSong':
      const [tlTrack] = await mopidy.tracklist.add({ uri: message.toString() });
      await mopidy.playback.play({ tlid: tlTrack.tlid });
      break;
    case 'pause':
      await mopidy.playback.pause();
      break;
    case 'resume':
      await mopidy.playback.play();
      break;
    }
  });

  const publishCurrentTrack = event => {
    mqttClient.publish(
      'home/media/spotify/currentTrack',
      JSON.stringify(event.tl_track.track),
      { retain: true }
    );
  };
  const clearCurrentTrack = event => {
    mqttClient.publish(
      'home/media/spotify/currentTrack',
      '',
      { retain: true }
    );
  };

  mopidy.on('event:playbackStateChanged', event => {
    mqttClient.publish(
      'home/media/spotify/playbackState',
      event.new_state,
      { retain: true }
    );
  });
  mopidy.on('event:trackPlaybackStarted', publishCurrentTrack);
  mopidy.on('event:trackPlaybackResumed', publishCurrentTrack);
  mopidy.on('event:trackPlaybackPaused', publishCurrentTrack);
  mopidy.on('event:trackPlaybackEnded', clearCurrentTrack);
});
