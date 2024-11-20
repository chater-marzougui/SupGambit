import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sup_gambit/pages/chatbot.dart';
import 'package:sup_gambit/pages/home_screen.dart';
import 'package:sup_gambit/pages/puzzles_page.dart';

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomePage({required this.cameras, super.key});

  static void switchToPage(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_HomePageState>();
    if (state != null) {
      state._onItemTapped(index);
    }
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  DateTime? lastPressed;

  late final List<Widget> _pages;
  late final List<Widget> _pageWidgets;
  final List<bool> _pagesUnderNav = [false, false, false];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      for (int i = 0; i < _pageWidgets.length; i++) {
        _pageWidgets[i] = Offstage(
          offstage: _selectedIndex != i,
          child: TickerMode(
            enabled: _selectedIndex == i,
            child: _pages[i],
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _pages = [
      ChessMainScreen(cameras: widget.cameras),
      const ChessPuzzlePage(),
      const ChatScreen(),
    ];

    _pageWidgets = _pages.asMap().entries.map((entry) {
      return Offstage(
        offstage: _selectedIndex != entry.key,
        child: TickerMode(
          enabled: _selectedIndex == entry.key,
          child: entry.value,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        final now = DateTime.now();
        if (lastPressed == null ||
            now.difference(lastPressed!) > const Duration(seconds: 2)) {
          lastPressed = now;
          Fluttertoast.showToast(msg: 'Tap again to exit');
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
            children: _pageWidgets
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: theme.primaryColor,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_sharp),
              label: 'Puzzle',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mark_unread_chat_alt_outlined),
              label: 'ChatBot',
            ),
          ],
        ),
      ),
    );
  }
}