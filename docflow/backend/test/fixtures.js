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

/**
 * A text PDF with `pages` pages, each carrying a legible line of prose. Pages
 * after `textPages` get an empty content stream — renders pure white, which is
 * what remove-blank-pages is supposed to detect and drop.
 */
function textPdf(pages, label, textPages = Infinity) {
  const kids = [];
  const objects = [null, null];
  for (let p = 0; p < pages; p++) {
    const contentId = 3 + p * 2;
    const pageId = contentId + 1;
    const text =
      p >= textPages
        ? ''
        : `BT /F1 18 Tf 64 700 Td (${label} - page ${p + 1}) Tj ET\n` +
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

/** A text PDF with an outline, so split-by-chapters has chapters to split on. */
function chapterPdf(pages, label, chapters) {
  const objects = [null, null];
  const kids = [];
  const fontId = 3 + pages * 2;
  const pageIds = [];
  for (let p = 0; p < pages; p++) {
    const contentId = 3 + p * 2;
    const pageId = contentId + 1;
    const text = `BT /F1 18 Tf 64 700 Td (${label} - page ${p + 1}) Tj ET`;
    objects[contentId - 1] = `<< /Length ${text.length} >>\nstream\n${text}\nendstream`;
    objects[pageId - 1] =
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] ` +
      `/Resources << /Font << /F1 ${fontId} 0 R >> >> /Contents ${contentId} 0 R >>`;
    kids.push(`${pageId} 0 R`);
    pageIds.push(pageId);
  }
  objects[1] = `<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages} >>`;
  objects[fontId - 1] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';

  const rootId = fontId + 1;
  const itemIds = chapters.map((_, i) => rootId + 1 + i);
  objects[rootId - 1] =
    `<< /Type /Outlines /First ${itemIds[0]} 0 R ` +
    `/Last ${itemIds[itemIds.length - 1]} 0 R /Count ${chapters.length} >>`;
  chapters.forEach((ch, i) => {
    const prev = i > 0 ? ` /Prev ${itemIds[i - 1]} 0 R` : '';
    const next = i < chapters.length - 1 ? ` /Next ${itemIds[i + 1]} 0 R` : '';
    objects[itemIds[i] - 1] =
      `<< /Title (${ch.title}) /Parent ${rootId} 0 R${prev}${next} ` +
      `/Dest [${pageIds[ch.page - 1]} 0 R /Fit] >>`;
  });
  objects[0] = `<< /Type /Catalog /Pages 2 0 R /Outlines ${rootId} 0 R >>`;
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

/** Minimal store-only zip writer, enough for a valid DOCX (and EPUB/CBZ). */
function zip(entries) {
  const locals = [];
  const central = [];
  let offset = 0;
  for (const [name, content] of entries) {
    const nameBuf = Buffer.from(name, 'utf8');
    const data = Buffer.isBuffer(content) ? content : Buffer.from(content, 'utf8');
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

const XML_DECL = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

/**
 * A PPTX fixture. Unlike the DOCX builder above, this one cannot be
 * hand-assembled: LibreOffice — which the engine drives for ppt-to-pdf —
 * refuses decks without the full slide-master/text-style/docProps graph,
 * answering "source file could not be loaded" even when theme and docProps
 * parts are supplied. This is python-pptx's default one-slide deck (printer
 * settings stripped), base64-embedded so the test stays dependency-free.
 */
const PPTX_B64 =
  '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' +
  'Pngm/G1FxOno42eiZ2wtVHUyfPhceFI+iT60tsNe20uk8JGwx0OcF4XS2X3SZz6ipdOJ3RtO7aU+8k0Wn6MkXSy9OHIv48XEjeMw' +
  'cpNleOmmSZimCy+aZmn4pb8+Cp2qIjXOyP1a4Ou1uR5Oq4oPg3Pojx8qogMYviZRX5OMMfMXHlYlHKIqpRJtWf5fI6E99JUZ8Bwa' +
  'lpFJz8iKkgKDN+v67hEv0RC86NZJQz9JTfAXRJv6WTZZLqau58W6oUvC2J0GWr7JJAqCaRyex0m2F600mTc6ulO1+uPrtxc/vn4f' +
  'QKvwsHfSN8KVVN0MrAXRiSTJdBKkceImfpi54XJ67i6ySeRm0TgM0yRepOPLL6YH88NZLrDt6/4r+o7QD3/pCWuSCyZZqc5yVnfN' +
  'JeTsIxacEdtf+l7XEW6QuRomfjj2wyCKuzLp2PrRRgvb/tBKhIrXiF9vrEhqe8+ldonrBrjTyIMJPGioL34CUEsDBBQAAAAIALVh' +
  'J12AZeGItwAAADYBAAAsAAAAcHB0L3NsaWRlTGF5b3V0cy9fcmVscy9zbGlkZUxheW91dDIueG1sLnJlbHONz70OwiAQB/DdpyAs' +
  'TELrYIwp7WJMHFyMPsAFri2xBcKh0beX0SYOjvf1++ea7jVP7ImJXPBa1LISDL0J1vlBi9v1uN4JRhm8hSl41OKNJLp21Vxwglxu' +
  'aHSRWEE8aT7mHPdKkRlxBpIhoi+TPqQZcinToCKYOwyoNlW1Venb4O3CZCereTrZmrPrO+I/duh7Z/AQzGNGn39EKJqcxTNQxlRY' +
  'SANmzaX87i+WalkiuGobtXi3/QBQSwMEFAAAAAgAtWEnXYtg7VpjBAAAWBEAACEAAABwcHQvc2xpZGVMYXlvdXRzL3NsaWRlTGF5' +
  'b3V0My54bWzNWNtu2zYYvt9TCOqFrxRSEnUK6hSWHG0D0iSo0wdgJNoWSh1G0q69oUBfa3ucPslISrIcN2ndzgtyI1LUf/j+A/nz' +
  '1+s3m5Iaa8J4UVfjkX0GRwapsjovqsV49P4utcKRwQWuckzrioxHW8JHby5+ed2cc5pf4W29EoYUUfFzPDaXQjTnAPBsSUrMz+qG' +
  'VPLbvGYlFvKVLUDO8EcpuqTAgdAHJS4qs+Nnx/DX83mRkWmdrUpSiVYIIxQLCZ8vi4b30ppjpDWMcClGcz+EJLYNGZucZL8RnJuG' +
  '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' +
  'eW91dDExLnhtbFBLAQIUABQAAAAIALVhJ12AZeGItwAAADYBAAAtAAAAAAAAAAAAAACAAYMhAABwcHQvc2xpZGVMYXlvdXRzL19y' +
  'ZWxzL3NsaWRlTGF5b3V0MTEueG1sLnJlbHNQSwECFAAUAAAACAC1YSddAP3sDSoEAAAFEQAAIQAAAAAAAAAAAAAAgAGFIgAAcHB0' +
  'L3NsaWRlTGF5b3V0cy9zbGlkZUxheW91dDEueG1sUEsBAhQAFAAAAAgAtWEnXYBl4Yi3AAAANgEAACwAAAAAAAAAAAAAAIAB7iYA' +
  'AHBwdC9zbGlkZUxheW91dHMvX3JlbHMvc2xpZGVMYXlvdXQxLnhtbC5yZWxzUEsBAhQAFAAAAAgAtWEnXQFX6IttAwAAlgsAACEA' +
  'AAAAAAAAAAAAAIAB7ycAAHBwdC9zbGlkZUxheW91dHMvc2xpZGVMYXlvdXQyLnhtbFBLAQIUABQAAAAIALVhJ12AZeGItwAAADYB' +
  'AAAsAAAAAAAAAAAAAACAAZsrAABwcHQvc2xpZGVMYXlvdXRzL19yZWxzL3NsaWRlTGF5b3V0Mi54bWwucmVsc1BLAQIUABQAAAAI' +
  'ALVhJ12LYO1aYwQAAFgRAAAhAAAAAAAAAAAAAACAAZwsAABwcHQvc2xpZGVMYXlvdXRzL3NsaWRlTGF5b3V0My54bWxQSwECFAAU' +
  'AAAACAC1YSddgGXhiLcAAAA2AQAALAAAAAAAAAAAAAAAgAE+MQAAcHB0L3NsaWRlTGF5b3V0cy9fcmVscy9zbGlkZUxheW91dDMu' +
  'eG1sLnJlbHNQSwECFAAUAAAACAC1YSddT8qCHAgEAABoEgAAIQAAAAAAAAAAAAAAgAE/MgAAcHB0L3NsaWRlTGF5b3V0cy9zbGlk' +
  'ZUxheW91dDQueG1sUEsBAhQAFAAAAAgAtWEnXYBl4Yi3AAAANgEAACwAAAAAAAAAAAAAAIABhjYAAHBwdC9zbGlkZUxheW91dHMv' +
  'X3JlbHMvc2xpZGVMYXlvdXQ0LnhtbC5yZWxzUEsBAhQAFAAAAAgAtWEnXemkxI/jBAAANhwAACEAAAAAAAAAAAAAAIABhzcAAHBw' +
  'dC9zbGlkZUxheW91dHMvc2xpZGVMYXlvdXQ1LnhtbFBLAQIUABQAAAAIALVhJ12AZeGItwAAADYBAAAsAAAAAAAAAAAAAACAAak8' +
  'AABwcHQvc2xpZGVMYXlvdXRzL19yZWxzL3NsaWRlTGF5b3V0NS54bWwucmVsc1BLAQIUABQAAAAIALVhJ10ttCb1EgMAALgIAAAh' +
  'AAAAAAAAAAAAAACAAao9AABwcHQvc2xpZGVMYXlvdXRzL3NsaWRlTGF5b3V0Ni54bWxQSwECFAAUAAAACAC1YSddgGXhiLcAAAA2' +
  'AQAALAAAAAAAAAAAAAAAgAH7QAAAcHB0L3NsaWRlTGF5b3V0cy9fcmVscy9zbGlkZUxheW91dDYueG1sLnJlbHNQSwECFAAUAAAA' +
  'CAC1YSdd6xefd+YCAABnBwAAIQAAAAAAAAAAAAAAgAH8QQAAcHB0L3NsaWRlTGF5b3V0cy9zbGlkZUxheW91dDcueG1sUEsBAhQA' +
  'FAAAAAgAtWEnXYBl4Yi3AAAANgEAACwAAAAAAAAAAAAAAIABIUUAAHBwdC9zbGlkZUxheW91dHMvX3JlbHMvc2xpZGVMYXlvdXQ3' +
  'LnhtbC5yZWxzUEsBAhQAFAAAAAgAtWEnXc3KitWyBAAAwhIAACEAAAAAAAAAAAAAAIABIkYAAHBwdC9zbGlkZUxheW91dHMvc2xp' +
  'ZGVMYXlvdXQ4LnhtbFBLAQIUABQAAAAIALVhJ12AZeGItwAAADYBAAAsAAAAAAAAAAAAAACAARNLAABwcHQvc2xpZGVMYXlvdXRz' +
  'L19yZWxzL3NsaWRlTGF5b3V0OC54bWwucmVsc1BLAQIUABQAAAAIALVhJ11a07SSeQQAADESAAAhAAAAAAAAAAAAAACAARRMAABw' +
  'cHQvc2xpZGVMYXlvdXRzL3NsaWRlTGF5b3V0OS54bWxQSwECFAAUAAAACAC1YSddgGXhiLcAAAA2AQAALAAAAAAAAAAAAAAAgAHM' +
  'UAAAcHB0L3NsaWRlTGF5b3V0cy9fcmVscy9zbGlkZUxheW91dDkueG1sLnJlbHNQSwECFAAUAAAACAC1YSddN8Y1+I0DAADNCwAA' +
  'IgAAAAAAAAAAAAAAgAHNUQAAcHB0L3NsaWRlTGF5b3V0cy9zbGlkZUxheW91dDEwLnhtbFBLAQIUABQAAAAIALVhJ12AZeGItwAA' +
  'ADYBAAAtAAAAAAAAAAAAAACAAZpVAABwcHQvc2xpZGVMYXlvdXRzL19yZWxzL3NsaWRlTGF5b3V0MTAueG1sLnJlbHNQSwECFAAU' +
  'AAAACAC1YSddO0XlXV4BAADGAgAAFQAAAAAAAAAAAAAAgAGcVgAAcHB0L3NsaWRlcy9zbGlkZTEueG1sUEsBAhQAFAAAAAgAtWEn' +
  'XUHfSPy3AAAANgEAACAAAAAAAAAAAAAAAIABLVgAAHBwdC9zbGlkZXMvX3JlbHMvc2xpZGUxLnhtbC5yZWxzUEsBAhQAFAAAAAgA' +
  'tWEnXVqgDq2jBQAA4w8AABcAAAAAAAAAAAAAAIABIlkAAGRvY1Byb3BzL3RodW1ibmFpbC5qcGVnUEsFBgAAAAAlACUATQsAAPpe' +
  'AAAAAA==';

function pptx() {
  return Buffer.from(PPTX_B64, 'base64');
}

/** A minimal EPUB 2: mimetype first and stored, one XHTML chapter. */
function epub(title, paragraph) {
  return zip([
    ['mimetype', 'application/epub+zip'],
    [
      'META-INF/container.xml',
      '<?xml version="1.0"?>' +
        '<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">' +
        '<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>' +
        '</container>',
    ],
    [
      'OEBPS/content.opf',
      '<?xml version="1.0"?>' +
        '<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">' +
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">' +
        `<dc:title>${title}</dc:title>` +
        '<dc:identifier id="id">urn:uuid:2f6d0478-4a2c-4e5f-9b7e-8f1a3d5c9e01</dc:identifier>' +
        '<dc:language>en</dc:language></metadata>' +
        '<manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>' +
        '<spine><itemref idref="ch1"/></spine></package>',
    ],
    [
      'OEBPS/ch1.xhtml',
      '<?xml version="1.0" encoding="utf-8"?>' +
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter 1</title></head>' +
        `<body><h1>${title}</h1><p>${paragraph}</p></body></html>`,
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

  // Inputs for the full-catalog engine test (engine-full.test.js).
  // 2 text pages + 2 intentionally blank ones for remove-blank-pages.
  write('blank-mixed.pdf', textPdf(4, 'Blank mixed test', 2));
  // Outline at pages 1 and 4, so split-by-chapters has two chapters to cut on.
  write('chapters.pdf', chapterPdf(6, 'Chaptered doc', [
    { title: 'Chapter One', page: 1 },
    { title: 'Chapter Two', page: 4 },
  ]));
  write(
    'sample.md',
    '# DocFlow engine test\n\nLorem **ipsum** dolor sit amet, consectetur adipiscing elit.\n\n- one\n- two\n',
  );
  write(
    'sample.html',
    '<!DOCTYPE html><html><head><title>DocFlow test</title></head>' +
      '<body><h1>DocFlow engine test</h1><p>Lorem ipsum dolor sit amet.</p></body></html>',
  );
  write(
    'sample.svg',
    '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200">' +
      '<rect width="200" height="200" fill="#4B68FF"/>' +
      '<circle cx="100" cy="100" r="60" fill="#FCA82F"/></svg>',
  );
  write(
    'sample.epub',
    epub('DocFlow engine test', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'),
  );
  write('sample.pptx', pptx());
  write('sample.cbz', zip([
    ['001.png', noisyPng(240, 320, 21)],
    ['002.png', noisyPng(240, 320, 22)],
  ]));

  return { dir, samplePdfBytes, photoPdfBytes };
}
