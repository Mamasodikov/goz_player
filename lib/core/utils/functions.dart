import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:goz_player/core/widgets/custom_toast.dart';
import 'package:goz_player/core/utils/constants.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> deleteFileFromInternalStorage(String fileName,
    {bool withPath = true}) async {
  try {
    // Get the application documents directory
    Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();

    // Create a file path
    String filePath;
    if (!withPath) {
      filePath = '${appDocumentsDirectory.path}/$fileName';
    } else {
      filePath = fileName;
    }

    // Check if the file exists before attempting to delete
    if (await File(filePath).exists()) {
      // Delete the file
      await File(filePath).delete(recursive: true);
      print('File deleted successfully: $filePath');
    } else {
      print('File not found: $filePath');
      // CustomToast.showToast('File not found: $filePath');
    }
  } catch (e) {
    print('Error deleting file: $e');
    CustomToast.showToast('Error deleting file: $e');
  }
}

bool isWebUrl(String path) {
  final urlPattern = r'^(http[s]?:\/\/|www\.)';
  final regExp = RegExp(urlPattern);

  return regExp.hasMatch(path);
}

bool isLocalFilePath(String path) {
  // Assuming that if it's not a web URL, it's a local file path
  return !isWebUrl(path);
}

Future<bool?> showAlertText(BuildContext context, String question) async {
  return await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoAlertDialog(
          title: Text("Confirmation"),
          content: Text(question),
          actions: [
            // The "Yes" button
            CupertinoDialogAction(
                onPressed: () {
                  // Close the dialog
                  Navigator.of(context).pop(true);
                },
                child: Text("Yes", style: TextStyle(color: cRedColor))),
            CupertinoDialogAction(
                onPressed: () {
                  // Close the dialog
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  "No",
                  style: TextStyle(color: cFirstColor),
                ))
          ],
        );
      });
}

// Function to launch a URL
Future<void> launchCustomUrl(Uri uri) async {
  try {
    await launchUrl(uri);
  } catch (e) {
    print(e);
    CustomToast.showToast('This action is not supported');
  }
}
