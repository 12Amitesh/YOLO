import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String baseUrl = "http://192.168.255.247:8000"; 
  File? _image;                      
  Uint8List? _generatedImageBytes;   
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  int _rotationCount = 0;  
  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _generatedImageBytes = null; // reset generated 
        _rotationCount = 0;          
      });
    }
  }

  // Show dialog messages
  void _showDialog(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            color: isError ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  // Send image to Django backend with rotation count
  Future<void> _sendImageToServer() async {
    if (_image == null) return;

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/generate/"),
      );
      request.files.add(await http.MultipartFile.fromPath('file', _image!.path));

      // Send rotation count as form data
      request.fields['rotation'] = (_rotationCount + 1).toString();

      var response = await request.send();

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        setState(() {
          _generatedImageBytes = bytes;
          _rotationCount += 1;  // increment for next click
        });
        _showDialog("Success", "Image rotated successfully!");
      } else {
        _showDialog("Error", "Server error: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showDialog("Error", "Connection failed: $e", isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Test connection with Django /test/ endpoint
  Future<void> _checkConnection() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/test/"));
      if (response.statusCode == 200) {
        _showDialog("Connected", "Django says: ${response.body}");
      } else {
        _showDialog("Error", "Server error: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showDialog("Error", "Connection failed: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Smart Image Picker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _image = null;
                _generatedImageBytes = null;
                _rotationCount = 0;
              });
            },
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: "Clear Images",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image Preview Card
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                          strokeWidth: 4,
                        ),
                      )
                    : _generatedImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              _generatedImageBytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : _image == null
                            ? const Center(
                                child: Text(
                                  "No Image Selected",
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  _image!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
              ),
            ),
            const SizedBox(height: 30),

            // Gallery & Camera buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo, color: Colors.white),
                  label: const Text("Gallery",
                      style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text("Camera",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Generate button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onPressed: (_image == null || _isLoading) ? null : _sendImageToServer,
              icon: const Icon(Icons.auto_fix_high, color: Colors.white),
              label: const Text("Generate",
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),

            // Check Connection button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onPressed: _isLoading ? null : _checkConnection,
              icon: const Icon(Icons.wifi, color: Colors.white),
              label: const Text("Check Connection",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
