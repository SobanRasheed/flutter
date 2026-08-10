/**
 * Test inputs, generated rather than committed — no binaries in the repo, and
 * the engine test stays runnable on a fresh clone.
 *
 * Everything here is hand-assembled bytes: a minimal PDF writer, a minimal
 * DOCX (which is just a zip of XML), and a PNG encoder. That keeps the test
 * dependency-free, and it means the fixtures are readable when a test fails.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

/** Assembles a PDF from a list of already-serialized objects. */
function buildPdf(objects) {
  const header = '%PDF-1.7\n';
  let body = '';
  const offsets = [];
  objects.forEach((obj, i) => {
    offsets.push(header.length + body.length);
    body += `${i + 1} 0 obj\n${obj}\nendobj\n`;
  });
  const xrefAt = header.length + body.length;
  let xref = `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const off of offsets) xref += `${String(off).padStart(10, '0')} 00000 n \n`;
  const trailer =
    `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefAt}\n%%EOF\n`;
  return Buffer.from(header + body + xref + trailer, 'latin1');
}

/** A text PDF with `pages` pages, each carrying a legible line of prose. */
function textPdf(pages, label) {
  const kids = [];
  const objects = [null, null];
  for (let p = 0; p < pages; p++) {
    const contentId = 3 + p * 2;
    const pageId = contentId + 1;
    const text =
      `BT /F1 18 Tf 64 700 Td (${label} - page ${p + 1}) Tj ET\n` +
      `BT /F1 11 Tf 64 660 Td (Lorem ipsum dolor sit amet, consectetur adipiscing elit.) Tj ET\n` +
      `BT /F1 11 Tf 64 640 Td (Sed do eiusmod tempor incididunt ut labore et dolore magna.) Tj ET`;
    objects[contentId - 1] = `<< /Length ${text.length} >>\nstream\n${text}\nendstream`;
    objects[pageId - 1] =
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ` +
      `/Resources << /Font << /F1 ${3 + pages * 2} 0 R >> >> ` +
      `/Contents ${contentId} 0 R >>`;
    kids.push(`${pageId} 0 R`);
  }
  objects[0] = '<< /Type /Catalog /Pages 2 0 R >>';
  objects[1] = `<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages} >>`;
  objects[3 + pages * 2 - 1] =
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';
  return buildPdf(objects);
}

/** CRC-32, for PNG chunks and zip entries. */
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

