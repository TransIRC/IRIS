import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Import your emoji list from your custom file
import '../utils/irc_safe_emojis.dart'; // Adjust path as needed

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSendMessage;
  final VoidCallback onProfilePressed;
  final Future<String?> Function(String) onAttachmentSelected; // <-- FIXED!
  final List<String> allUsernames;

  const MessageInput({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onProfilePressed,
    required this.onAttachmentSelected,
    required this.allUsernames,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _suggestionOverlay;
  List<String> _suggestions = [];
  int _selectedSuggestion = 0;

  @override
  void dispose() {
    _focusNode.dispose();
    _removeSuggestions();
    super.dispose();
  }

  void _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final url = await widget.onAttachmentSelected(pickedFile.path); // now returns String?
      if (url != null && url.isNotEmpty) {
        final controller = widget.controller;
        final text = controller.text;
        final selection = controller.selection;
        final cursor = selection.baseOffset < 0
            ? text.length
            : selection.baseOffset;
        final filename = url.split('/').last;
        final hyperlink = '[$filename]($url)';
        final newText = text.replaceRange(
            cursor, cursor, hyperlink + ' ');
        controller.value = controller.value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(
              offset: cursor + hyperlink.length + 1),
        );
      }
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (selection.baseOffset < 0) {
      _removeSuggestions();
      return;
    }

    final cursor = selection.baseOffset;
    final triggerIndex = text.lastIndexOf('@', cursor - 1);
    if (triggerIndex == -1 ||
        (triggerIndex > 0 && !RegExp(r'[\s]').hasMatch(text[triggerIndex - 1]))) {
      _removeSuggestions();
      return;
    }

    final afterAt = text.substring(triggerIndex + 1, cursor);
    if (afterAt.isEmpty && _suggestions.isEmpty) {
      _removeSuggestions();
      return;
    }

    final matches = widget.allUsernames
        .where((u) => u.toLowerCase().startsWith(afterAt.toLowerCase()))
        .toList();

    if (matches.isEmpty) {
      _removeSuggestions();
      return;
    }
    _showSuggestions(matches, triggerIndex, afterAt);
  }

  void _showSuggestions(List<String> suggestions, int triggerIndex, String afterAt) {
    _removeSuggestions();
    _suggestions = suggestions;
    _selectedSuggestion = 0;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final overlay = Overlay.of(context);

    final textFieldBox = context.findRenderObject() as RenderBox;
    final textFieldOffset = textFieldBox.localToGlobal(Offset.zero);

    _suggestionOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: textFieldOffset.dx + 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + size.height + 8,
        width: size.width - 32,
        child: Material(
          elevation: 6,
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF232428),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, idx) {
                final username = _suggestions[idx];
                return ListTile(
                  dense: true,
                  tileColor: idx == _selectedSuggestion
                      ? Colors.blueGrey[700]
                      : Colors.transparent,
                  title: Text('@$username',
                      style: TextStyle(
                        color: idx == _selectedSuggestion
                            ? Colors.white
                            : Colors.white70,
                      )),
                  onTap: () {
                    _insertSuggestion(username);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_suggestionOverlay!);
  }

  void _removeSuggestions() {
    _suggestionOverlay?.remove();
    _suggestionOverlay = null;
    _suggestions = [];
  }

  void _insertSuggestion(String username) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.baseOffset;
    final triggerIndex = text.lastIndexOf('@', cursor - 1);

    if (triggerIndex == -1) return;
    final afterAt = text.substring(triggerIndex + 1, cursor);

    final newText =
        text.replaceRange(triggerIndex, cursor, '@$username ');
    final newCursor = triggerIndex + username.length + 2; // @ + username + space

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _removeSuggestions();
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.baseOffset;

    final newText = text.replaceRange(cursor, cursor, emoji);
    final newCursor = cursor + emoji.length;

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _showEmojiPicker() {
    // Using a modal bottom sheet for emoji picker
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232428),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: 250,
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            itemCount: ircSafeEmojis.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final emoji = ircSafeEmojis[index];
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _insertEmoji(emoji);
                },
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // This container is now always "anchored" to the bottom.
    // The Row is replaced by a Stack+IntrinsicHeight+Align to ensure
    // the buttons stay anchored while the TextField grows in height.
    return Container(
      color: const Color(0xFF232428),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Row with buttons anchored to bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.white70),
                      tooltip: "Profile",
                      onPressed: widget.onProfilePressed,
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.white70),
                      tooltip: "Emoji Picker",
                      onPressed: _showEmojiPicker,
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white70),
                      onPressed: _pickAndUploadImage,
                      tooltip: "Attach Image",
                    ),
                    // Expanded TextField
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // You can tweak maxHeight as needed
                          maxHeight: 120,
                        ),
                        child: Scrollbar(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focusNode,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Send a message...",
                              hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
                              filled: true,
                              fillColor: const Color(0xFF383A40),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            ),
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            onChanged: (value) => _onTextChanged(),
                            onEditingComplete: _removeSuggestions,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF5865F2)),
                      onPressed: () {
                        widget.onSendMessage();
                        _removeSuggestions();
                      },
                      tooltip: "Send",
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}