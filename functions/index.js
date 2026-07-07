const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

initializeApp();

exports.onLike = onDocumentCreated("notifications/{notificationId}", async (event) => {
    const data = event.data.data();
    const recipientId = data.recipientId;

    const db = getFirestore();
    const userDoc = await db.collection('users').doc(recipientId).get();

    if (!userDoc.exists || !userDoc.data().fcmToken) return;

    const message = {
        notification: {
            title: 'Yeni Beğeni!',
            body: `${data.senderName || 'Birisi'} gönderini beğendi.`,
        },
        token: userDoc.data().fcmToken,
    };

    return getMessaging().send(message);
});