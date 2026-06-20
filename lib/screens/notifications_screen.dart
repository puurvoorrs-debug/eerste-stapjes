import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/notification_model.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/sketchy_components.dart';
import 'daily_entry_detail_screen.dart';
import 'calendar_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<void> _clearAllNotifications(BuildContext context, String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('Geen meldingen om te wissen.', 'No notifications to clear.')),
            ),
          );
        }
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('Meldingen wissen', 'Clear notifications')),
          content: Text(context.tr(
              'Weet je zeker dat je alle meldingen wilt wissen?',
              'Are you sure you want to clear all notifications?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('Annuleren', 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr('Wissen', 'Clear'), style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Alle meldingen gewist!', 'All notifications cleared!')),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Fout bij het wissen van meldingen', 'Error clearing notifications')),
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  void _handleNotificationTap(BuildContext context,
      NotificationModel notification, ProfileProvider provider) async {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    if (notification.type == 'like' ||
        notification.type == 'comment' ||
        notification.type == 'reply' ||
        notification.type == 'comment_like' ||
        notification.type == 'new_post' ||
        notification.type == 'download_approved') {
      if (notification.entryId != null) {
        Navigator.push(
          context,
          SketchyPageRoute(
            page: DailyEntryDetailScreen(
              entryId: notification.entryId!,
              profileId: notification.profileId,
            ),
          ),
        );
      }
    } else if (notification.type == 'follow_approved' ||
        notification.type == 'nudge' ||
        notification.type == 'nudge_available') {
      // Find the profile to navigate to
      final profileDoc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(notification.profileId)
          .get();
      if (profileDoc.exists) {
        final profile = Profile.fromMap(profileDoc.data()!, profileDoc.id);
        if (context.mounted) {
          Navigator.push(
            context,
            SketchyPageRoute(page: CalendarScreen(profile: profile)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
          body: Center(
              child: Text(context.tr('Niet ingelogd', 'Not logged in'))));
    }

    final theme = Theme.of(context);
    timeago.setLocaleMessages('nl', timeago.NlMessages());

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Meldingen', 'Notifications')),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.grey),
            tooltip: context.tr('Alle meldingen wissen', 'Clear all notifications'),
            onPressed: () => _clearAllNotifications(context, user.uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(context.tr('Fout bij laden van meldingen.',
                    'Error loading notifications.')));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
                child:
                    Text(context.tr('Geen meldingen.', 'No notifications.')));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = NotificationModel.fromDocument(docs[index]);
              return _buildNotificationTile(context, notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, NotificationModel notif) {
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final theme = Theme.of(context);

    IconData icon;
    Color iconColor;
    String title;
    String subtitle = '';

    switch (notif.type) {
      case 'like':
        icon = Icons.favorite;
        iconColor = Colors.red;
        title = context.tr(
          '${notif.senderName} vindt je foto leuk.',
          '${notif.senderName} liked your photo.',
        );
        break;
      case 'comment':
      case 'reply':
        icon = Icons.comment;
        iconColor = Colors.blue;
        title = context.tr(
          '${notif.senderName} heeft gereageerd.',
          '${notif.senderName} commented.',
        );
        break;
      case 'comment_like':
        icon = Icons.favorite_border;
        iconColor = Colors.redAccent;
        title = context.tr(
          '${notif.senderName} vindt je reactie leuk.',
          '${notif.senderName} liked your comment.',
        );
        break;
      case 'new_post':
        icon = Icons.photo_camera;
        iconColor = Colors.green;
        title = context.tr(
          '${notif.senderName} heeft een nieuwe foto geplaatst.',
          '${notif.senderName} posted a new photo.',
        );
        break;
      case 'follow_request':
        icon = Icons.person_add;
        iconColor = Colors.orange;
        title = context.tr(
          '${notif.senderName} wil je profiel volgen.',
          '${notif.senderName} wants to follow your profile.',
        );
        if (notif.status == 'pending') {
          subtitle = context.tr('Openstaand verzoek', 'Pending request');
        } else if (notif.status == 'approved')
          subtitle = context.tr('Geaccepteerd', 'Accepted');
        else if (notif.status == 'rejected')
          subtitle = context.tr('Geweigerd', 'Declined');
        break;
      case 'follow_request_sent':
        icon = Icons.access_time;
        iconColor = Colors.grey;
        title = context.tr(
          'Volgverzoek gestuurd naar ${notif.senderName}.',
          'Follow request sent to ${notif.senderName}.',
        );
        if (notif.status == 'pending') {
          subtitle = context.tr('In afwachting...', 'Pending...');
        } else if (notif.status == 'approved')
          subtitle = context.tr('Geaccepteerd', 'Accepted');
        else if (notif.status == 'rejected')
          subtitle = context.tr('Geweigerd', 'Declined');
        break;
      case 'follow_approved':
        icon = Icons.check_circle;
        iconColor = Colors.green;
        title = context.tr(
          'Je mag nu ${notif.senderName} volgen!',
          'You can now follow ${notif.senderName}!',
        );
        break;
      case 'download_request':
        icon = Icons.download;
        iconColor = Colors.orange;
        title = context.tr(
          '${notif.senderName} wil een foto downloaden.',
          '${notif.senderName} wants to download a photo.',
        );
        if (notif.status == 'pending') {
          subtitle = context.tr('Openstaand verzoek', 'Pending request');
        } else if (notif.status == 'approved')
          subtitle = context.tr('Geaccepteerd', 'Accepted');
        else if (notif.status == 'rejected')
          subtitle = context.tr('Geweigerd', 'Declined');
        break;
      case 'download_approved':
        icon = Icons.file_download_done;
        iconColor = Colors.green;
        title = context.tr(
          'Je downloadverzoek is goedgekeurd.',
          'Your download request has been approved.',
        );
        break;
      case 'nudge':
        icon = Icons.touch_app;
        iconColor = Colors.purple;
        title = context.tr(
          '${notif.senderName} heeft je een por gegeven.',
          '${notif.senderName} gave you a nudge.',
        );
        subtitle = context.tr(
          'Tijd voor een nieuwe foto!',
          'Time for a new photo!',
        );
        break;
      case 'nudge_available':
        icon = Icons.notifications_active;
        iconColor = Colors.orangeAccent;
        title = context.tr(
          'Geef de beheerders van ${notif.senderName} een por.',
          'Give the admins of ${notif.senderName} a nudge.',
        );
        subtitle = context.tr(
          'Er is vandaag nog geen foto geplaatst.',
          'No photo has been posted today.',
        );
        break;
      default:
        icon = Icons.notifications;
        iconColor = Colors.grey;
        title = context.tr(
          'Nieuwe melding van ${notif.senderName}',
          'New notification from ${notif.senderName}',
        );
    }

    final isUnread = !notif.isRead;

    return Container(
      color:
          isUnread ? theme.primaryColor.withOpacity(0.05) : Colors.transparent,
      child: ListTile(
        onTap: () => _handleNotificationTap(context, notif, provider),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.2),
              backgroundImage: notif.senderPhotoUrl != null
                  ? NetworkImage(notif.senderPhotoUrl!)
                  : null,
              child: notif.senderPhotoUrl == null
                  ? Icon(icon, color: iconColor)
                  : null,
            ),
            if (notif.senderPhotoUrl != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 12),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  style: TextStyle(color: _getStatusColor(notif.status))),
            const SizedBox(height: 4),
            Text(
                timeago.format(notif.timestamp.toDate(),
                    locale: context.tr('nl', 'en')),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (notif.status == 'pending' &&
                (notif.type == 'follow_request' ||
                    notif.type == 'download_request'))
              _buildActionButtons(context, notif, provider),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          tooltip: context.tr('Melding verwijderen', 'Delete notification'),
          onPressed: () => _deleteNotification(notif.id),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == 'pending') return Colors.orange;
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.grey;
  }

  Widget _buildActionButtons(
      BuildContext context, NotificationModel notif, ProfileProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () async {
              if (notif.type == 'follow_request') {
                await provider.respondToFollowRequest(
                    notif.profileId, notif.senderId!, 'approved');
              } else if (notif.type == 'download_request' &&
                  notif.entryId != null) {
                // Aanname: date kan gehaald worden uit entryId (formaat 'YYYY-MM-DD')
                final date = DateTime.tryParse(notif.entryId!);
                if (date != null) {
                  await provider.respondToDownloadRequest(
                      notif.profileId, date, notif.senderId!, 'approved');
                }
              }
              _deleteNotification(notif.id);
            },
            child: Text(context.tr('Accepteren', 'Accept')),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () async {
              if (notif.type == 'follow_request') {
                await provider.respondToFollowRequest(
                    notif.profileId, notif.senderId!, 'rejected');
              } else if (notif.type == 'download_request' &&
                  notif.entryId != null) {
                final date = DateTime.tryParse(notif.entryId!);
                if (date != null) {
                  await provider.respondToDownloadRequest(
                      notif.profileId, date, notif.senderId!, 'rejected');
                }
              }
              _deleteNotification(notif.id);
            },
            child: Text(context.tr('Weigeren', 'Decline')),
          ),
        ],
      ),
    );
  }
}
