import { ApiError } from '../errors.js';

/**
 * Maps DocFlow's tool ids — the same ids in lib/models/conversion_tool.dart —
 * onto Stirling-PDF endpoints and their form fields.
 *
 * Keeping the registry here means the Flutter app never learns a Stirling URL.
 * It posts a tool id; this file decides what that means. Adding a tool is a
 * one-entry change on both sides and nothing in between.
 */

const PDF = 'application/pdf';
const ZIP = 'application/zip';
const DOCX =
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/** Swaps a file's extension, keeping the user's chosen name. */
function rename(original, ext) {
  const base = (original || 'document').replace(/\.[^./\\]+$/, '');
  return `${base}.${ext}`;
}

function clampInt(value, min, max, fallback) {
  const n = Number.parseInt(value, 10);
  if (Number.isNaN(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function clampFloat(value, min, max, fallback) {
  const n = Number.parseFloat(value);
  if (Number.isNaN(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

export const TOOLS = {
  'pdf-to-word': {
    endpoint: '/api/v1/convert/pdf/word',
    accepts: ['application/pdf'],
    multiFile: false,
    contentType: DOCX,
    // Stirling drives this through LibreOffice, which is the slow path.
    fields: () => ({ outputFormat: 'docx' }),
    outputName: (files) => rename(files[0].originalname, 'docx'),
  },

  'word-to-pdf': {
    endpoint: '/api/v1/convert/file/pdf',
    accepts: [
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/msword',
      'application/vnd.oasis.opendocument.text',
      'application/rtf',
      'text/plain',
    ],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'pdf-to-excel': {
    // Verified against Stirling 2.14.3: /convert/pdf/csv answers 204 No Content
    // for every page range on a text PDF — the endpoint extracts *table*
    // structures, and a document without a detected table yields nothing. It
    // cannot be relied on as a general "PDF to spreadsheet" tool, and Stirling
    // has no PDF -> XLSX at all. Left registered so the id resolves, but the
    // route surfaces the empty result as a clear error rather than handing the
    // app a zero-byte file. Swap in a table-extraction service to ship this.
    endpoint: '/api/v1/convert/pdf/csv',
    accepts: ['application/pdf'],
    multiFile: false,
    contentType: 'text/csv',
    fields: (body) => ({ pageNumbers: body.pages || 'all' }),
    outputName: (files) => rename(files[0].originalname, 'csv'),
  },

  'excel-to-pdf': {
    endpoint: '/api/v1/convert/file/pdf',
    accepts: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.ms-excel',
      'application/vnd.oasis.opendocument.spreadsheet',
      'text/csv',
    ],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'merge-pdf': {
    endpoint: '/api/v1/general/merge-pdfs',
    accepts: ['application/pdf'],
    multiFile: true,
    minFiles: 2,
    contentType: PDF,
    // orderProvided keeps the order the user dragged them into on the merge
    // screen. Any other sort would silently override that. removeCertSign is
    // required by the schema and defaults to true server-side — sent
    // explicitly so a schema change cannot start stripping signatures.
    fields: () => ({ sortType: 'orderProvided', removeCertSign: 'true' }),
    outputName: () => 'Merged.pdf',
  },

  'split-pdf': {
    endpoint: '/api/v1/general/split-pages',
    accepts: ['application/pdf'],
    multiFile: false,
    // Split yields one PDF per range, so Stirling zips them. Flutter must save
    // this as .zip, not .pdf — it is the one tool whose output is not a PDF.
    contentType: ZIP,
    fields: (body) => {
      const pages = (body.pages || '').trim();
      if (!pages) {
        throw ApiError.badRequest(
          'Split needs a "pages" field, e.g. "1,3,5-9" or "all"',
        );
      }
      return { pageNumbers: pages };
    },
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'compress-pdf': {
    endpoint: '/api/v1/misc/compress-pdf',
    accepts: ['application/pdf'],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      // Measured against Stirling 2.14.3 across two differently-encoded
      // image PDFs. optimizeLevel is not a smooth dial and the threshold where
      // it engages at all is content-dependent:
      //   1-3  no-op on every fixture tried (output is ~135B LARGER)
      //   4    engaged on one encoding, no-op on the other
      //   5-9  engaged on both, broadly monotonic
      // So the UI's three levels avoid the unreliable low end entirely. Do not
      // "restore" 1-3 to make the range look symmetrical — Low would silently
      // return the original file and users would report compression as broken.
      //   low 5  ~86-95%  |  medium 7  ~90-95%  |  high 9  ~94-97%
      const presets = { low: 5, medium: 7, high: 9 };
      const level =
        presets[String(body.level || '').toLowerCase()] ??
        clampInt(body.level, 4, 9, 7);

      return {
        optimizeLevel: String(level),
        grayscale: body.grayscale === 'true' ? 'true' : 'false',
        // Declared required by the spec. Left empty on purpose: any value here
        // overrides optimizeLevel and drives compression toward a target size
        // (the schema's own default is "25KB", which would wreck real files).
        expectedOutputSize: '',
        linearize: 'false',
        normalize: 'false',
      };
    },
    outputName: (files) => files[0].originalname || 'Compressed.pdf',
  },

  'image-to-pdf': {
    endpoint: '/api/v1/convert/img/pdf',
    accepts: ['image/jpeg', 'image/png', 'image/webp', 'image/heic'],
    multiFile: true,
    minFiles: 1,
    contentType: PDF,
    fields: (body) => ({
      fitOption: body.fit || 'fitDocumentToImage',
      colorType: body.colorType || 'color',
      autoRotate: body.autoRotate === 'false' ? 'false' : 'true',
    }),
    outputName: (files) =>
      files.length === 1 ? rename(files[0].originalname, 'pdf') : 'Images.pdf',
  },

  'pdf-to-image': {
    endpoint: '/api/v1/convert/pdf/img',
    accepts: ['application/pdf'],
    multiFile: false,
    // Verified: a 6-page PDF comes back as a zip of sample_1.png ...
    // sample_6.png. singleOrMultiple: 'single' stitches every page into one
    // tall image instead, in which case the response is a bare PNG — the
    // route trusts Stirling's own content-type over this default.
    contentType: ZIP,
    fields: (body) => ({
      // Required by the schema; omitting it renders only the first page.
      pageNumbers: body.pages || 'all',
      imageFormat: body.format === 'jpeg' ? 'jpeg' : 'png',
      singleOrMultiple: body.singlePage === 'true' ? 'single' : 'multiple',
      colorType: body.colorType || 'color',
      dpi: String(clampInt(body.dpi, 72, 600, 300)),
    }),
    outputName: (files, body = {}) =>
      body.singlePage === 'true'
        ? rename(files[0].originalname, body.format === 'jpeg' ? 'jpg' : 'png')
        : rename(files[0].originalname, 'zip'),
  },

  'protect-pdf': {
    endpoint: '/api/v1/security/add-password',
    accepts: ['application/pdf'],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const password = body.password;
      if (!password || password.length < 4) {
        throw ApiError.badRequest('A password of at least 4 characters is required');
      }
      return {
        password,
        keyLength: '256',
        preventAssembly: 'false',
        preventExtractContent: 'false',
        preventPrinting: 'false',
      };
    },
    outputName: (files) => files[0].originalname || 'Protected.pdf',
  },

  'watermark-pdf': {
    endpoint: '/api/v1/security/add-watermark',
    accepts: ['application/pdf'],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const text = (body.text || '').trim();
      if (!text) throw ApiError.badRequest('Watermark text is required');
      return {
        watermarkType: 'text',
        watermarkText: text,
        // Both of these are nominally optional with server-side defaults, but
        // Stirling 2.14.3 throws a NullPointerException when either is absent
        // ("Cannot invoke String.hashCode()" for alphabet, "colorString is
        // null" for customColor). Verified: omitting either one 500s, sending
        // both succeeds. They are effectively required — do not "clean up".
        alphabet: 'roman',
        customColor: body.color || '#d3d3d3',
        fontSize: String(clampInt(body.size, 8, 96, 30)),
        rotation: String(clampInt(body.angle, -90, 90, 45)),
        opacity: String(clampFloat(body.opacity, 0.05, 1, 0.5)),
        widthSpacer: '50',
        heightSpacer: '50',
        convertPDFToImage: 'false',
      };
    },
    outputName: (files) => files[0].originalname || 'Watermarked.pdf',
  },

  // ---------------------------------------------------------------------------
  // Full Stirling catalog. Field names/defaults come from the v2.14.3 request
  // models (stirling/model/api/**) — see the clone of the tag for reference.
  // ---------------------------------------------------------------------------

  'pdf-to-ppt': {
    endpoint: '/api/v1/convert/pdf/presentation',
    accepts: [PDF],
    multiFile: false,
    contentType: 'application/octet-stream',
    fields: (body) => ({
      outputFormat: ['ppt', 'pptx', 'odp'].includes(body.format) ? body.format : 'pptx',
    }),
    outputName: (files, body = {}) =>
      rename(files[0].originalname, body.format === 'ppt' ? 'ppt' : body.format === 'odp' ? 'odp' : 'pptx'),
  },

  'pdf-to-text': {
    endpoint: '/api/v1/convert/pdf/text',
    accepts: [PDF],
    multiFile: false,
    contentType: 'text/plain',
    fields: (body) => ({ outputFormat: body.format === 'rtf' ? 'rtf' : 'txt' }),
    outputName: (files, body = {}) => rename(files[0].originalname, body.format === 'rtf' ? 'rtf' : 'txt'),
  },

  'pdf-to-xml': {
    endpoint: '/api/v1/convert/pdf/xml',
    accepts: [PDF],
    multiFile: false,
    contentType: 'application/xml',
    fields: () => ({ outputFormat: 'xml' }),
    outputName: (files) => rename(files[0].originalname, 'xml'),
  },

  'pdf-to-html': {
    endpoint: '/api/v1/convert/pdf/html',
    accepts: [PDF],
    multiFile: false,
    contentType: ZIP,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'pdf-to-epub': {
    endpoint: '/api/v1/convert/pdf/epub',
    accepts: [PDF],
    multiFile: false,
    contentType: 'application/epub+zip',
    fields: (body) => ({
      outputFormat: 'EPUB',
      detectChapters: body.detectChapters === 'false' ? 'false' : 'true',
      targetDevice: body.device === 'kindle' ? 'KINDLE_EINK_TEXT' : 'TABLET_PHONE_IMAGES',
    }),
    outputName: (files) => rename(files[0].originalname, 'epub'),
  },

  'pdf-to-pdfa': {
    endpoint: '/api/v1/convert/pdf/pdfa',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({ outputFormat: 'pdfa', strict: 'false' }),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'pdf-to-xlsx': {
    // Note: the registry's older comment (see pdf-to-excel) predates this
    // endpoint — /convert/pdf/xlsx exists in Stirling v2.14.3.
    endpoint: '/api/v1/convert/pdf/xlsx',
    accepts: [PDF],
    multiFile: false,
    contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    fields: (body) => ({ pageNumbers: body.pages || 'all' }),
    outputName: (files) => rename(files[0].originalname, 'xlsx'),
  },

  'ppt-to-pdf': {
    endpoint: '/api/v1/convert/file/pdf',
    accepts: [
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/vnd.ms-powerpoint',
      'application/vnd.oasis.opendocument.presentation',
    ],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'markdown-to-pdf': {
    endpoint: '/api/v1/convert/markdown/pdf',
    accepts: ['text/markdown', 'text/plain'],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'html-to-pdf': {
    endpoint: '/api/v1/convert/html/pdf',
    accepts: ['text/html', 'application/zip'],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'svg-to-pdf': {
    endpoint: '/api/v1/convert/svg/pdf',
    accepts: ['image/svg+xml'],
    multiFile: true,
    minFiles: 1,
    contentType: PDF,
    fields: (body) => ({ combineIntoSinglePdf: body.combine === 'false' ? 'false' : 'true' }),
    outputName: (files) =>
      files.length === 1 ? rename(files[0].originalname, 'pdf') : 'SVGs.pdf',
  },

  'ebook-to-pdf': {
    endpoint: '/api/v1/convert/ebook/pdf',
    accepts: ['application/epub+zip', 'application/x-mobipocket-ebook', 'application/vnd.amazon.ebook'],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      embedAllFonts: body.embedFonts === 'true' ? 'true' : 'false',
      includeTableOfContents: body.includeToc === 'true' ? 'true' : 'false',
      includePageNumbers: body.includePageNumbers === 'true' ? 'true' : 'false',
      optimizeForEbook: body.optimize === 'false' ? 'false' : 'true',
    }),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'cbz-to-pdf': {
    endpoint: '/api/v1/convert/cbz/pdf',
    accepts: ['application/vnd.comicbook+zip'],
    multiFile: false,
    contentType: PDF,
    fields: () => ({ optimizeForEbook: 'false' }),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'cbr-to-pdf': {
    endpoint: '/api/v1/convert/cbr/pdf',
    accepts: ['application/vnd.comicbook-rar'],
    multiFile: false,
    contentType: PDF,
    fields: () => ({ optimizeForEbook: 'false' }),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'pdf-to-cbz': {
    endpoint: '/api/v1/convert/pdf/cbz',
    accepts: [PDF],
    multiFile: false,
    contentType: 'application/vnd.comicbook+zip',
    fields: (body) => ({ dpi: String(clampInt(body.dpi, 72, 600, 150)) }),
    outputName: (files) => rename(files[0].originalname, 'cbz'),
  },

  'pdf-to-cbr': {
    endpoint: '/api/v1/convert/pdf/cbr',
    accepts: [PDF],
    multiFile: false,
    contentType: 'application/vnd.comicbook-rar',
    fields: (body) => ({ dpi: String(clampInt(body.dpi, 72, 600, 150)) }),
    outputName: (files) => rename(files[0].originalname, 'cbr'),
  },

  'rotate-pdf': {
    endpoint: '/api/v1/general/rotate-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const angle = [90, 180, 270].includes(Number(body.angle)) ? Number(body.angle) : 90;
      return { angle: String(angle) };
    },
    outputName: (files) => files[0].originalname || 'Rotated.pdf',
  },

  'remove-pages': {
    endpoint: '/api/v1/general/remove-pages',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const pages = (body.pages || '').trim();
      if (!pages) {
        throw ApiError.badRequest('Enter the pages to remove, e.g. "1,3-5"');
      }
      return { pageNumbers: pages };
    },
    outputName: (files) => files[0].originalname || 'Trimmed.pdf',
  },

  'rearrange-pages': {
    endpoint: '/api/v1/general/rearrange-pages',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const modes = [
        'REVERSE_ORDER', 'DUPLEX_SORT', 'BOOKLET_SORT', 'ODD_EVEN_SPLIT',
        'REMOVE_FIRST', 'REMOVE_LAST', 'REMOVE_FIRST_AND_LAST',
        'DUPLICATE', 'CUSTOM',
      ];
      const mode = modes.includes(body.mode) ? body.mode : 'REVERSE_ORDER';
      const fields = { customMode: mode };
      if (mode === 'CUSTOM') {
        const pages = (body.pages || '').trim();
        if (!pages) {
          throw ApiError.badRequest('Custom order needs a page list, e.g. "3,1,2"');
        }
        fields.pageNumbers = pages;
      }
      return fields;
    },
    outputName: (files) => files[0].originalname || 'Rearranged.pdf',
  },

  'pdf-to-single-page': {
    endpoint: '/api/v1/general/pdf-to-single-page',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'split-by-sections': {
    endpoint: '/api/v1/general/split-pdf-by-sections',
    accepts: [PDF],
    multiFile: false,
    contentType: ZIP,
    fields: (body) => ({
      pageNumbers: body.pages || 'all',
      splitMode: 'SPLIT_ALL',
      horizontalDivisions: String(clampInt(body.horizontal, 1, 10, 1)),
      verticalDivisions: String(clampInt(body.vertical, 1, 10, 1)),
      merge: body.merge === 'true' ? 'true' : 'false',
    }),
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'split-by-size': {
    endpoint: '/api/v1/general/split-by-size-or-count',
    accepts: [PDF],
    multiFile: false,
    contentType: ZIP,
    fields: (body) => {
      // splitType: 0 = by size, 1 = by page count, 2 = into N documents.
      const type = ['0', '1', '2'].includes(String(body.splitType)) ? Number(body.splitType) : 0;
      const value = (body.splitValue || '').trim();
      if (!value) {
        throw ApiError.badRequest('A split value is required (e.g. "10MB" or "5")');
      }
      return { splitType: String(type), splitValue: value };
    },
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'split-by-chapters': {
    endpoint: '/api/v1/general/split-pdf-by-chapters',
    accepts: [PDF],
    multiFile: false,
    contentType: ZIP,
    fields: (body) => ({
      includeMetadata: body.includeMetadata === 'false' ? 'false' : 'true',
      allowDuplicates: 'false',
      bookmarkLevel: String(clampInt(body.bookmarkLevel, 1, 5, 1)),
    }),
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'overlay-pdfs': {
    // First upload is the base PDF (fileInput); the rest become overlayFiles.
    endpoint: '/api/v1/general/overlay-pdfs',
    accepts: [PDF],
    multiFile: true,
    minFiles: 2,
    fileFields: ['fileInput', 'overlayFiles'],
    contentType: PDF,
    fields: (body) => ({
      overlayMode: body.mode === 'interleaved' ? 'InterleavedOverlay' : 'SequentialOverlay',
      overlayPosition: body.position === 'background' ? '1' : '0',
    }),
    outputName: () => 'Overlaid.pdf',
  },

  'multi-page-layout': {
    endpoint: '/api/v1/general/multi-page-layout',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      // DEFAULT mode: pagesPerSheet must be 2 or a perfect square.
      const allowed = [2, 4, 9, 16, 25, 36, 49, 64, 81, 100];
      const per = Number(body.pagesPerSheet);
      const pagesPerSheet = allowed.includes(per) ? per : 2;
      return {
        mode: 'DEFAULT',
        pagesPerSheet: String(pagesPerSheet),
        addBorder: body.addBorder === 'true' ? 'true' : 'false',
        borderWidth: '1',
        topMargin: '0',
        bottomMargin: '0',
        leftMargin: '0',
        rightMargin: '0',
        innerMargin: '0',
      };
    },
    outputName: (files) => files[0].originalname || 'Layout.pdf',
  },

  'scale-pages': {
    endpoint: '/api/v1/general/scale-pages',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      pageSize: body.pageSize || 'A4',
      orientation: body.orientation === 'landscape' ? 'LANDSCAPE' : 'PORTRAIT',
      scaleFactor: String(clampFloat(body.scale, 0.1, 4, 1)),
    }),
    outputName: (files) => files[0].originalname || 'Scaled.pdf',
  },

  'crop-pdf': {
    endpoint: '/api/v1/general/crop',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const x = clampFloat(body.x, -2000, 2000, 0);
      const y = clampFloat(body.y, -2000, 2000, 0);
      const width = clampFloat(body.width, 1, 5000, 595);
      const height = clampFloat(body.height, 1, 5000, 842);
      return {
        x: String(x),
        y: String(y),
        width: String(width),
        height: String(height),
        removeDataOutsideCrop: body.removeOutside === 'false' ? 'false' : 'true',
        autoCrop: body.autoCrop === 'true' ? 'true' : 'false',
      };
    },
    outputName: (files) => files[0].originalname || 'Cropped.pdf',
  },

  'auto-split-pdf': {
    endpoint: '/api/v1/misc/auto-split-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: ZIP,
    fields: (body) => ({ duplexMode: body.duplex === 'true' ? 'true' : 'false' }),
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'remove-images': {
    endpoint: '/api/v1/general/remove-image-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => files[0].originalname || 'NoImages.pdf',
  },

  'booklet-imposition': {
    endpoint: '/api/v1/general/booklet-imposition',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      pagesPerSheet: '2',
      spineLocation: body.spine === 'right' ? 'RIGHT' : 'LEFT',
      addBorder: body.addBorder === 'true' ? 'true' : 'false',
      addGutter: 'false',
      gutterSize: '12',
      doubleSided: body.doubleSided === 'false' ? 'false' : 'true',
      duplexPass: 'BOTH',
      flipOnShortEdge: 'false',
    }),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'poster-pdf': {
    endpoint: '/api/v1/general/split-for-poster-print',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      pageSize: ['A0', 'A1', 'A2', 'A3', 'A4', 'LETTER', 'LEGAL'].includes(body.pageSize)
        ? body.pageSize
        : 'A4',
      xFactor: String(clampInt(body.xFactor, 1, 10, 2)),
      yFactor: String(clampInt(body.yFactor, 1, 10, 2)),
      rightToLeft: body.rightToLeft === 'true' ? 'true' : 'false',
    }),
    outputName: (files) => rename(files[0].originalname, 'pdf'),
  },

  'unlock-pdf': {
    endpoint: '/api/v1/security/remove-password',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const password = body.password || '';
      if (!password) {
        throw ApiError.badRequest('Enter the password the PDF is protected with');
      }
      return { password };
    },
    outputName: (files) => files[0].originalname || 'Unlocked.pdf',
  },

  'sanitize-pdf': {
    endpoint: '/api/v1/security/sanitize-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      removeJavaScript: body.removeJavaScript === 'false' ? 'false' : 'true',
      removeEmbeddedFiles: body.removeEmbeddedFiles === 'false' ? 'false' : 'true',
      removeXMPMetadata: body.removeXMPMetadata === 'false' ? 'false' : 'true',
      removeMetadata: body.removeMetadata === 'false' ? 'false' : 'true',
      removeLinks: body.removeLinks === 'true' ? 'true' : 'false',
      removeFonts: body.removeFonts === 'true' ? 'true' : 'false',
    }),
    outputName: (files) => files[0].originalname || 'Sanitized.pdf',
  },

  'auto-redact': {
    endpoint: '/api/v1/security/auto-redact',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const listOfText = (body.listOfText || '').trim();
      if (!listOfText) {
        throw ApiError.badRequest('Enter the words or phrases to redact, separated by commas');
      }
      return {
        listOfText,
        useRegex: body.useRegex === 'true' ? 'true' : 'false',
        wholeWordSearch: body.wholeWord === 'true' ? 'true' : 'false',
        redactColor: body.color || '#000000',
        customPadding: '0',
        convertPDFToImage: 'false',
      };
    },
    outputName: (files) => files[0].originalname || 'Redacted.pdf',
  },

  'remove-cert-sign': {
    endpoint: '/api/v1/security/remove-cert-sign',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => files[0].originalname || 'Unsigned.pdf',
  },

  'get-info-on-pdf': {
    endpoint: '/api/v1/security/get-info-on-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: 'application/json',
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'json'),
  },

  'decompress-pdf': {
    endpoint: '/api/v1/misc/decompress-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => files[0].originalname || 'Decompressed.pdf',
  },

  'repair-pdf': {
    endpoint: '/api/v1/misc/repair',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => files[0].originalname || 'Repaired.pdf',
  },

  'ocr-pdf': {
    endpoint: '/api/v1/misc/ocr-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      // List<String> on the Java side — a comma-separated value binds fine.
      languages: body.languages || 'eng',
      sidecar: 'false',
      deskew: body.deskew === 'true' ? 'true' : 'false',
      clean: 'false',
      cleanFinal: 'false',
      ocrType: ['skip-text', 'force-ocr'].includes(body.ocrType) ? body.ocrType : 'skip-text',
      ocrRenderType: 'hocr',
      removeImagesAfter: 'false',
    }),
    outputName: (files) => files[0].originalname || 'OCR.pdf',
  },

  'flatten-pdf': {
    endpoint: '/api/v1/misc/flatten',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      flattenOnlyForms: body.onlyForms === 'true' ? 'true' : 'false',
      renderDpi: String(clampInt(body.dpi, 72, 600, 150)),
    }),
    outputName: (files) => files[0].originalname || 'Flattened.pdf',
  },

  'extract-images': {
    endpoint: '/api/v1/misc/extract-images',
    accepts: [PDF],
    multiFile: false,
    contentType: ZIP,
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'extract-image-scans': {
    endpoint: '/api/v1/misc/extract-image-scans',
    accepts: [PDF],
    multiFile: false,
    contentType: ZIP,
    fields: (body) => ({
      angleThreshold: String(clampInt(body.angleThreshold, 1, 90, 5)),
      tolerance: String(clampInt(body.tolerance, 0, 100, 10)),
      minArea: String(clampInt(body.minArea, 100, 1000000, 8000)),
      minContourArea: String(clampInt(body.minContourArea, 100, 1000000, 500)),
      borderSize: String(clampInt(body.borderSize, 0, 50, 1)),
    }),
    outputName: (files) => rename(files[0].originalname, 'zip'),
  },

  'remove-blank-pages': {
    endpoint: '/api/v1/misc/remove-blanks',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      threshold: String(clampInt(body.threshold, 1, 100, 10)),
      whitePercent: String(clampFloat(body.whitePercent, 0, 100, 99.9)),
    }),
    outputName: (files) => files[0].originalname || 'NoBlanks.pdf',
  },

  'auto-rename': {
    endpoint: '/api/v1/misc/auto-rename',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({ useFirstTextAsFallback: 'false' }),
    // null = keep the filename Stirling detected (the whole point of the tool).
    outputName: () => null,
  },

  'add-stamp': {
    endpoint: '/api/v1/misc/add-stamp',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const stampText = (body.stampText || '').trim();
      if (!stampText) throw ApiError.badRequest('Stamp text is required');
      return {
        stampType: 'text',
        stampText,
        alphabet: 'roman',
        fontSize: String(clampInt(body.size, 8, 96, 30)),
        rotation: String(clampInt(body.angle, -90, 90, 0)),
        opacity: String(clampFloat(body.opacity, 0.05, 1, 0.5)),
        position: String(clampInt(body.position, 1, 9, 8)),
        overrideX: '-1',
        overrideY: '-1',
        customMargin: String(clampInt(body.margin, 0, 200, 20)),
        // Same NPE risk as watermark-pdf: send the color explicitly.
        customColor: body.color || '#d3d3d3',
      };
    },
    outputName: (files) => files[0].originalname || 'Stamped.pdf',
  },

  'add-page-numbers': {
    endpoint: '/api/v1/misc/add-page-numbers',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      customMargin: String(clampInt(body.margin, 0, 200, 20)),
      fontSize: String(clampInt(body.size, 6, 72, 12)),
      fontType: 'Helvetica',
      fontColor: body.color || '#000000',
      zeroPad: String(clampInt(body.zeroPad, 0, 6, 0)),
      position: String(clampInt(body.position, 1, 9, 8)),
      startingNumber: String(clampInt(body.startAt, 0, 10000, 1)),
      pagesToNumber: body.pages || 'all',
      customText: body.customText || '',
    }),
    outputName: (files) => files[0].originalname || 'Numbered.pdf',
  },

  'add-image-to-pdf': {
    // Upload 1 = the PDF (fileInput), upload 2 = the image (imageFile).
    endpoint: '/api/v1/misc/add-image',
    accepts: [PDF],
    acceptsPerFile: [
      [PDF],
      ['image/jpeg', 'image/png', 'image/webp', 'image/heic'],
    ],
    multiFile: true,
    minFiles: 2,
    fileFields: ['fileInput', 'imageFile'],
    contentType: PDF,
    fields: (body) => ({
      x: String(clampFloat(body.x, -2000, 2000, 50)),
      y: String(clampFloat(body.y, -2000, 2000, 50)),
      everyPage: body.everyPage === 'true' ? 'true' : 'false',
    }),
    outputName: () => 'Stamped.pdf',
  },

  'update-metadata': {
    endpoint: '/api/v1/misc/update-metadata',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      if (body.deleteAll === 'true') return { deleteAll: 'true' };
      const keys = ['author', 'title', 'subject', 'keywords', 'creator', 'producer'];
      const fields = {};
      for (const key of keys) {
        const value = (body[key] || '').trim();
        if (value) fields[key] = value;
      }
      return fields;
    },
    outputName: (files) => files[0].originalname || 'Metadata.pdf',
  },

  'replace-invert-color': {
    endpoint: '/api/v1/misc/replace-invert-pdf',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => {
      const options = ['FULL_INVERSION', 'CUSTOM_COLOR', 'HIGH_CONTRAST_COLOR', 'COLOR_SPACE_CONVERSION'];
      const option = options.includes(body.option) ? body.option : 'FULL_INVERSION';
      return {
        replaceAndInvertOption: option,
        highContrastColorCombination: 'WHITE_TEXT_ON_BLACK',
        backGroundColor: body.background || '#ffffff',
        textColor: body.textColor || '#000000',
      };
    },
    outputName: (files) => files[0].originalname || 'Adjusted.pdf',
  },

  'show-javascript': {
    endpoint: '/api/v1/misc/show-javascript',
    accepts: [PDF],
    multiFile: false,
    contentType: 'text/plain',
    fields: () => ({}),
    outputName: (files) => rename(files[0].originalname, 'txt'),
  },

  'scanner-effect': {
    endpoint: '/api/v1/misc/scanner-effect',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: (body) => ({
      quality: ['low', 'medium', 'high'].includes(body.quality) ? body.quality : 'high',
      rotation: 'slight',
      colorspace: body.colorspace === 'color' ? 'color' : 'grayscale',
      border: String(clampInt(body.border, 0, 200, 20)),
      rotate: '0',
      rotateVariance: '2',
      brightness: '1',
      contrast: '1',
      blur: '1',
      noise: '8',
      yellowish: body.yellowish === 'true' ? 'true' : 'false',
      resolution: String(clampInt(body.resolution, 72, 600, 300)),
      advancedEnabled: 'false',
    }),
    outputName: (files) => files[0].originalname || 'Scanned.pdf',
  },

  'unlock-pdf-forms': {
    endpoint: '/api/v1/misc/unlock-pdf-forms',
    accepts: [PDF],
    multiFile: false,
    contentType: PDF,
    fields: () => ({}),
    outputName: (files) => files[0].originalname || 'UnlockedForms.pdf',
  },
};

