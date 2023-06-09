// Tuodaan tarvittavat kirjastot
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Käynnistetään sovellus
void main() {
  runApp(MyApp());
}
// Luodaan tilaton widget MyApp
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Palautetaan MaterialApp-widget
    return MaterialApp(
      title: 'AUDIO PLAYER',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: MyHomePage(title: 'AUDIO PLAYER'),
    );
  }
}
// Luodaan tilallinen widget MyHomePage
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}
// Luodaan tila _MyHomePageState-widgetille
class _MyHomePageState extends State<MyHomePage> {
  AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;
  List<String> audioFiles = [];
  int currentTrackIndex = 0;
  double currentPosition = 0.0;
  double totalDuration = 0.0;
  List<int> prevPositions = [0, 0];
  int lostPositions = 0;
  // Alustetaan tila
  @override
  void initState() {
    super.initState();
    _loadData();
    audioPlayer.onAudioPositionChanged.listen((Duration duration) {
      int positionChanged = duration.inMilliseconds;
      if (prevPositions[1] > positionChanged) {
        int diff = prevPositions[1] - prevPositions[0];
        int tempNext = prevPositions[1] + diff;
        lostPositions += tempNext - positionChanged;
      }
      int correctPosition = positionChanged + lostPositions;
      setState(() {
        currentPosition = correctPosition.toDouble();
      });
      prevPositions.add(positionChanged);
      prevPositions.removeAt(0);
    });
    audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        totalDuration = duration.inMilliseconds.toDouble();
      });
    });
    audioPlayer.onPlayerCompletion.listen((event) {
      _nextTrack();
    });
  }
  // Vapautetaan resurssit/tallennetaan kun widget poistetaan
  @override
  void dispose() {
    _saveData();
    super.dispose();
  }
  // Tallennetaan tiedot SharedPreferences-olioon
  void _saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('audioFiles', audioFiles);
    await prefs.setInt('currentTrackIndex', currentTrackIndex);
    await prefs.setDouble('currentPosition', currentPosition);
    await prefs.setDouble('totalDuration', totalDuration);
  }
  // Ladataan tiedot SharedPreferences-oliosta
  void _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      audioFiles = prefs.getStringList('audioFiles') ?? [];
      currentTrackIndex = prefs.getInt('currentTrackIndex') ?? 0;
      currentPosition = prefs.getDouble('currentPosition') ?? 0.0;
      totalDuration = prefs.getDouble('totalDuration') ?? 0.0;
    });
    audioPlayer.seek(Duration(milliseconds: currentPosition.toInt()));
  }
  // Toistetaan äänitiedostoa
  void _play() async {
    int result = await audioPlayer.play(audioFiles[currentTrackIndex]);
    if (result == 1) {
      setState(() {
        isPlaying = true;
        prevPositions = [0, 0];
        lostPositions = 0;
      });
    }
  }
  // Keskeytetään äänitiedoston toisto
  void _pause() async {
    int result = await audioPlayer.pause();
    if (result == 1) {
      setState(() {
        isPlaying = false;
      });
    }
  }
  void _nextTrack() {
    if (currentTrackIndex < audioFiles.length - 1) {
      setState(() {
        currentTrackIndex++;
      });
      _seek(0.0);
      _play();
    } else {
      audioPlayer.stop();
      isPlaying = false;
    }
  }
  // Siirrytään edelliseen äänitiedostoon
  void _previousTrack() {
    if (currentTrackIndex > 0) {
      setState(() {
        currentTrackIndex--;
      });
      _seek(0.0);
      _play();
    }
  }
  // Siirretään äänitiedoston toistokohtaa
  void _seek(double position) async {
    int result = await audioPlayer.seek(Duration(milliseconds: position.toInt()));
    if (result == 1) {
      setState(() {
        prevPositions = [0, 0];
        lostPositions = 0;
        currentPosition = position;
      });
      _saveData();
    }
  }
  // Lisätään uusi äänitiedosto
  void _addAudioFile(File file) async {
    setState(() {
      audioFiles.add(file.path);
    });
    _saveData();
  }
  // Poistetaan äänitiedosto
  void _removeAudioFile(int index) async {
    if (index == currentTrackIndex) {
      await audioPlayer.stop();
      isPlaying = false;
      setState(() {
        currentPosition = 0.0;
        totalDuration = 0.0;
      });
    }
    setState(() {
      audioFiles.removeAt(index);
    });
    if (currentTrackIndex >= audioFiles.length) {
      currentTrackIndex = audioFiles.length - 1;
    }
    _saveData();
  }
  // Näytetään dialogi äänitiedoston lisäämiseksi
  Future<void> _showAddAudioDialog(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileExtension = file.path.split('.').last;
      List<String> compatibleExtensions = ['mp3', 'wav', 'ogg'];
      if (compatibleExtensions.contains(fileExtension)) {
        _addAudioFile(file);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Filetype incompatible.'),
          ),
        );
      }
    }
  }
  // Näytetään dialogi äänitiedoston poistamiseksi
  Future<void> _showRemoveAudioDialog(BuildContext context, int index) async{
    return showDialog<void>(
      context: context,
      builder: (BuildContext context){
        return AlertDialog(
          title: Text('Remove Audio File'),
          content: Text('Remove this audio file?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Remove'),
              onPressed: (){
                _removeAudioFile(index);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  // Palauttaa tiedoston nimen URL-osoitteesta
  String getFileName(String url){
    return url.split('/').last;
  }
  // Muotoilee keston merkkijonoksi
  String formatDuration(Duration duration){
    String twoDigits(int n){
      if(n>=10)return "$n";
      return "0$n";
    }
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  // Rakennetaan widgetin ulkoasu
  @override
  Widget build(BuildContext context) {
    // Varmista, että currentPosition on kelvollisen alueen sisällä
    if (currentPosition < 0) {
      currentPosition = 0;
    } else if (currentPosition > totalDuration) {
      currentPosition = totalDuration;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            iconSize: 48,
            icon: Icon(Icons.add),
            onPressed: () => _showAddAudioDialog(context),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                itemCount: audioFiles.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(getFileName(audioFiles[index])),
                    onTap: () {
                      setState(() {
                        currentTrackIndex = index;
                      });
                      _play();
                      _saveData();
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _showRemoveAudioDialog(context, index),
                    ),
                    tileColor:
                    index == currentTrackIndex ? Colors.blue[50] : null,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(Duration(milliseconds: currentPosition.toInt())), style: TextStyle(fontSize: 20)),
                  Text(formatDuration(Duration(milliseconds: (totalDuration - currentPosition).toInt())), style: TextStyle(fontSize: 20)),
                ],
              ),
            ),
            Slider(
              value: currentPosition,
              min: 0.0,
              max: totalDuration,
              onChanged: (double value) => _seek(value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                IconButton(
                  iconSize :48,
                  icon : Icon(Icons.skip_previous),
                  onPressed :
                  currentTrackIndex >0 ?_previousTrack:null,
                ),
                SizedBox(width :20),
                IconButton(
                  iconSize :48,
                  icon :
                  isPlaying ? Icon(Icons.pause):Icon(Icons.play_arrow),
                  onPressed :
                  isPlaying ?_pause:_play,
                ),
                SizedBox(width :20),
                IconButton(
                  iconSize :48,
                  icon : Icon(Icons.skip_next),
                  onPressed :
                  currentTrackIndex <audioFiles.length -1 ?_nextTrack:null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
