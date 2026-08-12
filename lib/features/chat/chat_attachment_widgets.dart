import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/chat.dart';

class ChatAttachmentContent extends StatelessWidget {
  const ChatAttachmentContent({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ChatMessage message;
  final bool isMe;

  Color get _fg => isMe ? AppColors.white : AppColors.textPrimary;
  Color get _muted => isMe ? AppColors.white.withValues(alpha: 0.75) : AppColors.textSecondary;

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(Env.resolveMediaUrl(url));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openImage(BuildContext context, String url) {
    final resolved = Env.resolveMediaUrl(url);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.contain,
                width: double.infinity,
                height: MediaQuery.sizeOf(ctx).height * 0.8,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = message.attachmentUrl!;
    final children = <Widget>[];

    if (message.isImageAttachment) {
      children.add(
        GestureDetector(
          onTap: () => _openImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: Env.resolveMediaUrl(url),
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                width: 220,
                height: 160,
                color: _muted.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _fg,
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                width: 220,
                height: 120,
                color: _muted.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined, color: _fg),
              ),
            ),
          ),
        ),
      );
    } else {
      children.add(
        InkWell(
          onTap: () => _openUrl(url),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: (isMe ? Colors.white : AppColors.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_outlined, color: _fg, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.attachmentName ?? 'Файл',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.open_in_new, color: _muted, size: 16),
              ],
            ),
          ),
        ),
      );
    }

    if (message.text.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        Text(
          message.text,
          style: TextStyle(color: _fg, fontSize: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
