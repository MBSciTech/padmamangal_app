import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/vault_service.dart';
import '../services/chat_service.dart' show ChatFile;
import '../utils/file_picker_helper.dart';
import '../utils/file_downloader_helper.dart';
import '../utils/video_preview_helper.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final VaultService _vaultService = VaultService();
  List<VaultDocument> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final docs = await _vaultService.fetchDocuments();
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnack('Failed to load vault documents: $e');
      }
    }
  }

  Future<void> _uploadDocument() async {
    try {
      final picked = await pickFileAttachment();
      if (picked == null) return;

      setState(() => _isUploading = true);

      final newDoc = await _vaultService.uploadDocument(
        ChatFile(data: picked.data, name: picked.name, type: picked.type),
      );

      if (mounted) {
        setState(() {
          _documents.insert(0, newDoc);
          _isUploading = false;
        });
        _showSuccessSnack('Document securely uploaded to vault.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showErrorSnack('Upload failed: $e');
      }
    }
  }

  Future<void> _downloadAndPreview(VaultDocument doc) async {
    _showLoadingDialog('Decrypting document...');
    try {
      final downloadedFile = await _vaultService.downloadDocument(doc.id);
      if (mounted) {
        Navigator.of(context).pop(); // dismiss dialog
        // Just trigger standard download/open logic used in chat
        downloadOrOpenFile(downloadedFile);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnack('Decryption failed: $e');
      }
    }
  }

  Future<void> _deleteDocument(VaultDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete "${doc.name}" from the vault? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _vaultService.deleteDocument(doc.id);
      if (mounted) {
        setState(() {
          _documents.removeWhere((d) => d.id == doc.id);
        });
        _showSuccessSnack('Document deleted.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnack('Failed to delete document: $e');
      }
    }
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '\${(bytes / 1024).toStringAsFixed(1)} KB';
    return '\${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  IconData _getIconForType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.jpg') || lower.endsWith('.png') || lower.endsWith('.jpeg')) return Icons.image;
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return Icons.video_file;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Document Vault', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 80, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('Your vault is empty', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Securely store sensitive family documents here.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getIconForType(doc.name), color: theme.colorScheme.onPrimaryContainer),
                        ),
                        title: Text(doc.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("\${_formatSize(doc.size)} • \${DateFormat('MMM d, yyyy').format(doc.createdAt)}"),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'download') _downloadAndPreview(doc);
                            else if (value == 'delete') _deleteDocument(doc);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'download',
                              child: Row(children: [Icon(Icons.download, size: 20), SizedBox(width: 8), Text('Decrypt & View')]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                            ),
                          ],
                        ),
                        onTap: () => _downloadAndPreview(doc),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadDocument,
        backgroundColor: theme.colorScheme.primary,
        icon: _isUploading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_moderator),
        label: Text(_isUploading ? 'Encrypting...' : 'Secure Upload'),
      ),
    );
  }
}
