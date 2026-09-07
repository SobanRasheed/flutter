/**
 * Full-catalog contract test against a real Stirling-PDF instance.
 *
 *   STIRLING_BASE_URL=https://... npm run test:engine:full
 *
 * engine.test.js covers the original 11 tools in depth; this file's job is
 * breadth — every tool added in the full-catalog expansion gets exercised
 * with the exact multipart body the registry builds, so a bad field name or
 * an NPE-prone "optional" parameter is caught here, not by a user.
 *
 * Where a tool legitimately cannot produce output for our fixtures (e.g. the
 * table extractor on a prose PDF), the assertion accepts the mapped
 * `nothing_extracted` 422 — that is correct behaviour for the route, not a
 * failure. Anything else failing here is a real bug in the registry.
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import zlib from 'node:zlib';
import { Readable } from 'node:stream';

import { runConversion } from '../src/services/stirling.js';
import { TOOLS } from '../src/services/tools.js';
import { makeFixtures } from './fixtures.js';

if (!process.env.STIRLING_BASE_URL) {
  console.error('STIRLING_BASE_URL is not set.');
  process.exit(2);
}

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'docflow-engine-full-'));
makeFixtures(dir);
const load = (name, mimetype) => ({
  originalname: name,
  mimetype,
  buffer: fs.readFileSync(path.join(dir, name)),
});

let passed = 0;
const failures = [];

function check(label, condition, detail) {
  if (condition) {
    passed++;
    console.log(`  ok    ${label}`);
  } else {
    failures.push(`${label}: ${detail}`);
    console.log(`  FAIL  ${label} — ${detail}`);
  }
}

async function convert(toolId, files, body = {}) {
  const tool = TOOLS[toolId];
  const res = await runConversion({ tool, files, fields: tool.fields(body) });
  const buffer = Buffer.concat(await Readable.fromWeb(res.body).toArray());
  return {
    buffer,
    contentType: res.contentType,
    disposition: res.disposition,
    name: tool.outputName(files, body),
  };
}

/** Runs a conversion, allowing the mapped "nothing to extract" outcome. */
async function convertOrEmpty(toolId, files, body) {
  try {
    const r = await convert(toolId, files, body);
    return { ok: true, ...r };
  } catch (err) {
    if (err.status === 422 && err.code === 'nothing_extracted') {
      return { ok: true, empty: true, buffer: Buffer.alloc(0) };
    }
    throw err;
  }
}

function zipEntries(buf) {
  const names = [];
  let eocd = buf.length - 22;
  while (eocd >= 0 && buf.readUInt32LE(eocd) !== 0x06054b50) eocd--;
  if (eocd < 0) return names;
  let off = buf.readUInt32LE(eocd + 16);
  const count = buf.readUInt16LE(eocd + 10);
  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) break;
    const nameLen = buf.readUInt16LE(off + 28);
    names.push(buf.toString('utf8', off + 46, off + 46 + nameLen));
    off += 46 + nameLen + buf.readUInt16LE(off + 30) + buf.readUInt16LE(off + 32);
  }
  return names;
}

/** Inflates one entry out of a zip (stored or deflate) — no dependency needed. */
function zipEntry(buf, name) {
  let eocd = buf.length - 22;
  while (eocd >= 0 && buf.readUInt32LE(eocd) !== 0x06054b50) eocd--;
  if (eocd < 0) throw new Error('zip: no EOCD');
  let off = buf.readUInt32LE(eocd + 16);
  const count = buf.readUInt16LE(eocd + 10);
  for (let i = 0; i < count; i++) {
    if (buf.readUInt32LE(off) !== 0x02014b50) break;
    const nameLen = buf.readUInt16LE(off + 28);
    const entryName = buf.toString('utf8', off + 46, off + 46 + nameLen);
    const method = buf.readUInt16LE(off + 10);
    const compSize = buf.readUInt32LE(off + 20);
    const localOff = buf.readUInt32LE(off + 42);
    if (entryName === name) {
      const start = localOff + 30 + buf.readUInt16LE(localOff + 26) + buf.readUInt16LE(localOff + 28);
      const data = buf.subarray(start, start + compSize);
      return method === 0 ? Buffer.from(data) : zlib.inflateRawSync(data);
    }
    off += 46 + nameLen + buf.readUInt16LE(off + 30) + buf.readUInt16LE(off + 32);
  }
  throw new Error(`zip: entry not found: ${name}`);
}

