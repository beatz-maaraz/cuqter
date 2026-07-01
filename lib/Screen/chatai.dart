import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/providers/chat_provider.dart';
import '../widgets/animated_send_button.dart';
import '../widgets/chat_message_text.dart';

class AIChatScreen extends StatefulWidget {
  final bool isDesktop;
  const AIChatScreen({super.key, this.isDesktop = false});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Listen to changes in the provider to scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.addListener(_scrollToBottom);
    });
  }

  @override
  void dispose() {
    // Remove listener when screen is disposed to avoid memory leaks
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.removeListener(_scrollToBottom);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isDesktop,
        title: const Text(
          "Cuqter AI Bot",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          IconButton(
            icon: huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedDelete02,
              color: Theme.of(context).colorScheme.error,
              size: 22,
            ),
            onPressed: () => chatProvider.clearMessages(),
            tooltip: "Clear Chat",
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: Column(
        children: [
          Expanded(
            child: chatProvider.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount:
                        chatProvider.messages.length +
                        (chatProvider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chatProvider.messages.length) {
                        return _buildLoadingBubble();
                      }
                      final msg = chatProvider.messages[index];
                      bool isUser = msg['role'] == 'user';
                      return _buildChatBubble(msg['text']!, isUser);
                    },
                  ),
          ),
          _buildInputArea(chatProvider),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 80,
            color: colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            "How can I help you?",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser
                ? const Radius.circular(20)
                : const Radius.circular(0),
            bottomRight: isUser
                ? const Radius.circular(0)
                : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ChatMessageText(
          text: text,
          baseStyle: TextStyle(
            color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
            fontSize: 16,
            height: 1.4,
          ),
          linkColor: isUser
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue[300]!
                  : Colors.blue[100]!)
              : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue[300]!
                  : Colors.blue[800]!),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "Ask any question...",
                hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _handleSend(provider),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSendButton(
            onTap: () => _handleSend(provider),
            backgroundColor: colorScheme.primary,
            iconColor: colorScheme.onPrimary,
            iconSize: 22.0,
            radius: 24.0,
          ),
        ],
      ),
    );
  }

  void _handleSend(ChatProvider provider) {
    if (_controller.text.isNotEmpty) {
      final text = _controller.text;
      _controller.clear();
      provider.sendMessage(text);
      _scrollToBottom();
    }
  }
}
