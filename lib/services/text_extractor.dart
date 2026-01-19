import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'dart:convert';
import 'dart:typed_data';

class TextExtractor {
  static Future<String> extractText(File file, String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    
    try {
      switch (extension) {
        case 'pdf':
          return await _extractFromPdf(file);
        case 'txt':
          return await _extractFromTxt(file);
        case 'doc':
        case 'docx':
          return await _extractFromWord(file, extension);
        default:
          return await _extractFromTxt(file); // 默认尝试作为文本文件
      }
    } catch (e) {
      throw Exception('提取文字失败: $e');
    }
  }

  static Future<String> _extractFromPdf(File file) async {
    PdfDocument? document;
    try {
      final bytes = await file.readAsBytes();
      document = PdfDocument(inputBytes: bytes);
      
      // 创建文本提取器（必须使用实例方法）
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      
      // 提取所有页面的文字（使用实例方法调用）
      final String text = extractor.extractText();
      
      document.dispose();
      
      return text.trim();
    } catch (e) {
      document?.dispose();
      throw Exception('PDF解析失败: $e。请确保PDF文件包含可提取的文字内容（非扫描图片）');
    }
  }

  static Future<String> _extractFromTxt(File file) async {
    try {
      // 尝试不同的编码
      try {
        return await file.readAsString(encoding: utf8);
      } catch (e) {
        // 如果UTF-8失败，尝试GBK或其他编码
        final bytes = await file.readAsBytes();
        // 简单处理：使用UTF-8解码，忽略错误
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e) {
      throw Exception('读取文本文件失败: $e');
    }
  }

  /// 从 Word 文档中提取文字（.doc 或 .docx）
  static Future<String> _extractFromWord(File file, String extension) async {
    try {
      if (extension == 'docx') {
        // .docx 是基于 XML 的格式，可以手动解析
        return await _extractFromDocx(file);
      } else {
        // .doc 是二进制格式，需要特殊处理
        // 对于 .doc 文件，尝试作为文本读取，或提示用户转换为 .docx
        throw Exception(
          '暂不支持 .doc 格式（旧版 Word 格式）。\n'
          '请将文件另存为 .docx 格式后重试，或使用在线工具转换为 .docx。'
        );
      }
    } catch (e) {
      throw Exception('Word 文档解析失败: $e');
    }
  }

  /// 从 .docx 文件中提取文字
  /// .docx 实际上是一个 ZIP 文件，包含 XML 文件
  static Future<String> _extractFromDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      
      // .docx 是一个 ZIP 文件，需要解压并读取 word/document.xml
      // 由于 archive 包已在使用中，我们可以使用它来解压
      final archive = await _extractDocxArchive(bytes);
      
      // 查找 word/document.xml
      ArchiveFile? documentFile;
      for (final file in archive.files) {
        if (file.name.toLowerCase() == 'word/document.xml') {
          documentFile = file;
          break;
        }
      }
      
      if (documentFile == null) {
        throw Exception('无法在 .docx 文件中找到 document.xml');
      }
      
      // 读取 XML 内容
      // 安全地获取文件内容
      List<int> xmlBytes;
      final content = documentFile.content;
      
      if (content is List<int>) {
        xmlBytes = content;
      } else if (content is Uint8List) {
        xmlBytes = content.toList();
      } else if (content != null) {
        try {
          xmlBytes = List<int>.from(content);
        } catch (e) {
          throw Exception('无法读取 XML 内容: $e');
        }
      } else {
        throw Exception('XML 内容为空');
      }
      
      final xmlContent = utf8.decode(xmlBytes);
      
      // 简单的 XML 文本提取（移除 XML 标签，提取文本内容）
      // 使用正则表达式移除 XML 标签，保留文本内容
      String text = xmlContent
          .replaceAll(RegExp(r'<[^>]+>'), ' ') // 移除所有 XML 标签
          .replaceAll(RegExp(r'\s+'), ' ') // 合并多个空格
          .trim();
      
      // 解码 XML 实体
      text = text
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'")
          .replaceAll('&#10;', '\n') // 换行符
          .replaceAll('&#13;', '\r') // 回车符
          .replaceAll(RegExp(r'&#\d+;'), ''); // 移除其他数字实体
      
      if (text.isEmpty) {
        throw Exception('文档中未找到可提取的文字内容');
      }
      
      return text;
    } catch (e) {
      // 如果解析失败，尝试更简单的方法
      if (e.toString().contains('暂不支持') || e.toString().contains('未找到')) {
        rethrow;
      }
      throw Exception('解析 .docx 文件失败: $e');
    }
  }

  /// 解压 .docx 文件（实际上是一个 ZIP 文件）
  static Future<Archive> _extractDocxArchive(List<int> bytes) async {
    try {
      // 检查是否是 ZIP 格式（.docx 是基于 ZIP 的）
      // 简单的检查：ZIP 文件以 "PK" 开头
      if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        throw Exception('不是有效的 .docx 文件（应该是 ZIP 格式）');
      }
      
      // 使用 archive 包解压
      final archive = ZipDecoder().decodeBytes(bytes);
      return archive;
    } catch (e) {
      throw Exception('无法解压 .docx 文件: $e');
    }
  }
}
