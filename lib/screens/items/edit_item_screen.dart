import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../services/item_service.dart';
import '../../services/photo_service.dart';
import 'upload_item_screen.dart' show CurrentUidGetter, UploadItemScreen;

/// Edit Item screen — WBS 6.4.
///
/// Thin wrapper around [UploadItemScreen] in edit mode. Pre-fills all fields
/// from [item], shows "Edit item" title and "Save changes" button, and adds
/// a destructive "Delete item" button that soft-deletes the item document.
class EditItemScreen extends StatelessWidget {
  final Item item;
  final PhotoService? photoService;
  final ItemService? itemService;
  final CurrentUidGetter? getCurrentUid;

  /// Called after a successful save; used by tests to verify navigation intent.
  final VoidCallback? onSaveSuccess;

  /// Called after a successful soft-delete; used by tests to verify intent.
  final VoidCallback? onDeleteSuccess;

  const EditItemScreen({
    super.key,
    required this.item,
    this.photoService,
    this.itemService,
    this.getCurrentUid,
    this.onSaveSuccess,
    this.onDeleteSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return UploadItemScreen(
      initialItem: item,
      photoService: photoService,
      itemService: itemService,
      getCurrentUid: getCurrentUid,
      onSubmitSuccess: onSaveSuccess,
      onDeleteSuccess: onDeleteSuccess,
    );
  }
}