/** Encodes raw RGB rows as a PNG. */
function encodePng(width, height, pixelAt) {
  const raw = Buffer.alloc(height * (1 + width * 3));
  let o = 0;
  for (let y = 0; y < height; y++) {
    raw[o++] = 0;
    for (let x = 0; x < width; x++) {
      const [r, g, b] = pixelAt(x, y);
      raw[o++] = r;
      raw[o++] = g;
      raw[o++] = b;
    }
  }
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, 'latin1'), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body));
    return Buffer.concat([len, body, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/** A photo-like PNG: smooth gradients plus noise, so it resists compression. */
function noisyPng(width, height, seed) {
  let s = seed;
  const rand = () => ((s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  return encodePng(width, height, (x, y) => [
    Math.min(255, (x / width) * 200 + rand() * 55),
    Math.min(255, (y / height) * 200 + rand() * 55),
    Math.min(255, ((x + y) / (width + height)) * 200 + rand() * 55),
  ]);
}

/** Minimal store-only zip writer, enough for a valid DOCX. */
function zip(entries) {
  const locals = [];
  const central = [];
  let offset = 0;
  for (const [name, content] of entries) {
    const nameBuf = Buffer.from(name, 'utf8');
    const data = Buffer.from(content, 'utf8');
    const crc = crc32(data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(data.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    locals.push(local, nameBuf, data);

    const dir = Buffer.alloc(46);
    dir.writeUInt32LE(0x02014b50, 0);
    dir.writeUInt16LE(20, 4);
    dir.writeUInt16LE(20, 6);
    dir.writeUInt32LE(crc, 16);
    dir.writeUInt32LE(data.length, 20);
    dir.writeUInt32LE(data.length, 24);
    dir.writeUInt16LE(nameBuf.length, 28);
    dir.writeUInt32LE(offset, 42);
    central.push(dir, nameBuf);
    offset += 30 + nameBuf.length + data.length;
  }
  const centralBuf = Buffer.concat(central);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(entries.length, 8);
  eocd.writeUInt16LE(entries.length, 10);
  eocd.writeUInt32LE(centralBuf.length, 12);
  eocd.writeUInt32LE(offset, 16);
  return Buffer.concat([Buffer.concat(locals), centralBuf, eocd]);
}

function docx(paragraphs) {
  const body = paragraphs
    .map((t) => `<w:p><w:r><w:t xml:space="preserve">${t}</w:t></w:r></w:p>`)
    .join('');
  return zip([
    [
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
        '<Default Extension="xml" ContentType="application/xml"/>' +
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>' +
        '</Types>',
    ],
    [
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>' +
        '</Relationships>',
    ],
    [
      'word/document.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">' +
        `<w:body>${body}</w:body></w:document>`,
    ],
  ]);
}

/** An image-heavy PDF — the only kind where compression levels differ. */
function photoPdf(images) {
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    null,
    null,
    null,
  ];
  const kids = [];
  let next = 3;
  const pageRefs = [];
  for (const png of images) {
    const imgId = next++;
    const contentId = next++;
    const pageId = next++;
    // DCTDecode is not right for PNG, so embed as a raw Flate-compressed
    // stream: Stirling only needs a real image XObject to work on.
    objects[imgId - 1] =
      `<< /Type /XObject /Subtype /Image /Width ${png.width} /Height ${png.height} ` +
      `/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode ` +
      `/Length ${png.flate.length} >>\nstream\n${png.flate.toString('latin1')}\nendstream`;
    const content = `q 500 0 0 700 48 70 cm /Im0 Do Q`;
    objects[contentId - 1] = `<< /Length ${content.length} >>\nstream\n${content}\nendstream`;
    objects[pageId - 1] =
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ` +
      `/Resources << /XObject << /Im0 ${imgId} 0 R >> >> /Contents ${contentId} 0 R >>`;
    kids.push(`${pageId} 0 R`);
    pageRefs.push(pageId);
  }
  objects[1] = `<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pageRefs.length} >>`;
  return buildPdf(objects.filter((o) => o !== null || true).slice(0, next - 1));
}

/** Raw RGB bytes, Flate-compressed, for embedding straight into a PDF. */
function rawImage(width, height, seed) {
  let s = seed;
  const rand = () => ((s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff);
  const raw = Buffer.alloc(width * height * 3);
  let o = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      raw[o++] = Math.min(255, (x / width) * 200 + rand() * 55);
      raw[o++] = Math.min(255, (y / height) * 200 + rand() * 55);
      raw[o++] = Math.min(255, ((x + y) / (width + height)) * 200 + rand() * 55);
    }
  }
  return { width, height, flate: zlib.deflateSync(raw) };
}

/**
 * Writes every fixture into `dir` and returns a few measurements the engine
 * test asserts against.
 */
export function makeFixtures(dir) {
  fs.mkdirSync(dir, { recursive: true });
  const write = (name, buf) => {
    fs.writeFileSync(path.join(dir, name), buf);
    return buf.length;
  };

  // 6 pages: split with pages '2,4' needs room, and pdf-to-image asserts a
  // 6-entry zip.
  const samplePdfBytes = write('sample.pdf', textPdf(6, 'DocFlow engine test'));
  write('merge-a.pdf', textPdf(1, 'Merge input A'));
  write('merge-b.pdf', textPdf(2, 'Merge input B'));
  write('sample.docx', docx([
    'DocFlow engine contract test',
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    'This document exists so word-to-pdf has real input.',
  ]));
  write('img-a.png', noisyPng(240, 320, 7));
  write('img-b.png', noisyPng(240, 320, 99));
  const photoPdfBytes = write(
    'photo.pdf',
    photoPdf([rawImage(420, 560, 3), rawImage(420, 560, 11)]),
  );

  return { dir, samplePdfBytes, photoPdfBytes };
}
