const client = window.mqtt.connect('mqtt://192.168.1.8:9001');

$(window).keydown(function(event){
  if(event.keyCode == 13) {
    event.preventDefault();
    return false;
  }
});

$(document).ready(() => {
  const $speakerPower = $("input[name=speaker_power]");
  const $speakerVolume = $("input[name=speaker_volume]");
  const $projectorPower = $("input[name=projector_power]");
  const $hdmiInput = $("input[name=hdmi_input]");

  $speakerVolume.TouchSpin({
    min: 0,
    max: 70,
    step: 1,
    booster: false,
    mousewheel: false
  });

  client.on('connect', () => client.subscribe('home/#'));

  client.on('message', (topic, message) => {
    console.log(`${topic}: ${message}`);

    switch (topic) {
    case 'home/speakers/power':
      $speakerPower.val([message]);
      break;
    case 'home/speakers/volume':
      $speakerVolume.val(message);
      break;
    case 'home/projector/power':
      $projectorPower.val([message]);
      break;
    case 'home/projector/input':
      console.log(`Projector input: ${message}`);
      break;
    case 'home/hdmiSwitch/input':
      $hdmiInput.val([message]);
      break;
    }
  });

  $speakerPower.change(() => {
    client.publish('home/speakers/setPower', $speakerPower.filter(':checked').val());
  });

  $speakerVolume.change(() => {
    client.publish('home/speakers/setVolume', $speakerVolume.val());
  });
  $speakerVolume.keydown(event => {
    if(event.keyCode == 13) {
      client.publish('home/speakers/setVolume', $speakerVolume.val());
      event.preventDefault();
      return false;
    }
    return true;
  });
  $speakerVolume.on('mouseup', () => $speakerVolume.select());

  $projectorPower.change(() => {
    client.publish('home/projector/setPower', $projectorPower.filter(':checked').val());
  });

  $hdmiInput.change(() => {
    client.publish('home/hdmiSwitch/setInput', $hdmiInput.filter(':checked').val());
  });
});
