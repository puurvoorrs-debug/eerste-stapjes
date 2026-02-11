const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Function to send daily photo reminders
exports.sendDailyPhotoReminders = functions.pubsub
    .schedule("every day 09:00")
    .onRun(async (context) => {
      const now = new Date();
      const currentHour = now.getHours();

      // Only run between 9 AM and 9 PM
      if (currentHour < 9 || currentHour >= 21) {
        console.log("Skipping execution outside of the desired time window.");
        return null;
      }

      const db = admin.firestore();
      const usersSnapshot = await db.collection("users").get();

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;

        // Check if the user has already posted a photo today
        const dailyEntriesSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("daily_entries")
            .where("date", ">=", today)
            .get();

        if (dailyEntriesSnapshot.empty) {
          // User has not posted a photo today, send a reminder
          const fcmToken = userData.fcmToken;
          if (fcmToken) {
            const message = {
              notification: {
                title: "Tijd voor een kiekje!",
                body: "Tijd voor de dagelijkse foto van je kleintje!",
              },
              token: fcmToken,
            };

            // Schedule a notification with a random delay up to 12 hours.
            const twelveHoursInMs = 12 * 60 * 60 * 1000;
            const randomDelay = Math.floor(Math.random() * twelveHoursInMs);
            setTimeout(() => {
              admin.messaging().send(message)
                  .then((response) => {
                    console.log("Successfully sent message:", response);
                  })
                  .catch((error) => {
                    console.log("Error sending message:", error);
                  });
            }, randomDelay);
          }
        }
      }

      return null;
    });
