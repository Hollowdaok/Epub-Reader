import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:draggable_scrollbar/draggable_scrollbar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _nightMode = false;

  void _toggleTheme() {
    setState(() {
      _nightMode = !_nightMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epub Reader',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          color: Colors.grey[300],
          iconTheme: IconThemeData(color: Colors.black),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo,
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          color: Colors.grey[900],
          iconTheme: IconThemeData(color: Colors.white),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.indigo,
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      themeMode: _nightMode ? ThemeMode.dark : ThemeMode.light,
      home: EPUBViewer(toggleTheme: _toggleTheme, nightMode: _nightMode),
    );
  }
}

class EPUBViewer extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool nightMode;

  EPUBViewer({required this.toggleTheme, required this.nightMode});

  @override
  _EPUBViewerState createState() => _EPUBViewerState();
  final _searchController = TextEditingController();
}

class _EPUBViewerState extends State<EPUBViewer> {
  String _title = "Epub Reader";
  int _currentIndex = 0;
  List<Widget> _order = [];
  final _scrollController = ScrollController();
  bool _isLoading = false;
  List<String> _annotations = [];
  String _searchQuery = "";
  final _searchController = TextEditingController();

  Future<void> _loadEPUB() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.single.path!);
        final contents = await file.readAsBytes();
        final epubBook = await EpubReader.readBook(contents);

        EpubContent? bookContent = epubBook.Content;
        Map<String, EpubTextContentFile>? htmlFiles = bookContent?.Html;

        _order.clear();

        String htmlPage = "";
        htmlFiles?.keys.forEach((String htmlFile) {
          htmlPage = htmlFiles[htmlFile]!.Content!;
          _order.add(Html(data: _highlightSearchTerm(htmlPage, _searchQuery)));
        });

        setState(() {
          _title = epubBook.Title!;
          _isLoading = true;
        });
      }
    } catch (e) {
      print('Failed to load EPUB: $e');
    }
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 1) {
        _showAnnotationDialog();
      }
    });
  }

  void _searchEPUB(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isNotEmpty) {
        _isLoading = false;
        _order = _order.map((widget) {
          if (widget is Html) {
            return Html(data: _highlightSearchTerm(widget.data as String, _searchQuery));
          }
          return widget;
        }).toList();
      } else {
        _isLoading = false;
        _order = _order.map((widget) {
          if (widget is Html) {
            return Html(data: widget.data as String);
          }
          return widget;
        }).toList();
      }
      _isLoading = true;
    });
  }



  String _highlightSearchTerm(String text, String searchTerm) {
    if (searchTerm.isEmpty) {
      return text;
    }
    final pattern = RegExp(RegExp.escape(searchTerm), caseSensitive: false);
    return text.replaceAllMapped(pattern, (match) => '<mark>${match[0]}</mark>');
  }

  Widget buildLoadingScreen() {
    return Center(
      child: Text('Select an ePub File', style: TextStyle(color: Colors.black)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.nightMode ? Colors.black : Colors.grey[300],
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: widget.nightMode ? Colors.white : Colors.black),
          ),
          style: TextStyle(color: widget.nightMode ? Colors.white : Colors.black),
          onChanged: _searchEPUB,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchEPUB('');
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              _searchEPUB(_searchController.text);
            },
          ),
          IconButton(
            icon: Icon(widget.nightMode ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: _isLoading
          ? DraggableScrollbar.rrect(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _order.length,
          itemBuilder: (context, index) {
            return Card(
              child: SelectionArea(
                child: _order[index],
                contextMenuBuilder: (context, selectableRegionState) {
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: selectableRegionState.contextMenuAnchors,
                    buttonItems: <ContextMenuButtonItem>[
                      ...selectableRegionState.contextMenuButtonItems,
                    ],
                  );
                },
              ),
            );
          },
        ),
      )
          : buildLoadingScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Notes',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEPUB,
        child: Icon(Icons.folder_open),
      ),
    );
  }

  void _showAnnotationDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: EdgeInsets.all(16.0),
            constraints: BoxConstraints(maxWidth: 400.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Annotation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.0),
                TextField(
                  controller: textController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Enter annotation',
                  ),
                ),
                SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _annotations.add(textController.text);
                        Navigator.of(context).pop();
                        _showAnnotations();
                      },
                      child: Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAnnotations() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3), // Dimmed black background
      builder: (context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: EdgeInsets.all(16.0),
            constraints: BoxConstraints(maxWidth: 400.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Annotations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.0),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _annotations.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_annotations[index]),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Copy all annotations to clipboard
                        Clipboard.setData(
                          ClipboardData(text: _annotations.join('\n')),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Annotations copied to clipboard'),
                          ),
                        );
                      },
                      child: Text('Copy'),
                    ),
                    SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
