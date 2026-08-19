const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");

initializeApp();
const db = getFirestore();

// ---------------------------------------------------
// 1) Beğeni / Yorum bildirimi -> Push Notification
// ---------------------------------------------------
// ---------------------------------------------------
// 1) Beğeni / Yorum / Yanıt / Etiket Bildirimleri -> Push Notification
// ---------------------------------------------------
exports.onNotificationCreated = onDocumentCreated("notifications/{notificationId}", async (event) => {
    const data = event.data?.data();
    if (!data) return null;

    const recipientId = data.recipientId;
    const senderName = data.senderName || "Birisi";
    const type = data.type || "like";

    if (!recipientId) return null;

    // Bildirimi alan kullanıcının FCM token'ını çek
    const userDoc = await db.collection("users").doc(recipientId).get();
    if (!userDoc.exists || !userDoc.data()?.fcmToken) return null;

    let title = "Humea";
    let body = `${senderName} seninle etkileşime geçti.`;

    switch (type) {
        case "like":
            title = "Yeni Beğeni!";
            body = `${senderName} gönderini beğendi.`;
            break;
        case "comment":
            title = "Yeni Yorum!";
            body = `${senderName} gönderine yorum yaptı.`;
            break;
        case "comment_like":
            title = "Yorum Beğenisi!";
            body = `${senderName} yorumunu beğendi.`;
            break;
        case "reply":
            title = "Yeni Yanıt!";
            body = `${senderName} yorumuna yanıt verdi.`;
            break;
        case "reply_reply":
            title = "Yeni Yanıt!";
            body = `${senderName} yanıtına cevap verdi.`;
            break;
        case "reply_like":
            title = "Yanıt Beğenisi!";
            body = `${senderName} yanıtını beğendi.`;
            break;
        case "mention":
            title = "Senden Bahsedildi!";
            body = `${senderName} bir gönderide senden bahsetti.`;
            break;
        default:
            title = "Yeni Bildirim!";
            body = `${senderName} seninle etkileşime geçti.`;
            break;
    }

    const message = {
        notification: {
            title: title,
            body: body,
        },
        data: {
            postId: data.postId || "",
            type: type,
        },
        token: userDoc.data().fcmToken,
    };

    try {
        return await getMessaging().send(message);
    } catch (err) {
        console.error("Bildirim gönderme hatası:", err);
        return null;
    }
});

// ---------------------------------------------------
// 2) Doğum günü mesajı -> Günde 4 Kez Kontrol (00:00, 08:00, 16:00, 21:00)
// ---------------------------------------------------
async function postBirthdayMessages() {
    const now = new Date();

    // Türkiye saat dilimine göre net tarih alımı
    const formatter = new Intl.DateTimeFormat("en-CA", {
        timeZone: "Europe/Istanbul",
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    });

    const parts = formatter.formatToParts(now);
    const year = parts.find((p) => p.type === "year").value;
    const month = parts.find((p) => p.type === "month").value;
    const day = parts.find((p) => p.type === "day").value;
    const monthDay = `${month}-${day}`; // Örn: "08-17"

    const snapshot = await db
        .collection("users")
        .where("birthMonthDay", "==", monthDay)
        .get();

    if (snapshot.empty) return;

    for (const userDoc of snapshot.docs) {
        const user = userDoc.data();
        const userId = userDoc.id;

        // O yıla ve kullanıcıya özel sabit ID (Mükerrer paylaşımı önler)
        const customPostId = `birthday_${userId}_${year}`;
        const postRef = db.collection("posts").doc(customPostId);

        // Bu yıl o kullanıcı için zaten paylaşılmış mı?
        const existingPost = await postRef.get();
        if (existingPost.exists) {
            continue; // Zaten paylaşılmışsa tekrar paylaşma
        }

        // İlk kez paylaşılıyorsa oluştur
        await postRef.set({
            userId: "Humea",
            userName: "Humea",
            userImage: "assets/logo.png",
            moodEmoji: "🎂",
            moodTitle: "Doğum Günü",
            note: `${user.name || "Kullanıcımız"} adlı kişinin doğum günü 🎂, Yaş sadece bir sayı bunu kesinlikle unutma!!!! Humea Ailesi olarak, sevdiklerinle birlikte mutlu, sağlıklı ve huzurlu bir ömür geçirmeni dileriz! 🎉`,
            likes: 0,
            likesList: [],
            commentsCount: 0,
            timestamp: FieldValue.serverTimestamp(),
            isBirthdayPost: true,
            birthdayUserId: userId,
        });
    }
}

exports.birthdayFeedPost = onSchedule(
    {
        // Her gün Türkiye saatiyle 00:00, 08:00, 16:00 ve 21:00'de çalışır
        schedule: "0 0,8,16,21 * * *",
        timeZone: "Europe/Istanbul",
    },
    async () => {
        await postBirthdayMessages();
    }
);

// ---------------------------------------------------
// 3) TEK SEFERLİK: Eski kullanıcılara birthMonthDay ekle (Saat Dilimi Düzeltmeli)
// ---------------------------------------------------
exports.backfillBirthMonthDay = onRequest(async (req, res) => {
    try {
        const snapshot = await db.collection("users").get();
        const batch = db.batch();
        let count = 0;

        snapshot.forEach((doc) => {
            const data = doc.data();
            if (data.birthDate) {
                // String veya Timestamp'ten Türkiye saatine göre ay-gün formatlama
                const d = new Date(data.birthDate);
                const formatter = new Intl.DateTimeFormat("en-CA", {
                    timeZone: "Europe/Istanbul",
                    month: "2-digit",
                    day: "2-digit",
                });
                const parts = formatter.formatToParts(d);
                const month = parts.find((p) => p.type === "month").value;
                const day = parts.find((p) => p.type === "day").value;
                const monthDay = `${month}-${day}`;

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