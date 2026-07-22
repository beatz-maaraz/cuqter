const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendChatNotification = functions.region('asia-south1').firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.data();
        if (!messageData) {
            console.log('No message data found.');
            return null;
        }

        const receiverId = messageData.receiverId;
        const senderId = messageData.senderId;
        const rawText = messageData.text || '';
        const messageType = messageData.type || 'text';

        // Produce a user-friendly notification body based on message type
        let notificationBody;
        switch (messageType) {
            case 'video_call': notificationBody = rawText; break; // rawText IS the roomId
            case 'voice_call': notificationBody = rawText; break; // rawText IS the roomId
            case 'image':    notificationBody = '📷 Photo'; break;
            case 'video':    notificationBody = '🎥 Video'; break;
            case 'audio':    notificationBody = '🎵 Audio'; break;
            case 'document': notificationBody = '📄 Document'; break;
            case 'location': notificationBody = '📍 Shared a location'; break;
            default:
                // For text messages, use the actual text (strip the pipe-separated filesize if any)
                notificationBody = rawText.split('|')[0];
        }

        // 1. Fetch recipient's FCM token
        const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
        if (!receiverDoc.exists) {
            console.log('Receiver document does not exist.');
            return null;
        }
        
        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;

        if (!fcmToken) {
            console.log('No FCM token found for user:', receiverId);
            return null;
        }

        // 2. Fetch sender's name and profile picture
        const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
        let senderName = 'New Message';
        let senderProfilePic = '';
        if (senderDoc.exists) {
            const senderData = senderDoc.data();
            senderName = senderData.name || senderData.username || 'New Message';
            senderProfilePic = senderData.profilepic || '';
        }

        // 3. Construct DATA-ONLY Notification Payload
        // We use data-only payload to force onBackgroundMessage handler on client side to trigger,
        // allowing us to show a customized local notification with Action Input buttons (Reply).
        const message = {
            data: {
                title: senderName,
                body: notificationBody,
                chatId: context.params.chatId,
                senderId: senderId,
                receiverId: receiverId,
                senderProfilePic: senderProfilePic,
                type: messageType,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
            },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                        category: 'chats_messages_category',
                    },
                },
            },
            token: fcmToken,
        };

        // 4. Send Message via FCM
        try {
            const response = await admin.messaging().send(message);
            console.log('Notification sent successfully:', response);
        } catch (error) {
            console.error('Error sending notification:', error);
        }
        return null;
    });

exports.sendFriendRequestNotification = functions.region('asia-south1').firestore
    .document('friend_requests/{requestId}')
    .onCreate(async (snapshot, context) => {
        const requestData = snapshot.data();
        if (!requestData) {
            console.log('No request data found.');
            return null;
        }

        const receiverId = requestData.receiverId;
        const senderId = requestData.senderId;
        const senderName = requestData.senderName || 'Someone';
        
        if (requestData.status !== 'pending') {
            return null;
        }

        const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
        if (!receiverDoc.exists) {
            console.log('Receiver document does not exist.');
            return null;
        }
        
        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;

        if (!fcmToken) {
            console.log('No FCM token found for user:', receiverId);
            return null;
        }

        const message = {
            data: {
                title: 'New Friend Request',
                body: `${senderName} sent you a friend request`,
                type: 'friend_request',
                senderId: senderId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
            },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                        category: 'friend_requests_category',
                    },
                },
            },
            token: fcmToken,
        };

        try {
            const response = await admin.messaging().send(message);
            console.log('Friend request notification sent successfully:', response);
        } catch (error) {
            console.error('Error sending friend request notification:', error);
        }
        return null;
    });

exports.sendCallInviteNotification = functions.region('asia-south1').database
    .ref('incoming_calls/{receiverId}')
    .onCreate(async (snapshot, context) => {
        const callData = snapshot.val();
        if (!callData) return null;

        const receiverId = context.params.receiverId;
        const callerId = callData.callerId;
        const callerName = callData.callerName || 'Someone';
        const roomId = callData.roomId;
        const isVideoCall = callData.isVideo || false;

        // Fetch recipient's FCM token
        const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
        if (!receiverDoc.exists) return null;
        
        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;
        if (!fcmToken) return null;

        const message = {
            data: {
                type: 'call_invite',
                callerName: callerName,
                roomId: roomId,
                callerId: callerId,
                isVideoCall: isVideoCall ? 'true' : 'false',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: { priority: 'high' },
            apns: { payload: { aps: { contentAvailable: true } } },
            token: fcmToken,
        };

        try {
            await admin.messaging().send(message);
        } catch (error) {
            console.error('Error sending call invite notification:', error);
        }
        return null;
    });

exports.cancelCallInviteNotification = functions.region('asia-south1').database
    .ref('incoming_calls/{receiverId}')
    .onDelete(async (snapshot, context) => {
        const callData = snapshot.val();
        if (!callData) return null;

        const receiverId = context.params.receiverId;
        const roomId = callData.roomId;

        const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
        if (!receiverDoc.exists) return null;
        
        const receiverData = receiverDoc.data();
        const fcmToken = receiverData.fcmToken;
        if (!fcmToken) return null;

        const message = {
            data: {
                type: 'call_cancel',
                roomId: roomId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: { priority: 'high' },
            apns: { payload: { aps: { contentAvailable: true } } },
            token: fcmToken,
        };

        try {
            await admin.messaging().send(message);
        } catch (error) {
            console.error('Error sending call cancel notification:', error);
        }
        return null;
    });
