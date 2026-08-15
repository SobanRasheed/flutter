/**
 * Contract test against a real Stirling-PDF instance.
 *
 *   STIRLING_BASE_URL=https://... npm run test:engine
 *
 * Every assertion here was written against Stirling 2.14.3 by observing actual
 * responses, not by reading the docs. The engine's OpenAPI spec marks fields
 * optional that throw NPEs when omitted, and optimizeLevel is documented as
 * 1-9 but collapses into two effective bands. Run this after bumping the
 * Stirling image — a silent behaviour change here reaches users as a failed
 * conversion or, worse, a parameter that quietly does nothing.
 *
 * Needs no Firebase credentials: it exercises the engine layer, below auth.
 */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { Readable } from 'node:stream';

import { runConversion } from '../src/services/stirling.js';
import { TOOLS } from '../src/services/tools.js';
import { makeFixtures } from './fixtures.js';

if (!process.env.STIRLING_BASE_URL) {
  console.error('STIRLING_BASE_URL is not set.');
  process.exit(2);
}

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'docflow-engine-'));
const fixtures = makeFixtures(dir);
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
  return { buffer, contentType: res.contentType, name: tool.outputName(files, body) };
}

/** Reads entry names out of a zip's central directory. */
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

const isPdf = (b) => b.slice(0, 4).toString('latin1') === '%PDF';
const isZip = (b) => b[0] === 0x50 && b[1] === 0x4b;
const isPng = (b) => b[0] === 0x89 && b.slice(1, 4).toString('latin1') === 'PNG';

const pdf = () => [load('sample.pdf', 'application/pdf')];
const DOCX_MIME =
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

console.log(`\nEngine: ${process.env.STIRLING_BASE_URL}\n`);

console.log('conversions');
{
  const r = await convert('word-to-pdf', [load('sample.docx', DOCX_MIME)]);
  check('word-to-pdf returns a PDF', isPdf(r.buffer), r.contentType);

  const w = await convert('pdf-to-word', pdf());
  check('pdf-to-word returns a docx', isZip(w.buffer) && w.name.endsWith('.docx'), w.name);
  check(
    'pdf-to-word content-type is not octet-stream',
    w.contentType === DOCX_MIME,
    w.contentType,
  );
  check(
    'pdf-to-word zip holds word/document.xml',
    zipEntries(w.buffer).includes('word/document.xml'),
    zipEntries(w.buffer).slice(0, 3).join(', '),
  );
}

console.log('\nmulti-file');
{
  const m = await convert('merge-pdf', [
    load('merge-a.pdf', 'application/pdf'),
    load('merge-b.pdf', 'application/pdf'),
  ]);
  check('merge returns a PDF named Merged.pdf', isPdf(m.buffer) && m.name === 'Merged.pdf', m.name);

  const i = await convert('image-to-pdf', [
    load('img-a.png', 'image/png'),
    load('img-b.png', 'image/png'),
  ]);
  check('image-to-pdf returns a PDF', isPdf(i.buffer), i.contentType);
}

console.log('\nzip-producing tools');
{
  const s = await convert('split-pdf', pdf(), { pages: '2,4' });
  check('split returns a zip named .zip', isZip(s.buffer) && s.name.endsWith('.zip'), s.name);
  check('split content-type is application/zip', s.contentType === 'application/zip', s.contentType);
  check(
    'split zip holds one PDF per range',
    zipEntries(s.buffer).length >= 2 && zipEntries(s.buffer).every((n) => n.endsWith('.pdf')),
    zipEntries(s.buffer).join(', '),
  );

  const multi = await convert('pdf-to-image', pdf(), { format: 'png' });
  check(
    'pdf-to-image (multiple) zips one PNG per page',
    isZip(multi.buffer) && zipEntries(multi.buffer).length === 6,
    `${zipEntries(multi.buffer).length} entries`,
  );

  const single = await convert('pdf-to-image', pdf(), { format: 'png', singlePage: 'true' });
  check(
    'pdf-to-image (single) returns a bare PNG named .png',
    isPng(single.buffer) && single.name.endsWith('.png'),
    `${single.contentType} / ${single.name}`,
  );
}

console.log('\nsecurity tools');
{
  const p = await convert('protect-pdf', pdf(), { password: 'example-test-password' });
  const text = p.buffer.toString('latin1');
  check('protect returns a PDF', isPdf(p.buffer), p.contentType);
  check('protect output declares /Encrypt', text.includes('/Encrypt'), 'no /Encrypt dictionary');
  check('protect output is not readable as plain text', !text.includes('Lorem ipsum'), 'body text still legible');

  // Regression: omitting alphabet or customColor makes Stirling 2.14.3 throw
  // a NullPointerException. Both must be sent.
  const w = await convert('watermark-pdf', pdf(), {
    text: 'CONFIDENTIAL',
    size: '30',
    angle: '45',
    opacity: '0.4',
  });
  check('watermark succeeds (regression: NPE on missing alphabet/customColor)', isPdf(w.buffer), w.contentType);
  check('watermark grew the file', w.buffer.length > fixtures.samplePdfBytes, `${w.buffer.length}B`);
}

console.log('\ncompression levels must actually compress');
{
  const photo = [load('photo.pdf', 'application/pdf')];
  const original = fs.statSync(path.join(dir, 'photo.pdf')).size;
  const sizes = {};
  for (const level of ['low', 'medium', 'high']) {
    const r = await convert('compress-pdf', photo, { level });
    sizes[level] = r.buffer.length;
    check(`compress ${level} returns a PDF`, isPdf(r.buffer), r.contentType);
  }
  console.log(
    `        original ${original}B -> low ${sizes.low}B, medium ${sizes.medium}B, high ${sizes.high}B`,
  );

  // The regression that matters: a level that silently returns the original
  // file. Stirling's low optimizeLevels are a no-op and actually come back a
  // few bytes larger, so every preset must clear a real margin.
  for (const level of ['low', 'medium', 'high']) {
    check(
      `${level} shrinks the file by at least 25%`,
      sizes[level] < original * 0.75,
      `${sizes[level]}B vs ${original}B original`,
    );
  }

  // Ordering between adjacent levels is content-dependent — on some encodings
  // level 5 beats level 7. Only the span from low to high is dependable.
  check(
    'high compresses at least as hard as low',
    sizes.high <= sizes.low,
    JSON.stringify(sizes),
  );
}

console.log('\nerror mapping');
{
  // The CSV extractor answers 204 for a PDF with no detectable table. That is
  // a success status, so without special handling it would stream 0 bytes to
  // the user's phone as if it had worked.
  try {
    await convert('pdf-to-excel', pdf(), { pages: 'all' });
    check('pdf-to-excel surfaces the empty result', false, 'returned a body instead of throwing');
  } catch (err) {
    check(
      'empty extraction becomes 422 nothing_extracted, not a 0-byte file',
      err.status === 422 && err.code === 'nothing_extracted',
      `${err.status} ${err.code}`,
    );
  }
}

fs.rmSync(dir, { recursive: true, force: true });

console.log(`\n${passed} passed, ${failures.length} failed`);
if (failures.length) {
  console.log('\nFailures:');
  for (const f of failures) console.log('  - ' + f);
  process.exit(1);
}