export function getTool(id) {
  const tool = TOOLS[id];
  if (!tool) {
    throw ApiError.badRequest(`Unknown tool "${id}"`, {
      supported: Object.keys(TOOLS),
    });
  }
  return tool;
}

/**
 * Rejects mismatched uploads before they cost a quota credit or a round trip.
 * Some clients send application/octet-stream for everything, so an unknown
 * type falls through to the extension.
 */
export function assertAccepted(tool, toolId, files) {
  if (tool.multiFile) {
    const min = tool.minFiles ?? 1;
    if (files.length < min) {
      throw ApiError.badRequest(
        `"${toolId}" needs at least ${min} file${min === 1 ? '' : 's'}, got ${files.length}`,
      );
    }
  } else if (files.length !== 1) {
    throw ApiError.badRequest(
      `"${toolId}" takes exactly one file, got ${files.length}`,
    );
  }

  const extensions = {
    'application/pdf': ['pdf'],
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['docx'],
    'application/msword': ['doc'],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['xlsx'],
    'application/vnd.ms-excel': ['xls'],
    'image/jpeg': ['jpg', 'jpeg'],
    'image/png': ['png'],
    'image/webp': ['webp'],
    'image/heic': ['heic'],
    'image/svg+xml': ['svg'],
    'text/csv': ['csv'],
    'text/plain': ['txt', 'md', 'markdown'],
    'text/markdown': ['md', 'markdown', 'txt'],
    'text/html': ['html', 'htm', 'zip'],
    'application/zip': ['zip', 'epub', 'cbz', 'html', 'htm'],
    'application/epub+zip': ['epub'],
    'application/x-mobipocket-ebook': ['mobi'],
    'application/vnd.amazon.ebook': ['azw3'],
    'application/vnd.comicbook+zip': ['cbz'],
    'application/vnd.comicbook-rar': ['cbr'],
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': ['pptx'],
    'application/vnd.ms-powerpoint': ['ppt'],
    'application/vnd.oasis.opendocument.presentation': ['odp'],
  };

  // Tools whose uploads go to different Stirling fields (e.g. add-image:
  // fileInput=PDF, imageFile=PNG) validate each slot against its own list.
  const acceptsPerFile = tool.acceptsPerFile?.length === files.length ? tool.acceptsPerFile : null;

  files.forEach((file, index) => {
    const accepted = acceptsPerFile ? acceptsPerFile[index] : tool.accepts;
    const allowedExtensions = new Set(
      accepted.flatMap((mime) => extensions[mime] ?? []),
    );
    if (accepted.includes(file.mimetype)) return;
    const ext = (file.originalname.split('.').pop() || '').toLowerCase();
    if (allowedExtensions.has(ext)) return;
    throw ApiError.badRequest(
      `"${file.originalname}" is not a valid input for "${toolId}"`,
      { accepts: [...allowedExtensions] },
    );
  });
}
