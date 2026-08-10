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
    'text/csv': ['csv'],
    'text/plain': ['txt'],
  };
  const allowedExtensions = new Set(
    tool.accepts.flatMap((mime) => extensions[mime] ?? []),
  );

  for (const file of files) {
    if (tool.accepts.includes(file.mimetype)) continue;
    const ext = (file.originalname.split('.').pop() || '').toLowerCase();
    if (allowedExtensions.has(ext)) continue;
    throw ApiError.badRequest(
      `"${file.originalname}" is not a valid input for "${toolId}"`,
      { accepts: [...allowedExtensions] },
    );
  }
}
