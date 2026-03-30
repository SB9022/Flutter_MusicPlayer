import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const HomePage({super.key, required this.themeModeNotifier});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final List<String> _folders = [];
  final List<String> _musicFiles = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isPopupVisible = false;
  String? _currentlyPlaying;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _volume = 1.0;
  double _previousVolume = 1.0; // Variable to store the previous volume
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late AnimationController _themeAnimationController;
  late Animation<double> _themeAnimation;
  bool _isVolumeHovered = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    Platform.isAndroid
        ? _requestStoragePermission()
        : null;
    _focusNode.requestFocus();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        // Re-enable key mapping when search box loses focus
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      _playNextMusic();
    });

    _themeAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _themeAnimation = CurvedAnimation(
      parent: _themeAnimationController,
      curve: Curves.easeInOut,
    );

    // Set initial animation value based on theme
    if (widget.themeModeNotifier.value == ThemeMode.dark) {
      _themeAnimationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _themeAnimationController.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      if (widget.themeModeNotifier.value == ThemeMode.dark) {
        widget.themeModeNotifier.value = ThemeMode.light;
        _themeAnimationController.reverse();
      } else {
        widget.themeModeNotifier.value = ThemeMode.dark;
        _themeAnimationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredMusicFiles = _musicFiles
        .where((file) => path
            .basename(file)
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: GestureDetector(
        onTap: () {
          // Unfocus the search box when tapping anywhere else
          FocusScope.of(context).requestFocus(_focusNode);
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Container(
              margin: EdgeInsets.all(5.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: AppBar(
                  flexibleSpace: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.themeModeNotifier.value == ThemeMode.dark
                            ? [Colors.blue.shade900, Colors.black87]
                            : [Colors.blue.shade400, Colors.blue.shade700],
                      ),
                    ),
                  ),
                  leading: Platform.isAndroid
                      ? null
                      : Builder(
                          builder: (context) => IconButton(
                            icon: Container(
                              padding: EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.menu,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                  title: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(_isSearching ? -0.3 : 0.3, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isSearching && Platform.isAndroid
                        ? Container(
                            key: ValueKey('search_field'),
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              focusNode: _searchFocusNode,
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search Music',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                hintStyle: TextStyle(color: Colors.white70),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear, color: Colors.white70),
                                        onPressed: () => _searchController.clear(),
                                      )
                                    : null,
                              ),
                              style: TextStyle(color: Colors.white),
                              autofocus: true,
                            ),
                          )
                        : Row(
                            key: ValueKey('title_row'),
                            children: [
                              Icon(Icons.music_note, color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                'Music Player',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                  ),
                  actions: [
                    if (Platform.isAndroid)
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _searchController,
                          ValueNotifier<bool>(_isSearching)
                        ]),
                        builder: (context, _) {
                          return IconButton(
                            icon: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: _isSearching ? 1.0 : 0.0,
                              ),
                              duration: Duration(milliseconds: 300),
                              builder: (context, value, child) {
                                return Transform.rotate(
                                  angle: value * 0.5 * 3.14,
                                  child: Icon(
                                    _isSearching ? Icons.close : Icons.search,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            onPressed: () {
                              setState(() {
                                _isSearching = !_isSearching;
                                if (!_isSearching) {
                                  _searchController.clear();
                                } else {
                                  Future.delayed(Duration(milliseconds: 100), () {
                                    FocusScope.of(context).requestFocus(_searchFocusNode);
                                  });
                                }
                              });
                            },
                          );
                        },
                      ),
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Switch(
                        value: widget.themeModeNotifier.value == ThemeMode.dark,
                        onChanged: (value) {
                          _toggleTheme();
                        },
                        activeColor: Colors.blue.shade700,
                        activeTrackColor: Colors.blue.shade900,
                        inactiveThumbColor: Colors.amber.shade200,
                        inactiveTrackColor: Colors.orange.shade700,
                        thumbIcon: MaterialStateProperty.resolveWith<Icon?>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return Icon(Icons.dark_mode, color: Colors.white, size: 16);
                          }
                          return Icon(Icons.light_mode, color: Colors.white, size: 16);
                        }),
                      ),
                    ),
                  ],
                  elevation: 0,
                ),
              ),
            ),
          ),
          drawer: Platform.isAndroid
              ? null
              : Drawer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: widget.themeModeNotifier.value == ThemeMode.dark
                            ? [Colors.blue.shade900, Colors.black87]
                            : [Colors.blue.shade300, Colors.white],
                      ),
                    ),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.blue.shade700, Colors.blue.shade900],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 50,
                                left: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.music_note,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Music Library',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${_musicFiles.length} songs',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                right: 20,
                                child: ElevatedButton.icon(
                                  onPressed: _pickFolder,
                                  icon: Icon(Icons.create_new_folder),
                                  label: Text('Add Folder'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.blue.shade900,
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10),
                        ..._folders.map((folder) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 4.0),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                color: (widget.themeModeNotifier.value == ThemeMode.dark
                                        ? Colors.grey[850]
                                        : Colors.white)
                                    ?.withOpacity(0.9),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8.0),
                                  leading: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.folder,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: Text(
                                    path.basename(folder),
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    folder,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red[300]),
                                    onPressed: () {
                                      setState(() {
                                        _folders.remove(folder);
                                        _removeMusicFilesFromFolder(folder);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            )),
                        if (_folders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Center(
                              child: Text(
                                'No folders added yet',
                                style: TextStyle(
                                  color: widget.themeModeNotifier.value == ThemeMode.dark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          body: Stack(
            children: [
              // Animated Background
              AnimatedBuilder(
                animation: _themeAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AnimatedBackgroundPainter(
                      color1: Color.lerp(
                        Colors.blue.shade300,
                        Colors.blue.shade900,
                        _themeAnimation.value,
                      )!,
                      color2: Color.lerp(
                        Colors.white,
                        Colors.black,
                        _themeAnimation.value,
                      )!,
                      transitionValue: _themeAnimation.value,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
              // Rest of the content
              Column(
                children: [
                  SizedBox(height: kToolbarHeight + 2), // Reduced from 5 to 2
                  if (!Platform.isAndroid)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0, // Reduced from 4.0 to 2.0
                      ),
                      child: TextField(
                        focusNode: _searchFocusNode,
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search Music',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor.withOpacity(0.9),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          // ...existing TextField decoration...
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: Platform.isAndroid
                      ? const EdgeInsets.only(top: 25.0) // Add small top padding
                      : const EdgeInsets.only(top: 2.0),
                      child: filteredMusicFiles.isEmpty
                          ? Center(
                              child: TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: Duration(milliseconds: 800),
                                builder: (context, double value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.scale(
                                      scale: 0.8 + (0.2 * value),
                                      child: Container(
                                        padding: EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.blue.withOpacity(0.2),
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.music_off,
                                              size: 70,
                                              color:
                                                  Colors.white.withOpacity(0.7),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Music not found',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Add music folders to get started',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.only(
                                  top: 5), // Remove default ListView padding
                              itemCount: filteredMusicFiles.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4.0, // Reduced from 8.0 to 4.0
                                    vertical: 4.0, // Reduced from 2.0 to 1.0
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: _currentlyPlaying ==
                                              filteredMusicFiles[index]
                                          ? [
                                              BoxShadow(
                                                color: Colors.blue
                                                    .withOpacity(0.3),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                              BoxShadow(
                                                color: Colors.blue
                                                    .withOpacity(0.2),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        side: BorderSide(
                                          color: _currentlyPlaying ==
                                                  filteredMusicFiles[index]
                                              ? Colors.blue.withOpacity(0.8)
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      tileColor: (_currentlyPlaying ==
                                                  filteredMusicFiles[index]
                                              ? Colors.blue.withOpacity(0.1)
                                              : widget.themeModeNotifier
                                                          .value ==
                                                      ThemeMode.dark
                                                  ? Colors.grey[800]
                                                  : Colors.white)
                                          ?.withOpacity(0.8),
                                      title: Text(
                                        path.basename(
                                            filteredMusicFiles[index]),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _currentlyPlaying ==
                                                  filteredMusicFiles[index]
                                              ? Colors.blue.withOpacity(0.2)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: _currentlyPlaying ==
                                                    filteredMusicFiles[index] &&
                                                _isPlaying
                                            ? AnimatedEqualizerBar()
                                            : Icon(Icons.music_note),
                                      ),
                                      trailing: _currentlyPlaying ==
                                                  filteredMusicFiles[index] &&
                                              _isPlaying
                                          ? Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: Colors.blue
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: AnimatedEqualizerBar(
                                                barCount: 3,
                                                reverse: true,
                                              ),
                                            )
                                          : Icon(Icons.play_arrow),
                                      onTap: () {
                                        _playMusic(filteredMusicFiles[index]);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(10.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15.0),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        height: _isPopupVisible ? 180.0 : 0.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade800,
                              Colors.blue.shade900,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10.0,
                              spreadRadius: 2.0,
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue.shade900,
                                      Colors.blue.shade800.withOpacity(0.5),
                                    ],
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: _isPlaying
                                          ? AnimatedEqualizerBar(
                                              barCount: 3,
                                              reverse: true,
                                            )
                                          : Icon(
                                              Icons.music_note,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _currentlyPlaying != null
                                            ? path.basename(_currentlyPlaying!)
                                            : '',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Wave Animation
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: SizedBox(
                                            height: 30,
                                            child: CustomPaint(
                                              painter: WaveFormPainter(
                                                progress: _currentPosition
                                                        .inSeconds /
                                                    (_totalDuration.inSeconds ==
                                                            0
                                                        ? 1
                                                        : _totalDuration
                                                            .inSeconds),
                                                color: Colors.white,
                                                waveColor: Colors.white
                                                    .withOpacity(0.3),
                                              ),
                                              size: Size.infinite,
                                            ),
                                          ),
                                        ),
                                        // Slider
                                        SliderTheme(
                                          data: SliderThemeData(
                                            thumbColor: Colors.white,
                                            activeTrackColor:
                                                Colors.transparent,
                                            inactiveTrackColor:
                                                Colors.transparent,
                                            trackHeight: 30.0,
                                            thumbShape: RoundSliderThumbShape(
                                              enabledThumbRadius: 8.0,
                                            ),
                                            overlayShape:
                                                RoundSliderOverlayShape(
                                              overlayRadius: 16.0,
                                            ),
                                            trackShape:
                                                RectangularSliderTrackShape(),
                                            // This ensures precise positioning
                                            overlayColor:
                                                Colors.blue.withOpacity(0.2),
                                          ),
                                          child: Slider(
                                            value: _currentPosition
                                                .inMilliseconds
                                                .toDouble(),
                                            min: 0,
                                            max: _totalDuration.inMilliseconds
                                                .toDouble(),
                                            onChanged: (value) {
                                              final position = Duration(
                                                  milliseconds: value.toInt());
                                              setState(() {
                                                _currentPosition = position;
                                                _audioPlayer.seek(position);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(_currentPosition),
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(_totalDuration),
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.skip_previous,
                                        color: Colors.white),
                                    onPressed: _playPreviousMusic,
                                    splashColor: Colors.white24,
                                  ),
                                  Container(
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      iconSize: 32,
                                      icon: AnimatedIcon(
                                        icon: AnimatedIcons.play_pause,
                                        progress: AlwaysStoppedAnimation(
                                            _isPlaying ? 1.0 : 0.0),
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        if (_isPlaying) {
                                          _audioPlayer.pause();
                                          setState(() => _isPlaying = false);
                                        } else if (_currentlyPlaying != null) {
                                          _audioPlayer.resume();
                                          setState(() => _isPlaying = true);
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.skip_next,
                                        color: Colors.white),
                                    onPressed: _playNextMusic,
                                    splashColor: Colors.white24,
                                  ),
                                  Spacer(),
                                  MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => _isVolumeHovered = true),
                                    onExit: (_) => setState(
                                        () => _isVolumeHovered = false),
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      width: _isVolumeHovered ? 160 : 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _isVolumeHovered
                                            ? Colors.white.withOpacity(0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (_isVolumeHovered)
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 12),
                                                child: SliderTheme(
                                                  data: SliderThemeData(
                                                    thumbColor: Colors.white,
                                                    activeTrackColor:
                                                        Colors.white,
                                                    inactiveTrackColor: Colors
                                                        .white
                                                        .withOpacity(0.3),
                                                    trackHeight: 2.0,
                                                    thumbShape:
                                                        RoundSliderThumbShape(
                                                      enabledThumbRadius: 6.0,
                                                      pressedElevation: 8.0,
                                                    ),
                                                    overlayColor: Colors.white
                                                        .withOpacity(0.1),
                                                    overlayShape:
                                                        RoundSliderOverlayShape(
                                                      overlayRadius: 12.0,
                                                    ),
                                                    valueIndicatorShape:
                                                        PaddleSliderValueIndicatorShape(),
                                                    valueIndicatorColor:
                                                        Colors.blue.shade700,
                                                    valueIndicatorTextStyle:
                                                        TextStyle(
                                                            color:
                                                                Colors.white),
                                                  ),
                                                  child: Slider(
                                                    value: _volume,
                                                    min: 0.0,
                                                    max: 1.0,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _volume = value;
                                                        _audioPlayer
                                                            .setVolume(_volume);
                                                      });
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: IconButton(
                                              icon: Icon(
                                                _volume == 0
                                                    ? Icons.volume_off
                                                    : _volume < 0.5
                                                        ? Icons.volume_down
                                                        : Icons.volume_up,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  if (_volume == 0) {
                                                    _volume = _previousVolume;
                                                  } else {
                                                    _previousVolume = _volume;
                                                    _volume = 0;
                                                  }
                                                  _audioPlayer
                                                      .setVolume(_volume);
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _requestStoragePermission() {
    Permission.audio.request().then((status) {
      if (status.isGranted) {
        _fetchMusicFiles();
      } else if (status.isDenied) {
        Permission.storage.request().then((status) {
          if (status.isGranted) {
            _fetchMusicFiles();
          } else {
            _showPermissionDeniedDialog();
          }
        });
      } else if (status.isPermanentlyDenied) {
        _showPermissionPermanentlyDeniedDialog();
      }
    });
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Storage Permission Required'),
        content: Text('This app needs storage access to fetch music files.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestStoragePermission();
            },
            child: Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Storage Permission Required'),
        content: Text(
            'Storage access is permanently denied. Please enable it in the app settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _fetchMusicFiles() {
    final directories = [
      Directory('/storage/emulated/0/Music'),
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/'),
    ];

    for (var directory in directories) {
      if (directory.existsSync()) {
        _listMusicFiles(directory.path);
      }
    }
  }

  void _pickFolder() {
    FilePicker.platform.getDirectoryPath().then((selectedDirectory) {
      if (selectedDirectory != null && !_folders.contains(selectedDirectory)) {
        setState(() {
          _folders.add(selectedDirectory);
          _listMusicFiles(selectedDirectory);
        });
      }
    });
  }

  void _listMusicFiles(String folderPath) {
    final directory = Directory(folderPath);
    final files = directory
        .listSync(recursive: true)
        .where((file) => file.path.endsWith('.mp3'))
        .map((file) => file.path)
        .toList();
    setState(() {
      for (var file in files) {
        if (!_musicFiles.any((existingFile) =>
            path.basename(existingFile) == path.basename(file))) {
          _musicFiles.add(file);
        }
      }
    });
  }

  void _removeMusicFilesFromFolder(String folderPath) {
    final directory = Directory(folderPath);
    final files = directory
        .listSync()
        .where((file) => file.path.endsWith('.mp3'))
        .map((file) => file.path)
        .toList();
    setState(() {
      _musicFiles.removeWhere((file) => files.contains(file));
      if (_currentlyPlaying != null && files.contains(_currentlyPlaying)) {
        _audioPlayer.stop(); // Stop the audio player
        _currentlyPlaying = null;
        _isPlaying = false;
        _isPopupVisible = false;
      }
    });
  }

  void _playMusic(String filePath) {
    if (_currentlyPlaying == filePath && _isPlaying) {
      _audioPlayer.pause().then((_) {
        setState(() {
          _isPlaying = false;
        });
      });
    } else {
      setState(() {
        _currentlyPlaying = filePath;
        _isPlaying = true;
      });
      _audioPlayer.play(DeviceFileSource(filePath)).then((_) {
        setState(() {
          _isPopupVisible = true;
        });
      });
    }
  }

  void _playNextMusic() {
    if (_currentlyPlaying != null) {
      int currentIndex = _musicFiles.indexOf(_currentlyPlaying!);
      int nextIndex = (currentIndex + 1) % _musicFiles.length;
      _playMusic(_musicFiles[nextIndex]);
    }
  }

  void _playPreviousMusic() {
    if (_currentlyPlaying != null) {
      int currentIndex = _musicFiles.indexOf(_currentlyPlaying!);
      int previousIndex =
          (currentIndex - 1 + _musicFiles.length) % _musicFiles.length;
      _playMusic(_musicFiles[previousIndex]);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (_searchFocusNode.hasFocus) {
      // If the search box is focused, do not handle key events
      return;
    }

    if (event is RawKeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.space:
          // Handle play/pause
          if (_isPlaying) {
            _audioPlayer.pause();
            setState(() {
              _isPlaying = false;
            });
          } else {
            if (_currentlyPlaying != null) {
              _audioPlayer.resume();
              setState(() {
                _isPlaying = true;
              });
            }
          }
          break;
        case LogicalKeyboardKey.arrowRight:
          if (event.isControlPressed) {
            // Handle next song
            _playNextMusic();
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (event.isControlPressed) {
            // Handle previous song
            _playPreviousMusic();
          }
          break;
        case LogicalKeyboardKey.arrowUp:
          if (event.isControlPressed) {
            // Increase volume
            setState(() {
              _volume = (_volume + 0.1).clamp(0.0, 1.0);
              _audioPlayer.setVolume(_volume);
            });
          }
          break;
        case LogicalKeyboardKey.arrowDown:
          if (event.isControlPressed) {
            // Decrease volume
            setState(() {
              _volume = (_volume - 0.1).clamp(0.0, 1.0);
              _audioPlayer.setVolume(_volume);
            });
          }
          break;
      }
    }
  }
}

// Add this custom painter class at the end of the file
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < size.width; i += 30) {
      for (var j = 0; j < size.height; j += 30) {
        canvas.drawCircle(Offset(i.toDouble(), j.toDouble()), 5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class AnimatedEqualizerBar extends StatefulWidget {
  final int barCount;
  final bool reverse;

  const AnimatedEqualizerBar({
    super.key,
    this.barCount = 4,
    this.reverse = false,
  });

  @override
  _AnimatedEqualizerBarState createState() => _AnimatedEqualizerBarState();
}

class _AnimatedEqualizerBarState extends State<AnimatedEqualizerBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.barCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 600 + (index * 100)),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    for (var controller in _controllers) {
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        widget.barCount,
        (index) => AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              width: 3,
              height: 20 * _animations[index].value,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(5),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Add this class at the end of the file
class AnimatedBackgroundPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final Paint paintObject;
  final double animationValue;
  final double transitionValue;

  AnimatedBackgroundPainter({
    required this.color1,
    required this.color2,
    required this.transitionValue,
  })  : paintObject = Paint(),
        animationValue = DateTime.now().millisecondsSinceEpoch / 2000;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Draw gradient background
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color1, color2],
      stops: [0.0, 1.0],
      transform: GradientRotation(animationValue),
    );

    paintObject.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paintObject);

    // Determine wave colors based on background
    final isDark = color2.computeLuminance() < 0.5;
    final waveColors = isDark
        ? [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.03),
            Colors.white.withOpacity(0.02),
          ]
        : [
            Colors.blue.shade300.withOpacity(0.15),
            Colors.blue.shade400.withOpacity(0.1),
            Colors.blue.shade500.withOpacity(0.05),
          ];

    // Draw multiple layered waves with different opacities and sizes
    final wavePaints = waveColors
        .map((color) => Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2))
        .toList();

    // Draw waves with different parameters
    for (int wave = 0; wave < wavePaints.length; wave++) {
      final path = Path();
      path.moveTo(0, size.height);

      final amplitude = (45 - wave * 10).toDouble();
      final period = (180 + wave * 20).toDouble();
      final phase = animationValue * (1.2 + wave * 0.3);

      for (double x = 0; x <= size.width; x += 1) {
        final y = size.height * (0.5 + wave * 0.1) +
            amplitude * sin((x / period) + phase) +
            amplitude * 0.5 * cos((x / (period * 0.8)) - phase * 1.5);

        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.close();

      canvas.drawPath(path, wavePaints[wave]);
    }

    // Add shimmer effect in light mode
    if (!isDark) {
      final shimmerPaint = Paint()
        ..color = Colors.blue.shade200.withOpacity(0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);

      for (int i = 0; i < 3; i++) {
        final shimmerPath = Path();
        final offset = sin(animationValue * 2 + i) * 60;

        shimmerPath.moveTo(0, size.height);
        shimmerPath.lineTo(size.width, size.height);
        shimmerPath.lineTo(size.width + offset, 0);
        shimmerPath.lineTo(offset - 100, 0);
        shimmerPath.close();

        canvas.drawPath(shimmerPath, shimmerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedBackgroundPainter oldDelegate) => true;
}

// ba
class WaveFormPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color waveColor;
  final Paint wavePaint;
  final Paint progressPaint;
  final double animationValue;

  WaveFormPainter({
    required this.progress,
    required this.color,
    required this.waveColor,
  })  : wavePaint = Paint()
          ..color = waveColor
          ..style = PaintingStyle.fill,
        progressPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill,
        animationValue = DateTime.now().millisecondsSinceEpoch / 1000;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final progressWidth = width * progress;
    final barWidth = 3.0;
    final spacing = 5.0;
    final totalBars = (width / (barWidth + spacing)).floor();

    // Draw background static bars
    for (int i = 0; i < totalBars; i++) {
      final x = i * (barWidth + spacing);
      final barHeight = height * 0.3; // Static height for non-active bars

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, (height - barHeight) / 2, barWidth, barHeight),
        Radius.circular(2),
      );

      canvas.drawRRect(rect, wavePaint);
    }

    // Draw animated progress bars
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, progressWidth, height));

    for (int i = 0; i < totalBars; i++) {
      final x = i * (barWidth + spacing);
      final normalized = x / width;
      final animatedHeight =
          height * (0.3 + 0.4 * sin(normalized * 10 + animationValue * 2));

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            x, (height - animatedHeight) / 2, barWidth, animatedHeight),
        Radius.circular(2),
      );

      canvas.drawRRect(rect, progressPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WaveFormPainter oldDelegate) => true;
}
