import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../models/channel.dart'; // Import the Message class
import '../config.dart'; // Needed for apiHost and apiPort
import 'link_preview.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;
  final ScrollController scrollController;
  final Map<String, String> userAvatars;

  const MessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.userAvatars,
  });

  String? _getDisplayAvatarUrl(String username) {
    final storedAvatarUrl = userAvatars[username];
    if (storedAvatarUrl != null && storedAvatarUrl.isNotEmpty) {
      return storedAvatarUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: messages.length,
      itemBuilder: (context, idx) {
        final message = messages[idx];
        final String? displayAvatarUrl = _getDisplayAvatarUrl(message.from);

        // Show loading indicator when we reach the top of history and the message is historical
        if (idx == 0 && message.isHistorical) {
          return Column(
            children: [
              const Center(child: CircularProgressIndicator()),
              _buildMessageItem(message, displayAvatarUrl),
            ],
          );
        }

        return _buildMessageItem(message, displayAvatarUrl);
      },
    );
  }

  Widget _buildMessageItem(Message message, String? displayAvatarUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF5865F2),
            radius: 18,
            backgroundImage: displayAvatarUrl != null ? NetworkImage(displayAvatarUrl) : null,
            child: displayAvatarUrl == null
                ? Text(
                    message.from.isNotEmpty ? message.from[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.from,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                _buildMessageContent(message.content),
                ..._extractLinks(message.content).map((url) => LinkPreview(url: url)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String content) {
    // Check if this is an image URL by extension
    final isImageUrl = content.toLowerCase().endsWith('.jpg') ||
                       content.toLowerCase().endsWith('.jpeg') ||
                       content.toLowerCase().endsWith('.png') ||
                       content.toLowerCase().endsWith('.gif');

    if (isImageUrl) {
      print("[MessageList] Loading image from URL: $content");
      return GestureDetector(
        onTap: () {
          // Could expand to show in full screen
        },
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              content,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print("[MessageList] Error loading image: $error");
                // If image fails to load, show the URL as text
                return Container(
                  padding: EdgeInsets.all(8),
                  child: Text(content,
                    style: TextStyle(color: Colors.white70)),
                );
              },
            ),
          ),
        ),
      );
    }

    // Regular text message (may include code blocks)
    return RichText(
      text: TextSpan(
        children: _buildMessageSpans(content),
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  List<String> _extractLinks(String text) {
    final regex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);
    return regex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<InlineSpan> _buildMessageSpans(String content) {
    final List<InlineSpan> spans = [];
    final codeBlockRegex = RegExp(r'```(\w+)?\n([\s\S]*?)\n```');
    int lastMatchEnd = 0;

    for (RegExpMatch match in codeBlockRegex.allMatches(content)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: content.substring(lastMatchEnd, match.start)));
      }

      final language = match.group(1);
      final code = match.group(2)!;

      spans.add(
        WidgetSpan(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(5.0),
            ),
            child: HighlightView(
              code,
              language: language ?? 'plaintext',
              theme: atomOneDarkTheme,
              textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14.0),
            ),
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastMatchEnd)));
    }

    return spans;
  }
}
