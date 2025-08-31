import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chatbot_app/models/message.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool animate;

  const MessageBubble({
    super.key,
    required this.message,
    this.animate = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  String _displayedText = "";
  Timer? _timer;
  int _currentIndex = 0;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeIn),
    );

    if (widget.animate && !widget.message.isUser) {
      // Start typing effect for AI messages when animate is true
      _startTypingEffect();
    } else {
      // Display full text immediately for user messages or non-animated AI messages
      _displayedText = widget.message.text;
      _animationController?.forward();
    }
  }

  void _startTypingEffect() {
    _timer?.cancel();
    _displayedText = "";
    _currentIndex = 0;

    // Use characters for a smooth typing effect
    final characters = widget.message.text.characters.toList();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentIndex < characters.length) {
        setState(() {
          _displayedText += characters[_currentIndex];
          _currentIndex++;
        });
      } else {
        timer.cancel();
        _timer = null;
        _animationController?.forward(); // Fade in the complete message
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fadeAnimation == null || _animationController == null) {
      return _buildBubble();
    }

    return FadeTransition(
      opacity: _fadeAnimation!,
      child: _buildBubble(),
    );
  }

  Widget _buildBubble() {
    return Align(
      alignment: widget.message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: widget.message.isUser
              ? const LinearGradient(
                  colors: [Color.fromARGB(255, 66, 66, 68), Color.fromARGB(255, 118, 137, 137)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFF5F5F5), Color.fromARGB(255, 92, 91, 91)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(widget.message.isUser ? 12 : 0),
            topRight: Radius.circular(widget.message.isUser ? 0 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.message.isUser)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
                ),
              ),
            if (widget.message.isUser)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 16, color: Colors.white),
                ),
              ),
            Flexible(
              child: Text(
                _displayedText.isNotEmpty ? _displayedText : widget.message.text, // Fallback to full text
                style: TextStyle(
                  color: widget.message.isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}