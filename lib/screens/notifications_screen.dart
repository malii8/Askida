import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/aski_service.dart'; // Import AskiService

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final PostService _postService = PostService();
  final AskiService _askiService = AskiService(); // Yeni eklendi
  late Stream<List<NotificationModel>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    _notificationsStream = _notificationService.getUserNotificationsStream(
      includeRead: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Tümünü Okundu İşaretle',
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hata: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _notificationsStream =
                            _notificationService.getUserNotificationsStream();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: Text(
                      'Tekrar Dene',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz bildiriminiz yok',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () => _onNotificationTap(notification),
                onMarkAsRead: () => _markAsRead(notification.id),
                onDelete: () => _deleteNotification(notification.id),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tüm bildirimler okundu olarak işaretlendi'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bildirim silindi'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _onNotificationTap(NotificationModel notification) async {
    // Bildirimi okundu olarak işaretle
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Bildirim tipine göre yönlendirme yap
    switch (notification.type) {
      case NotificationType.applicationReceived:
      case NotificationType.applicationAccepted:
      case NotificationType.applicationRejected:
      case NotificationType.postExpired:
      case NotificationType.newMessage:
      case NotificationType.adminNotification:
      case NotificationType.productClaimed:
      case NotificationType.askiTaken:
      case NotificationType.productDelivered: // Handle new case
      case NotificationType.other:
        if (notification.relatedPostId != null) {
          _navigateToPost(notification.relatedPostId!);
        }
        break;
      case NotificationType.askiWon:
        if (notification.relatedPostId != null && notification.data != null) {
          // QRDisplayScreen'e yönlendir
          final askiId = notification.relatedPostId!;
          final aski = await _askiService.getAski(askiId); // Fetch aski
          if (aski == null) {
            _showError('Askı bulunamadı.');
            return;
          }
          final productName = notification.data!['productName'] as String;
          final corporateName = notification.data!['corporateName'] as String;
          final corporateId = notification.data!['corporateId'] as String;
          final applicantUserId =
              notification.data!['applicantUserId'] as String?;

          if (mounted) {
            Navigator.of(context).pushNamed(
              '/qrDisplay',
              arguments: {
                'askiId': askiId,
                'productName': productName,
                'corporateName': corporateName,
                'corporateId': corporateId,
                'applicantUserId': applicantUserId,
                'postType': aski.postType.name, // Pass postType
              },
            );
          }
        }
        break;
    }
  }

  void _navigateToPost(String postId) async {
    try {
      // Post detaylarını al
      final post = await _postService.getPost(postId);
      if (post != null && mounted) {
        Navigator.of(context).pushNamed('/postDetail', arguments: post);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post bulunamadı veya silinmiş'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post yüklenirken hata: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onMarkAsRead;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onMarkAsRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: notification.isRead ? 1 : 3,
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: _buildLeadingIcon(context),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: TextStyle(
                color:
                    notification.isRead
                        ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.6).round())
                        : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(notification.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'mark_read':
                onMarkAsRead();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder:
              (context) => [
                if (!notification.isRead)
                  PopupMenuItem<String>(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(
                          Icons.mark_email_read,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Okundu İşaretle',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sil',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
          ),
        ),
        onTap: onTap,
        tileColor:
            notification.isRead
                ? null
                : Theme.of(
                  context,
                ).colorScheme.primary.withAlpha((255 * 0.1).round()),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.applicationReceived:
        icon = Icons.person_add;
        color = Theme.of(context).colorScheme.primary;
        break;
      case NotificationType.applicationAccepted:
        icon = Icons.check_circle;
        color = Theme.of(context).colorScheme.tertiary;
        break;
      case NotificationType.applicationRejected:
        icon = Icons.cancel;
        color = Theme.of(context).colorScheme.error;
        break;
      case NotificationType.postExpired:
        icon = Icons.access_time;
        color = Theme.of(context).colorScheme.secondary;
        break;
      case NotificationType.newMessage:
        icon = Icons.message;
        color =
            Theme.of(context).colorScheme.primary; // Using primary for messages
        break;
      case NotificationType.adminNotification:
        icon = Icons.admin_panel_settings;
        color =
            Theme.of(
              context,
            ).colorScheme.primary; // Using primary for admin notifications
        break;
      case NotificationType.productClaimed:
        icon = Icons.shopping_bag;
        color = Theme.of(context).colorScheme.tertiary;
        break;
      case NotificationType.askiWon:
        icon = Icons.emoji_events; // Kupa veya ödül ikonu
        color =
            Theme.of(
              context,
            ).colorScheme.secondary; // Using secondary for won aski
        break;
      case NotificationType.askiTaken:
        icon = Icons.check_circle_outline; // Checkmark icon
        color =
            Theme.of(
              context,
            ).colorScheme.tertiary; // Using tertiary for taken aski
        break;
      case NotificationType.productDelivered:
        icon = Icons.check_box; // Delivered icon
        color =
            Theme.of(
              context,
            ).colorScheme.tertiary; // Using tertiary for delivered
        break;
      default:
        icon = Icons.info; // Default icon
        color = Theme.of(
          context,
        ).colorScheme.onSurface.withAlpha((255 * 0.6).round()); // Default color
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withAlpha((255 * 0.2).round()),
      child: Icon(icon, color: color),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }
}
