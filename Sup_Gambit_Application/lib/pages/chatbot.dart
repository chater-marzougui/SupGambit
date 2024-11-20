import 'package:flutter/material.dart';
import '../managers/sql_manager.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  static const String llmApiKey = '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';
  static const String embedderApiKey = "emb_a1574df7acdf844a572f73b917e0ed64987331d6beb6da23";
  static const String apiUrl = 'https://api-inference.huggingface.co/models/meta-llama/Llama-3.2-3B';

  final _chatService = ChatService(
    llmApiKey: llmApiKey,
    embedmentApiKey: embedderApiKey,
  );

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> commonQuestions = [
    "What is castling?",
    "How does the queen move?",
    "What is checkmate?",
    "How do pawns move?",
    "What is en passant?",
    "What is a fork?",
    "What is a pin?",
    "What is a skewer?",
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String text) async {
    // _handleQuery(text);

    if (text.trim().isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
      ));
      _isLoading = true;
    });
    _scrollToBottom();


    try {
      String botResponse = await  _chatService.getResponse(text);

      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          isUser: false,
        ));
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _messages.add(const ChatMessage(
          text: "Oops! Something went wrong. Please try again!",
          isUser: false,
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ChessBot 🤖',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _messages[index],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 8.0),
                  Text('Thinking... ♟️'),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: commonQuestions
                    .map((question) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton(
                    onPressed: () => _handleSubmitted(question),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(question),
                  ),
                ))
                    .toList(),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about chess...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12.0),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _handleSubmitted(_textController.text),
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue : Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              border: isUser
                  ? null
                  : Border.all(color: Colors.grey[300]!, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12.0),
            child: Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 16.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}