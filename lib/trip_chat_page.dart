// All your imports stay unchanged
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
import 'Plan_trip/EditTripDetailsPage.dart';

final TextEditingController _messageController = TextEditingController();

class TripChatPage extends StatefulWidget {
  final String tripId;

  const TripChatPage({Key? key, required this.tripId}) : super(key: key);

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
        final timestamp = (data['timestamp'] as Timestamp?)?.millisecondsSinceEpoch;

        if (data['type'] == 'text') {
          return types.TextMessage(
            id: doc.id,
            author: types.User(
              id: data['sender'],
              firstName: data['senderName'] ?? '',
              imageUrl: data['senderAvatarUrl'],
            ),
            text: data['text'],
            createdAt: timestamp,
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
            createdAt: timestamp,
            name: "📷 ${data['caption'] ?? ''}",
            size: 0,
          );
        } else if (data['type'] == 'video') {
          return types.CustomMessage(
            id: doc.id,
            author: types.User(
              id: data['sender'],
              firstName: data['senderName'] ?? '',
              imageUrl: data['senderAvatarUrl'],
            ),
            createdAt: timestamp,
            metadata: {
              'type': 'video',
              'url': data['url'],
              'caption': data['caption'],
            },
          );
        }
        return null;
      }).whereType<types.Message>().toList();

      setState(() {
        _messages = messages;
      });
    });
  }

  void _sendMessage(types.PartialText message) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final messageData = {
      'text': message.text,
      'sender': currentUser.uid,
      'senderName': currentUser.displayName,
      'senderAvatarUrl': currentUser.photoURL,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    };

    await _firestore
        .collection('trips')
        .doc(widget.tripId)
        .collection('chat')
        .add(messageData);
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
          content: SingleChildScrollView(
            child: Column(
              children: [
                type == "image"
                    ? Image.file(file, width: 200, height: 200, fit: BoxFit.cover)
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: VideoPlayerPreview(file: file),
                      ),
                const SizedBox(height: 10),
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(
                    hintText: "Add a caption...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                final caption = captionController.text.trim();
                Navigator.pop(context);
                await _sendMedia(file, type, caption);
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMedia(File file, String type, String caption) async {
    try {
      final fileName = uuid.v4();
      final ref = _storage.ref().child('chat_$type/$fileName.${type == "image" ? "jpg" : "mp4"}');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      final user = _auth.currentUser!;
      await _firestore
          .collection('trips')
          .doc(widget.tripId)
          .collection('chat')
          .doc(uuid.v4())
          .set({
        'sender': user.uid,
        'senderName': user.displayName,
        'senderAvatarUrl': user.photoURL,
        'url': url,
        'caption': caption,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("⚠️ Media send error: $e");
    }
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(leading: Icon(Icons.image), title: Text("Select Image"), onTap: () {
            Navigator.pop(context);
            _pickImage();
          }),
          ListTile(leading: Icon(Icons.videocam), title: Text("Select Video"), onTap: () {
            Navigator.pop(context);
            _pickVideo();
          }),
        ],
      ),
    );
  }

  void _handleMessageLongPress(BuildContext context, types.Message message) {
    if (message.author.id != _currentUser.id) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete Message", style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _deleteMessage(message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    final docRef = _firestore.collection('trips').doc(widget.tripId).collection('chat').doc(messageId);
    final doc = await docRef.get();

    final data = doc.data();
    if (data != null && (data['type'] == 'image' || data['type'] == 'video')) {
      final url = data['url'];
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (e) {
        print("⚠️ Storage delete error: $e");
      }
    }

    await docRef.delete();
    setState(() {
      _messages.removeWhere((msg) => msg.id == messageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text("Trip Chat")),
        body: const Center(child: Text("You are not a member of this trip.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Chat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EditTripDetailsPage(tripId: widget.tripId)),
            ),
          ),
        ],
      ),
      body: Chat(
        messages: _messages,
        onSendPressed: _sendMessage,
        onAttachmentPressed: _handleAttachmentPressed,
        user: _currentUser,
        onMessageLongPress: _handleMessageLongPress,
        customMessageBuilder: (message, {required int messageWidth}) {
          final meta = message.metadata ?? {};
          if (meta['type'] == 'video' && meta['url'] != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: messageWidth.toDouble(),
                  height: 200,
                  child: VideoPlayerWidget(url: meta['url']),
                ),
                if ((meta['caption'] as String?)?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(meta['caption'], style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
              ],
            );
          }
          return Text("Unsupported message");
        },
      ),
    );
  }
}

class VideoPlayerPreview extends StatefulWidget {
  final File file;
  const VideoPlayerPreview({Key? key, required this.file}) : super(key: key);

  @override
  _VideoPlayerPreviewState createState() => _VideoPlayerPreviewState();
}

class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
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
    return _isInitialized
        ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
        : const Center(child: CircularProgressIndicator());
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({Key? key, required this.url}) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.setLooping(true);
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
    return _isInitialized
        ? AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
        : const Center(child: CircularProgressIndicator());
  }
}
