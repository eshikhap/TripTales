import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'trip_info.dart';
class TripChatPage extends StatefulWidget {
  final String tripId;

  const TripChatPage({super.key, required this.tripId});

  @override
  _TripChatPageState createState() => _TripChatPageState();
}

class _TripChatPageState extends State<TripChatPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final uuid = Uuid();
  final ImagePicker _picker = ImagePicker();

  List<types.Message> _messages = [];
  late types.User _currentUser;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    final tripDoc = await _firestore.collection('trips').doc(widget.tripId).get();

    if (!tripDoc.exists) return;

    final members = List<String>.from(tripDoc.data()?['members'] ?? []);
    final currentUserId = _auth.currentUser?.uid;

    if (currentUserId != null && members.contains(currentUserId)) {
      _currentUser = types.User(
        id: currentUserId,
        firstName: _auth.currentUser?.displayName ?? 'You',
        imageUrl: _auth.currentUser?.photoURL,
      );
      setState(() {
        _hasAccess = true;
      });
      _loadMessages();
    } else {
      setState(() {
        _hasAccess = false;
      });
    }
  }

  void _loadMessages() {
    _firestore
        .collection('trips')
        .doc(widget.tripId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();

        if (data['type'] == 'text') {
          return types.TextMessage(
            id: doc.id,
            author: types.User(
              id: data['sender'],
              firstName: data['senderName'] ?? '',
              imageUrl: data['senderAvatarUrl'],
            ),
            text: data['text'],
            createdAt: (data['timestamp'] as Timestamp).millisecondsSinceEpoch,
          );
        } else if (data['type'] == 'image') {
          return types.ImageMessage(
            id: doc.id,
            author: types.User(
              id: data['sender'],
              firstName: data['senderName'] ?? '',
              imageUrl: data['senderAvatarUrl'],
            ),
            uri: data['url'],
            createdAt: (data['timestamp'] as Timestamp).millisecondsSinceEpoch,
            name: "📷 ${data['caption'] ?? ''}",
            size: 0,
          );
        } else if (data['type'] == 'video') {
          return types.VideoMessage(
            id: doc.id,
            author: types.User(
              id: data['sender'],
              firstName: data['senderName'] ?? '',
              imageUrl: data['senderAvatarUrl'],
            ),
            uri: data['url'],
            createdAt: (data['timestamp'] as Timestamp).millisecondsSinceEpoch,
            name: "📹 ${data['caption'] ?? ''}",
            size: 0,
            height: 200,
          );
        }

        return null;
      }).whereType<types.Message>().toList();

      setState(() {
        _messages = messages;
      });
    });
  }

  void _sendMessage(types.PartialText message) {
    final messageId = uuid.v4();
    final user = _auth.currentUser!;
    _firestore
        .collection('trips')
        .doc(widget.tripId)
        .collection('chat')
        .doc(messageId)
        .set({
      'sender': user.uid,
      'senderName': user.displayName,
      'senderAvatarUrl': user.photoURL,
      'text': message.text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickImage() async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      _showMediaPreview(File(pickedImage.path), "image");
    }
  }

  Future<void> _pickVideo() async {
    final XFile? pickedVideo = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedVideo != null) {
      _showMediaPreview(File(pickedVideo.path), "video");
    }
  }

  void _showMediaPreview(File file, String type) {
    TextEditingController captionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Send $type?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              type == "image"
                  ? Image.file(file, width: 200, height: 200, fit: BoxFit.cover)
                  : AspectRatio(
                      aspectRatio: 16 / 9,
                      child: VideoPlayerWidget(file: file),
                    ),
              SizedBox(height: 10),
              TextField(
                controller: captionController,
                decoration: InputDecoration(
                  hintText: "Add a caption...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                String caption = captionController.text.trim();
                Navigator.pop(context);
                await _sendMedia(file, type, caption);
              },
              child: Text("Send"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMedia(File file, String type, String caption) async {
    final String fileName = uuid.v4();
    final Reference ref = _storage.ref().child('chat_$type/$fileName.${type == "image" ? "jpg" : "mp4"}');
    await ref.putFile(file);
    final String fileUrl = await ref.getDownloadURL();

    final user = _auth.currentUser!;
    final messageId = uuid.v4();
    await _firestore
        .collection('trips')
        .doc(widget.tripId)
        .collection('chat')
        .doc(messageId)
        .set({
      'sender': user.uid,
      'senderName': user.displayName,
      'senderAvatarUrl': user.photoURL,
      'url': fileUrl,
      'caption': caption,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.image),
              title: Text("Select Image"),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.video_camera_back),
              title: Text("Select Video"),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text("Trip Chat")),
        body: Center(child: Text("You are not a member of this trip.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
  title: const Text("Trip Chat"),
  actions: [
    IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'Trip Info',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripInfoPage(tripId: widget.tripId),
          ),
        );
      },
    ),
  ],
),
      body: Chat(
        messages: _messages,
        onSendPressed: _sendMessage,
        onAttachmentPressed: _handleAttachmentPressed,
        user: _currentUser,
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final File file;
  const VideoPlayerWidget({super.key, required this.file});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : Center(child: CircularProgressIndicator());
  }
}
