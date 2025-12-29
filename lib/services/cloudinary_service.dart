import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  // 1. REPLACE WITH YOUR DATA
  final String cloudName = "dfbmftktm"; // e.g., dxy45...
  final String uploadPreset = "eclinic_present"; // The 'Unsigned' preset you created

  Future<String?> uploadImage(File imageFile) async {
    try {
      // 2. Prepare the URL
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      // 3. Create the request
      final request = http.MultipartRequest('POST', url);

      // 4. Add the fields Cloudinary needs
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      // 5. Send it!
      final response = await request.send();

      // 6. Read response
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);

        // 7. Return the secure URL
        return jsonMap['secure_url'];
      } else {
        print("Cloudinary Upload Failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }
}