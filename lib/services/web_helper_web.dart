import 'dart:html' as html;
import 'dart:convert';

void reloadPage() {
  html.window.location.reload();
}

void downloadBase64File(String base64, String fileName, String extension) {
  final String mimeType = extension.toLowerCase() == 'pdf' ? 'application/pdf' : 'image/jpeg';
  final bytes = base64Decode(base64);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "$fileName.$extension")
    ..click();
    
  html.Url.revokeObjectUrl(url);
}

void openBase64InNewTab(String base64, String extension) {
  final String mimeType = extension.toLowerCase() == 'pdf' ? 'application/pdf' : 'image/jpeg';
  final bytes = base64Decode(base64);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Optional: Revoke URL after some time to free memory
  // html.Url.revokeObjectUrl(url);
}
