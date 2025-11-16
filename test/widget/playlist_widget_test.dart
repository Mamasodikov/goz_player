import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple widget for testing
class SimplePlaylistWidget extends StatelessWidget {
  final bool hasInternet;
  final VoidCallback? onRefresh;

  const SimplePlaylistWidget({
    Key? key,
    required this.hasInternet,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(hasInternet ? 'Online Mode' : 'Offline Mode'),
        if (onRefresh != null)
          ElevatedButton(
            onPressed: onRefresh,
            child: Text('Refresh'),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) {
              return ListTile(
                key: Key('playlist_item_$index'),
                title: Text('Song ${index + 1}'),
                subtitle: Text('Artist ${index + 1}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

void main() {
  group('Playlist Widget Tests', () {
    testWidgets('shows online mode when connected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimplePlaylistWidget(
              hasInternet: true,
              onRefresh: () {},
            ),
          ),
        ),
      );

      expect(find.text('Online Mode'), findsOneWidget);
      expect(find.text('Offline Mode'), findsNothing);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('shows offline mode when disconnected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimplePlaylistWidget(hasInternet: false),
          ),
        ),
      );

      expect(find.text('Offline Mode'), findsOneWidget);
      expect(find.text('Online Mode'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('shows 3 songs in the list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimplePlaylistWidget(hasInternet: true),
          ),
        ),
      );

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Song 1'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
      expect(find.text('Song 3'), findsOneWidget);
    });

    testWidgets('refresh button works when tapped', (tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SimplePlaylistWidget(
              hasInternet: true,
              onRefresh: () => wasPressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Refresh'));
      await tester.pump();

      expect(wasPressed, true);
    });
  });
}