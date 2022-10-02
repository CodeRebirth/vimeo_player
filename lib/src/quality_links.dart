import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import "dart:collection";

//throw UnimplementedError();

class QualityLinks {
  String videoId;

  QualityLinks(this.videoId);

  getQualitiesSync(String token) {
    return getQualitiesAsync(token);
  }

  Future<SplayTreeMap?> getQualitiesAsync(String token) async {
    print(videoId);
    try {
      // var response = await http.get(Uri.parse('https://player.vimeo.com/video/' + videoId + '/config'));
      var response = await http.get(Uri.parse('https://api.vimeo.com/videos/' + videoId), headers: {"Authorization": "Bearer $token"});
      var jsonData = jsonDecode(response.body)['files'];
      SplayTreeMap videoList = SplayTreeMap.fromIterable(jsonData, key: (item) => "${item['public_name']} ${item['fps']}", value: (item) => item['link']);
      return videoList;
    } catch (error) {
      print('=====> REQUEST ERROR: $error');
      return null;
    }
  }
}
