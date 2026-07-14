const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");

// initializeApp SADECE BİR KERE çağrılır
initializeApp();
const db = getFirestore();

// ---------------------------------------------------
// 1) Beğeni / Yorum bildirimi -> Push Notification
// ---------------------------------------------------
exports.onNotificationCreated = onDocumentCreated("notifications/{notificationId}", async (event) => {
    const data = event.data.data();
    const recipientId = data.recipientId;

    if (!recipientId) return null;

    const userDoc = await db.collection("users").doc(recipientId).get();

    if (!userDoc.exists || !userDoc.data().fcmToken) return null;

    const type = data.type || "like";
    let title = "Yeni Beğeni!";
    let body = `${data.senderName || "Birisi"} gönderini beğendi.`;

    if (type === 'comment') {
        title = 'Yeni Yorum!';
        body = `${data.senderName || 'Birisi'} gönderine yorum yaptı.`;
    } else if (type === 'comment_like') {
        title = 'Yorum Beğenisi!';
        body = `${data.senderName || 'Birisi'} yorumunu beğendi.`;
    } else if (type === 'reply') {
        title = 'Yeni Yanıt!';
        body = `${data.senderName || 'Birisi'} yorumuna yanıt verdi.`;
    } else if (type === 'reply_like') {
        title = 'Yanıt Beğenisi!';
        body = `${data.senderName || 'Birisi'} yanıtını beğendi.`;
    }

    const message = {
        notification: {
            title,
            body,
        },
        token: userDoc.data().fcmToken,
    };

    return getMessaging().send(message);
});

// ---------------------------------------------------
// 2) Doğum günü mesajı -> Zamanlanmış görev (00:00, 08:00, 16:00, 21:00)
// ---------------------------------------------------
async function postBirthdayMessages() {
    const now = new Date();
    const monthDay = `${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;

    const snapshot = await db
        .collection("users")
        .where("birthMonthDay", "==", monthDay)
        .get();

    if (snapshot.empty) return;

    const batch = db.batch();

    snapshot.forEach((doc) => {
        const user = doc.data();

        const postRef = db.collection("posts").doc();
        batch.set(postRef, {
            userId: "Humea",
            userName: "Humea",
            userImage: "assets/logo.png",
            moodEmoji: "🎂",
            moodTitle: "Doğum Günü",
            note: `${user.name} adlı kişinin doğum günü 🎂, Yaş sadece bir sayı bunu kesinlikle unutma!!!! Humea Ailesi olarak, sevdiklerinle birlikte mutlu, sağlıklı ve huzurlu bir ömür geçirmeni dileriz! 🎉`,
            likes: 0,
            likesList: [],
            commentsCount: 0,
            timestamp: FieldValue.serverTimestamp(),
            isBirthdayPost: true,
        });
    });

    await batch.commit();
}

exports.birthdayFeedPost = onSchedule(
    {
        schedule: "0 0,8,16,21, * * *",
        timeZone: "Europe/Istanbul",
    },
    async () => {
        await postBirthdayMessages();
    }
);

// ---------------------------------------------------
// 3) TEK SEFERLİK: Eski kullanıcılara birthMonthDay ekle
// ---------------------------------------------------
exports.backfillBirthMonthDay = onRequest(async (req, res) => {
    try {
        const snapshot = await db.collection("users").get();
        const batch = db.batch();
        let count = 0;

        snapshot.forEach((doc) => {
            const data = doc.data();
            if (!data.birthMonthDay && data.birthDate) {
                const d = new Date(data.birthDate);
                const monthDay = `${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
                batch.update(doc.ref, { birthMonthDay: monthDay });
                count++;
            }
        });

        await batch.commit();
        res.send(`${count} kullanıcı güncellendi.`);
    } catch (err) {
        console.error(err);
        res.status(500).send("Hata: " + err.message);
    }
});