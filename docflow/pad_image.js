const { Jimp } = require('jimp');

(async function() {
  try {
    const image = await Jimp.read('assets/logo/app_icon-Photoroom.png');
    // Create a 2400x2400 white background
    const newImage = new Jimp({ width: 2400, height: 2400, color: '#ffffff' });
    // Composite the 2400x1200 image in the middle (y=600)
    newImage.composite(image, 0, 600);
    await newImage.write('assets/logo/app_icon_square.png');
    console.log('Done!');
  } catch (e) {
    console.error(e);
  }
})();
