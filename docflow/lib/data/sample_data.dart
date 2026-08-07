import '../models/document.dart';

/// Placeholder library content. Mirrors the file names used throughout the
/// ProScan mockups so the screens read the same as the design.
class SampleData {
  SampleData._();

  /// The six files on the kit's recent-files screen, in its order, each paired
  /// with the page render exported from that node.
  static const List<DocumentFile> recentFiles = [
    DocumentFile(
      name: 'Job Application Letter',
      format: DocFormat.pdf,
      sizeLabel: '456 KB',
      date: '12/30/2023',
      time: '09:41',
      pages: 2,
      starred: true,
      thumbnail: 'assets/thumbnails/doc_01.png',
    ),
    DocumentFile(
      name: 'Requirements Document',
      format: DocFormat.docx,
      sizeLabel: '1.2 MB',
      date: '12/29/2023',
      time: '10:20',
      pages: 14,
      thumbnail: 'assets/thumbnails/doc_02.png',
    ),
    DocumentFile(
      name: 'Recommendation Letter',
      format: DocFormat.pdf,
      sizeLabel: '389 KB',
      date: '12/28/2023',
      time: '09:37',
      pages: 1,
      thumbnail: 'assets/thumbnails/doc_03.png',
    ),
    DocumentFile(
      name: 'Business Plan Proposal',
      format: DocFormat.docx,
      sizeLabel: '824 KB',
      date: '12/27/2023',
      time: '18:28',
      pages: 18,
      thumbnail: 'assets/thumbnails/doc_04.png',
    ),
    DocumentFile(
      name: 'Legal & Terms of Reference',
      format: DocFormat.pdf,
      sizeLabel: '512 KB',
      date: '12/26/2023',
      time: '16:53',
      pages: 9,
      thumbnail: 'assets/thumbnails/doc_05.png',
    ),
    DocumentFile(
      name: 'Software Requirements',
      format: DocFormat.pdf,
      sizeLabel: '1.1 MB',
      date: '12/25/2023',
      time: '12:45',
      pages: 24,
      thumbnail: 'assets/thumbnails/doc_06.png',
    ),
  ];

  /// Spreadsheets, decks and images beyond the recent list. Kept separate so
  /// the converter still has eligible inputs for the non-PDF tools.
  static const List<DocumentFile> otherFiles = [
    DocumentFile(
      name: 'Quarterly Budget',
      format: DocFormat.xlsx,
      sizeLabel: '249 KB',
      date: '12/24/2023',
      time: '16:02',
      pages: 6,
    ),
    DocumentFile(
      name: 'Team Offsite Deck',
      format: DocFormat.pptx,
      sizeLabel: '563 KB',
      date: '12/23/2023',
      time: '11:35',
      pages: 22,
    ),
    DocumentFile(
      name: 'Scanned Receipt',
      format: DocFormat.jpg,
      sizeLabel: '800 KB',
      date: '12/22/2023',
      time: '08:14',
    ),
  ];

  /// Everything in the library — what the Files tab and the converter browse.
  static const List<DocumentFile> allFiles = [...recentFiles, ...otherFiles];

  static const List<DocFolder> folders = [
    DocFolder(
      name: 'My Certificate Files',
      fileCount: 12,
      date: '12/26/2023',
      time: '17:29',
    ),
    DocFolder(
      name: 'My Home Files',
      fileCount: 8,
      date: '12/24/2023',
      time: '20:08',
    ),
  ];

  static int get totalFiles => 125;
}