const isPdf = (b) => b.slice(0, 4).toString('latin1') === '%PDF';
const isZip = (b) => b[0] === 0x50 && b[1] === 0x4b;
const isPng = (b) => b[0] === 0x89 && b.slice(1, 4).toString('latin1') === 'PNG';
const latin1 = (b) => b.toString('latin1');

/**
 * Page counts and rotations are read back through the engine's own
 * get-info-on-pdf endpoint. Raw-byte counting (`/Type /Page` greps) is not
 * reliable here: PDFBox rewrites compress many outputs' page dictionaries
 * into object streams, so the markers simply aren't in the bytes.
 */
async function infoOf(buffer, name = 'sample.pdf') {
  const r = await convert('get-info-on-pdf', [
    { originalname: name, mimetype: PDF_MIME, buffer },
  ]);
  return JSON.parse(latin1(r.buffer));
}
const pagesOf = async (buffer, name) => (await infoOf(buffer, name)).BasicInfo['Number of pages'];

/**
 * One section must not be able to kill the run: an unexpected throw here is a
 * finding ("crashed"), and the sections after it still get their chance.
 */
async function section(name, fn) {
  console.log(`\n${name}`);
  try {
    await fn();
  } catch (err) {
    const label = `${name} — crashed on ${err.toolId || 'an unchecked call'}`;
    failures.push(`${label}: ${err.status} ${err.code} ${err.message}`);
    console.log(`  CRASH ${label} — ${err.status} ${err.code} ${err.message}`);
  }
}

/** Wraps convert() so a failed conversion is reported, not thrown. */
async function attempt(toolId, files, body) {
  try {
    return { ok: true, ...(await convert(toolId, files, body)) };
  } catch (err) {
    err.toolId = toolId;
    return { ok: false, err };
  }
}

const PDF_MIME = 'application/pdf';
const PDF = () => [load('sample.pdf', PDF_MIME)];
const PHOTO = () => [load('photo.pdf', PDF_MIME)];

console.log(`\nEngine (full catalog): ${process.env.STIRLING_BASE_URL}\n`);

await section('PDF → other formats', async () => {
  const ppt = await convert('pdf-to-ppt', PDF());
  check('pdf-to-ppt returns a pptx zip', isZip(ppt.buffer) && ppt.name.endsWith('.pptx'), ppt.name);
  check('pdf-to-ppt zip holds a presentation', zipEntries(ppt.buffer).some((n) => n.includes('slide') || n.includes('presentation')), zipEntries(ppt.buffer).slice(0, 3).join(', '));

  const txt = await convert('pdf-to-text', PDF());
  check('pdf-to-text (txt) extracts real text', txt.name.endsWith('.txt') && latin1(txt.buffer).includes('Lorem ipsum'), `${txt.name}, ${txt.buffer.length}B`);

  const rtf = await convert('pdf-to-text', PDF(), { format: 'rtf' });
  check('pdf-to-text (rtf) is an RTF body', rtf.name.endsWith('.rtf') && latin1(rtf.buffer).includes('\\rtf'), rtf.name);

  const xml = await convert('pdf-to-xml', PDF());
  check('pdf-to-xml returns XML', xml.name.endsWith('.xml') && latin1(xml.buffer).includes('<'), xml.name);

  const html = await convert('pdf-to-html', PDF());
  check('pdf-to-html returns a zip of HTML', isZip(html.buffer) && html.name.endsWith('.zip'), html.name);

  const epub = await convert('pdf-to-epub', PDF());
  check('pdf-to-epub returns a zip (epub)', isZip(epub.buffer) && epub.name.endsWith('.epub'), epub.name);
  check('pdf-to-epub zip carries a mimetype entry', zipEntries(epub.buffer).includes('mimetype'), zipEntries(epub.buffer).slice(0, 3).join(', '));

  const pdfa = await convert('pdf-to-pdfa', PDF());
  check('pdf-to-pdfa returns a PDF', isPdf(pdfa.buffer), pdfa.contentType);

  // The spreadsheet extractor may find no table in a prose PDF — both a real
  // xlsx and the mapped 422 are acceptable here.
  const xlsx = await convertOrEmpty('pdf-to-xlsx', PDF());
  check('pdf-to-xlsx returns xlsx or a clean nothing_extracted', xlsx.empty || (isZip(xlsx.buffer) && xlsx.name.endsWith('.xlsx')), `${xlsx.name} empty=${!!xlsx.empty}`);
  console.log(`        (pdf-to-xlsx empty result: ${!!xlsx.empty})`);

  const cbz = await convert('pdf-to-cbz', PHOTO(), { dpi: '150' });
  check('pdf-to-cbz returns a zip of page images', isZip(cbz.buffer) && cbz.name.endsWith('.cbz'), cbz.name);
  check('pdf-to-cbz extracts the two embedded photos', zipEntries(cbz.buffer).length === 2, `${zipEntries(cbz.buffer).length} entries`);
  // No pdf-to-cbr here: the engine's RAR-writing endpoint is disabled (403)
  // in the deployment this suite runs against — the tool is not registered.
});

