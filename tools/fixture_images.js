/**
 * Generates the fixture images the seed uploads to Cloud Storage.
 *
 * Written in code rather than checked in as .png files for two reasons: binary
 * fixtures rot silently in a repo, and a reviewer cannot tell what is in them.
 * These are deliberately plain: a flat brand colour with a darker border, at the
 * real dimensions the field names claim. Enough to prove that a Storage PATH
 * resolves, renders, and comes back from the cache on the second look.
 *
 * No image library, so the PNGs are assembled by hand. Node's zlib does the
 * only hard part.
 */
const zlib = require('zlib');

// ── CRC32, which every PNG chunk needs ──────────────────────────────────────
const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const typeAndData = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(typeAndData), 0);
  return Buffer.concat([length, typeAndData, crc]);
}

/**
 * A solid PNG with a border, so a rendered fixture is obviously a fixture and
 * not a broken image.
 *
 * @param {number} width
 * @param {number} height
 * @param {[number,number,number]} fill    body colour, RGB 0-255
 * @param {[number,number,number]} border  border colour, RGB 0-255
 * @param {number} borderWidth
 */
function solidPng(width, height, fill, border, borderWidth = 8) {
  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 2;  // colour type 2 = truecolour RGB
  ihdr[10] = 0; // deflate
  ihdr[11] = 0; // adaptive filtering
  ihdr[12] = 0; // no interlace

  // One filter byte per scanline, then RGB triples.
  const raw = Buffer.alloc(height * (1 + width * 3));
  let offset = 0;
  for (let y = 0; y < height; y++) {
    raw[offset++] = 0; // filter type: none
    for (let x = 0; x < width; x++) {
      const onBorder =
        x < borderWidth ||
        y < borderWidth ||
        x >= width - borderWidth ||
        y >= height - borderWidth;
      const [r, g, b] = onBorder ? border : fill;
      raw[offset++] = r;
      raw[offset++] = g;
      raw[offset++] = b;
    }
  }

  return Buffer.concat([
    signature,
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ThinkTac palette, so a fixture on screen still looks like this app.
const SKY = [4, 156, 216];
const NAVY = [40, 43, 102];
const WHITE = [255, 255, 255];

/**
 * The fixture set, keyed by the role each one plays.
 *
 * Dimensions match what the field names claim: the preview is the 200x200 the
 * seeded file name advertises, the step illustration is a landscape image big
 * enough that caching it actually matters.
 */
function fixtures() {
  return {
    preview: { bytes: solidPng(200, 200, SKY, NAVY), contentType: 'image/png' },
    stepImage: { bytes: solidPng(800, 600, NAVY, SKY), contentType: 'image/png' },
    materialList: { bytes: solidPng(600, 400, WHITE, SKY), contentType: 'image/png' },
  };
}

module.exports = { fixtures, solidPng };
