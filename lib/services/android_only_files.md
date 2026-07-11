# Android-only files intentionally skipped in Linux port

The following Kotlin files from the original Android project rely on
Android-specific APIs that have no direct equivalent on Linux desktop:

- `DocumentUri.kt` - `android.provider.DocumentsContract`, `ContentResolver`
- `DocumentTreeUri.kt` - `DocumentsContract`, `StorageVolume`, URI permissions
- `ExternalStorageUri.kt` - `DocumentsContract` external storage provider URIs
- `FileProvider.kt` - Android `ContentProvider`, `ParcelFileDescriptor`,
  `ProxyFileDescriptorCallback`, `MediaStore`, etc.

The Flutter + C++ Linux version uses direct POSIX filesystem access via
`lib/services/file_service.dart` and the native `file_ops` layer instead of
Android Storage Access Framework / ContentProvider abstractions.