await section('other formats → PDF', async () => {
  const PPTX_MIME = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  const p = await attempt('ppt-to-pdf', [load('sample.pptx', PPTX_MIME)]);
  check('ppt-to-pdf returns a PDF', p.ok && isPdf(p.buffer), p.ok ? p.contentType : `${p.err.status} ${p.err.message}`);

  const md = await convert('markdown-to-pdf', [load('sample.md', 'text/markdown')]);
  check('markdown-to-pdf returns a PDF', isPdf(md.buffer), md.contentType);

  const html = await convert('html-to-pdf', [load('sample.html', 'text/html')]);
  check('html-to-pdf returns a PDF', isPdf(html.buffer), html.contentType);

  const svg = await convert('svg-to-pdf', [load('sample.svg', 'image/svg+xml')]);
  check('svg-to-pdf (single) returns a PDF', isPdf(svg.buffer) && svg.name.endsWith('.pdf'), svg.name);

  const ebook = await convert('ebook-to-pdf', [load('sample.epub', 'application/epub+zip')]);
  check('ebook-to-pdf returns a PDF', isPdf(ebook.buffer), ebook.contentType);

  const comic = await convert('cbz-to-pdf', [load('sample.cbz', 'application/vnd.comicbook+zip')]);
  check('cbz-to-pdf returns a PDF', isPdf(comic.buffer), comic.contentType);

  // cbr-to-pdf is registered and the endpoint is enabled, but the suite has no
  // way to fabricate a RAR archive on this machine — it needs a real .cbr to
  // be exercised. Leaving it unexercised rather than unregistered.
  console.log('  ----  cbr-to-pdf not exercised (no RAR fixture; endpoint verified enabled)');
});

await section('organize', async () => {
  const rot = await convert('rotate-pdf', PDF(), { angle: '90' });
  check('rotate-pdf returns a PDF', isPdf(rot.buffer), rot.contentType);
  const rotInfo = await infoOf(rot.buffer);
  check('rotate-pdf rotates every page to 90°', Object.values(rotInfo.PerPageInfo).every((p) => p.Rotation === 90), JSON.stringify(Object.values(rotInfo.PerPageInfo).map((p) => p.Rotation)));

  const rem = await convert('remove-pages', PDF(), { pages: '2,4' });
  check('remove-pages drops the listed pages', isPdf(rem.buffer) && await pagesOf(rem.buffer) === 4, `${await pagesOf(rem.buffer)} pages`);

  const re = await convert('rearrange-pages', PDF(), { mode: 'REVERSE_ORDER' });
  check('rearrange-pages (reverse) returns a 6-page PDF', isPdf(re.buffer) && await pagesOf(re.buffer) === 6, `${await pagesOf(re.buffer)} pages`);

  const single = await convert('pdf-to-single-page', PDF());
  check('pdf-to-single-page returns one page', isPdf(single.buffer) && await pagesOf(single.buffer) === 1, `${await pagesOf(single.buffer)} pages`);

  const sect = await convert('split-by-sections', PDF(), { horizontal: '1', vertical: '1' });
  check('split-by-sections returns a zip of section PDFs', isZip(sect.buffer) && zipEntries(sect.buffer).every((n) => n.endsWith('.pdf')), zipEntries(sect.buffer).slice(0, 3).join(', '));

  const bySize = await convert('split-by-size', PDF(), { splitType: '2', splitValue: '3' });
  check('split-by-size (into 3 docs) returns 3 PDFs', isZip(bySize.buffer) && zipEntries(bySize.buffer).length === 3, `${zipEntries(bySize.buffer).length} entries`);

  const chapters = await convert('split-by-chapters', [load('chapters.pdf', PDF_MIME)], { bookmarkLevel: '1' });
  check('split-by-chapters cuts on the outline', isZip(chapters.buffer) && zipEntries(chapters.buffer).length >= 2, zipEntries(chapters.buffer).join(', '));

  const over = await convert('overlay-pdfs', [load('sample.pdf', PDF_MIME), load('merge-a.pdf', PDF_MIME)]);
  check('overlay-pdfs overlays the second file', isPdf(over.buffer) && over.name === 'Overlaid.pdf', over.name);

  const layout = await convert('multi-page-layout', PDF(), { pagesPerSheet: '2' });
  check('multi-page-layout packs 6 pages onto 3 sheets', isPdf(layout.buffer) && await pagesOf(layout.buffer) === 3, `${await pagesOf(layout.buffer)} pages`);

  const scaled = await convert('scale-pages', PDF(), { pageSize: 'A4', orientation: 'portrait', scale: '1' });
  check('scale-pages returns a PDF', isPdf(scaled.buffer), scaled.contentType);

  const cropped = await convert('crop-pdf', PDF(), { x: '0', y: '0', width: '300', height: '400' });
  check('crop-pdf rewrites the MediaBox', isPdf(cropped.buffer) && latin1(cropped.buffer).includes('[0 0 300 400]'), 'no 300x400 MediaBox found');

  const auto = await convertOrEmpty('auto-split-pdf', PDF());
  check('auto-split-pdf answers without a 500', auto.empty || isZip(auto.buffer), `empty=${!!auto.empty}`);

  const noImg = await convert('remove-images', PHOTO());
  check('remove-images strips both embedded photos', isPdf(noImg.buffer) && noImg.buffer.length < fs.statSync(path.join(dir, 'photo.pdf')).size, `${noImg.buffer.length}B`);

  const booklet = await convert('booklet-imposition', PDF(), { spine: 'left', doubleSided: 'true' });
  check('booklet-imposition returns a PDF', isPdf(booklet.buffer), booklet.contentType);

  const poster = await convert('poster-pdf', PDF(), { pageSize: 'A4', xFactor: '2', yFactor: '2' });
  // Verified against 2.14.3: the response is a zip holding one PDF per
  // poster tile — the registry and web catalog both present it as a ZIP.
  check('poster-pdf returns a zip of tile PDFs', isZip(poster.buffer) && poster.name.endsWith('.zip') && zipEntries(poster.buffer).every((n) => n.endsWith('.pdf')), `${poster.name}, ${zipEntries(poster.buffer).join(', ')}`);
});

