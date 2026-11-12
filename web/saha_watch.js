// Montre connectée réelle : lecture d'un capteur de fréquence cardiaque Bluetooth
// (profil standard « Heart Rate », service 0x180D) avec l'API Web Bluetooth de Chrome.
// Une Apple Watch devient un tel capteur grâce à une application de diffusion
// installée sur l'iPhone (HeartCast, Echo, BlueHeart…).
(function () {
  let device = null;
  let characteristic = null;
  const queue = [];
  const state = { status: 'idle', name: '', error: '' };

  function onValue(event) {
    const value = event.target.value;
    const flags = value.getUint8(0);
    // Bit 0 des indicateurs : valeur sur 16 bits (1) ou 8 bits (0)
    const bpm = flags & 1 ? value.getUint16(1, true) : value.getUint8(1);
    if (bpm > 0) queue.push(bpm);
  }

  window.sahaWatch = {
    supported: () => !!navigator.bluetooth,
    state: () => JSON.stringify(state),
    connect: async () => {
      state.status = 'connecting';
      state.error = '';
      try {
        device = await navigator.bluetooth.requestDevice({ filters: [{ services: ['heart_rate'] }] });
        device.addEventListener('gattserverdisconnected', () => {
          state.status = 'disconnected';
        });
        const server = await device.gatt.connect();
        const service = await server.getPrimaryService('heart_rate');
        characteristic = await service.getCharacteristic('heart_rate_measurement');
        characteristic.addEventListener('characteristicvaluechanged', onValue);
        await characteristic.startNotifications();
        state.name = device.name || 'Capteur cardiaque';
        state.status = 'connected';
        return state.name;
      } catch (error) {
        state.status = 'error';
        state.error = String((error && error.message) || error);
        throw error;
      }
    },
    disconnect: () => {
      try {
        if (device && device.gatt.connected) device.gatt.disconnect();
      } catch (_) {}
      queue.length = 0;
      state.status = 'idle';
    },
    // Valeurs reçues depuis le dernier appel
    drain: () => JSON.stringify(queue.splice(0)),
  };
})();