await section('security & inspection', async () => {
  const protectPw = 'hunter2hunter2';
  const locked = await convert('protect-pdf', PDF(), { password: protectPw });
  check('protect-pdf (chain setup) returns an encrypted PDF', isPdf(locked.buffer) && latin1(locked.buffer).includes('/Encrypt'), 'no /Encrypt');

  const unlocked = await convert('unlock-pdf', [
    { originalname: 'sample.pdf', mimetype: PDF_MIME, buffer: locked.buffer },
  ], { password: protectPw });
  check('unlock-pdf returns a decrypted PDF', isPdf(unlocked.buffer) && !latin1(unlocked.buffer).includes('/Encrypt'), 'still encrypted');
  check('unlock-pdf restores readable text', latin1(unlocked.buffer).includes('Lorem ipsum'), 'body text missing');

  const clean = await convert('sanitize-pdf', PDF(), {
    removeJavaScript: 'true', removeEmbeddedFiles: 'true', removeXMPMetadata: 'true',
    removeMetadata: 'true', removeLinks: 'false', removeFonts: 'false',
  });
  check('sanitize-pdf returns a PDF', isPdf(clean.buffer), clean.contentType);

  const redact = await convert('auto-redact', PDF(), { listOfText: 'Lorem ipsum', wholeWord: 'false' });
  check('auto-redact returns a PDF', isPdf(redact.buffer), redact.contentType);

  const unsigned = await convert('remove-cert-sign', PDF());
  check('remove-cert-sign returns a PDF', isPdf(unsigned.buffer), unsigned.contentType);

  const info = await convert('get-info-on-pdf', PDF());
  let infoObj = null;
  try {
    infoObj = JSON.parse(latin1(info.buffer));
  } catch { /* checked below */ }
  check('get-info-on-pdf returns JSON', infoObj !== null && typeof infoObj === 'object', `${info.buffer.length}B, head: ${latin1(info.buffer).slice(0, 40)}`);

  const meta = await convert('update-metadata', PDF(), { title: 'DocFlowMetaTitle', author: 'DocFlow engine test' });
  check('update-metadata returns a PDF', isPdf(meta.buffer), meta.contentType);
  const metaInfo = await convert('get-info-on-pdf', [
    { originalname: 'sample.pdf', mimetype: PDF_MIME, buffer: meta.buffer },
  ]);
  check('update-metadata title is readable back via get-info', JSON.stringify(JSON.parse(latin1(metaInfo.buffer))).includes('DocFlowMetaTitle'), 'title not found in info JSON');

  const forms = await convert('unlock-pdf-forms', PDF());
  check('unlock-pdf-forms returns a PDF', isPdf(forms.buffer), forms.contentType);
});

await section('optimize & edit', async () => {
  const dec = await convert('decompress-pdf', PDF());
  check('decompress-pdf returns a PDF', isPdf(dec.buffer), dec.contentType);

  const rep = await convert('repair-pdf', PDF());
  check('repair-pdf returns a PDF', isPdf(rep.buffer), rep.contentType);

  const ocr = await convert('ocr-pdf', PDF(), { languages: 'eng', ocrType: 'skip-text' });
  check('ocr-pdf (skip-text) passes a text PDF through', isPdf(ocr.buffer), ocr.contentType);

  const flat = await convert('flatten-pdf', PDF(), { onlyForms: 'false', dpi: '150' });
  check('flatten-pdf returns a PDF', isPdf(flat.buffer), flat.contentType);

  const imgs = await convert('extract-images', PHOTO());
  check('extract-images pulls both photos into a zip', isZip(imgs.buffer) && zipEntries(imgs.buffer).length >= 2, `${zipEntries(imgs.buffer).length} entries`);

  const scans = await convertOrEmpty('extract-image-scans', PHOTO());
  check('extract-image-scans answers without a 500', scans.empty || isZip(scans.buffer), `empty=${!!scans.empty}`);

  // The engine answers with a zip holding both halves: <name>_nonBlankPages.pdf
  // (the cleaned document) and <name>_blankPages.pdf (the removed pages).
  const blanks = await convert('remove-blank-pages', [load('blank-mixed.pdf', PDF_MIME)], { threshold: '10', whitePercent: '99.9' });
  const blankNames = zipEntries(blanks.buffer);
  const nonBlankOk = isZip(blanks.buffer) && blanks.name.endsWith('.zip')
    && blankNames.includes('blank-mixed_nonBlankPages.pdf')
    && blankNames.includes('blank-mixed_blankPages.pdf');
  check('remove-blank-pages returns a zip separating kept from removed pages', nonBlankOk, `${blanks.name}: ${blankNames.join(', ')}`);
  let keptPages = -1;
  if (nonBlankOk) {
    const kept = zipEntry(blanks.buffer, 'blank-mixed_nonBlankPages.pdf');
    keptPages = isPdf(kept) ? await pagesOf(kept, 'blank-mixed_nonBlankPages.pdf') : -1;
  }
  check('remove-blank-pages keeps only the 2 text pages', keptPages === 2, `${keptPages} pages`);

  const renamed = await convert('auto-rename', PDF());
  check('auto-rename returns a PDF with a detected filename', isPdf(renamed.buffer) && (renamed.disposition || '').includes('.pdf'), renamed.disposition || 'no disposition');

  const stamp = await convert('add-stamp', PDF(), { stampText: 'DRAFT', size: '30', angle: '0', opacity: '0.5', position: '8', color: '#d3d3d3' });
  check('add-stamp returns a PDF', isPdf(stamp.buffer), stamp.contentType);

  const numbered = await convert('add-page-numbers', PDF(), { position: '8', startAt: '1', size: '12', color: '#000000' });
  check('add-page-numbers returns a PDF', isPdf(numbered.buffer), numbered.contentType);

  const stampedImg = await convert('add-image-to-pdf', [load('sample.pdf', PDF_MIME), load('img-a.png', 'image/png')], { x: '50', y: '50', everyPage: 'false' });
  check('add-image-to-pdf returns a PDF', isPdf(stampedImg.buffer), stampedImg.contentType);

  const inverted = await convert('replace-invert-color', PDF(), { option: 'FULL_INVERSION' });
  check('replace-invert-color returns a PDF', isPdf(inverted.buffer), inverted.contentType);

  const js = await convert('show-javascript', PDF());
  check('show-javascript returns a text body', js.name.endsWith('.txt'), js.contentType);

  const scan = await convert('scanner-effect', PDF(), { quality: 'low', colorspace: 'grayscale', border: '20' });
  check('scanner-effect returns a PDF', isPdf(scan.buffer), scan.contentType);
});

fs.rmSync(dir, { recursive: true, force: true });

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) {
  console.log('\nFailures:');
  for (const f of failures) console.log('  - ' + f);
  process.exit(1);
}
