const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Corrected Function: send daily photo reminders
exports.sendDailyPhotoReminders = functions.pubsub
    .schedule("every day 09:00")
    .onRun(async (context) => {
      console.log("Running daily photo reminder function.");

      const db = admin.firestore();
      const profilesSnapshot = await db.collection("profiles").get();

      const today = new Date();
      const dateString = today.toISOString().split("T")[0];

      // Use a set to avoid sending multiple reminders to the same user
      const usersToRemind = new Set();

      for (const profileDoc of profilesSnapshot.docs) {
        const profileId = profileDoc.id;
        const profileData = profileDoc.data();
        const ownerId = profileData.ownerId;

        if (!ownerId) {
          console.log(`Profile ${profileId} has no ownerId. Skipping.`);
          continue;
        }

        const entryRef = db.collection("profiles").doc(profileId).collection("daily_entries").doc(dateString);
        const entryDoc = await entryRef.get();

        if (!entryDoc.exists) {
          // No post for this profile today, add owner to reminder list.
          usersToRemind.add(ownerId);
        }
      }

      if (usersToRemind.size === 0) {
        console.log("All active profiles have posted today. No reminders needed.");
        return null;
      }

      console.log(`Found ${usersToRemind.size} users to remind.`);

      for (const userId of usersToRemind) {
        const userDoc = await db.collection("users").doc(userId).get();
        if (userDoc.exists && userDoc.data().fcmToken) {
          const fcmToken = userDoc.data().fcmToken;
          const message = {
            notification: {
              title: "Tijd voor een kiekje!",
              body: "Je hebt vandaag nog geen foto van je kleintje geplaatst. Tijd voor de dagelijkse update!",
            },
            token: fcmToken,
          };

          try {
            await admin.messaging().send(message);
            console.log(`Successfully sent reminder to user: ${userId}`);
          } catch (error) {
            console.error(`Error sending reminder to user ${userId}:`, error);
          }
        } else {
          console.log(`User ${userId} has no FCM token or does not exist. Skipping reminder.`);
        }
      }

      return null;
    });


// Corrected Function: Notify followers on new photo
exports.sendNotificationOnNewPhoto = functions.firestore
    .document("profiles/{profileId}/daily_entries/{entryId}")
    .onCreate(async (snap, context) => {
      const profileId = context.params.profileId;
      console.log(`New photo detected for profile: ${profileId}`);

      const profileDoc = await admin.firestore().collection("profiles").doc(profileId).get();
      if (!profileDoc.exists) {
        console.error(`Profile document ${profileId} not found.`);
        return;
      }

      const profileData = profileDoc.data();
      const ownerId = profileData.ownerId;
      const followerIds = profileData.followers || [];
      const profileName = profileData.name || "een profiel";

      if (followerIds.length === 0) {
        console.log(`Profile ${profileName} has no followers to notify.`);
        return;
      }

      const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
      const posterName = ownerDoc.exists ? (ownerDoc.data().displayName || "Iemand") : "Iemand";

      const tokens = [];
      for (const followerId of followerIds) {
        // Don't send notification to the person who posted
        if (followerId === ownerId) continue;

        const followerDoc = await admin.firestore().collection("users").doc(followerId).get();
        if (followerDoc.exists && followerDoc.data().fcmToken) {
          tokens.push(followerDoc.data().fcmToken);
        }
      }

      if (tokens.length === 0) {
        console.log("No followers with FCM tokens found.");
        return;
      }

      const message = {
        notification: {
          title: "Nieuwe foto!",
          body: `${posterName} heeft een nieuwe foto geplaatst voor ${profileName}.`,
        },
        tokens: tokens,
        data: {
          type: "new_post",
          entryId: context.params.entryId,
          profileId: profileId,
        },
      };

      try {
        await admin.messaging().sendEachForMulticast(message);
        console.log("Successfully sent new photo notifications to followers.");
      } catch (error) {
        console.error("Error sending new photo notifications:", error);
      }
    });

// Corrected Function: Notify photo owner on new comment
exports.sendNotificationOnNewComment = functions.firestore
    .document("profiles/{profileId}/daily_entries/{entryId}/comments/{commentId}")
    .onCreate(async (snap, context) => {
      const profileId = context.params.profileId;
      const entryId = context.params.entryId;
      const commentData = snap.data();
      const commenterId = commentData.userId;

      console.log(`New comment by ${commenterId} on post ${entryId} for profile ${profileId}`);

      const profileDoc = await admin.firestore().collection("profiles").doc(profileId).get();
      if (!profileDoc.exists) {
        console.error(`Profile document ${profileId} not found.`);
        return;
      }
      const ownerId = profileDoc.data().ownerId;

      if (ownerId === commenterId) {
        console.log("User commented on their own post. No notification needed.");
        return;
      }

      const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
      if (!ownerUserDoc.exists || !ownerUserDoc.data().fcmToken) {
        console.log(`Photo owner ${ownerId} has no FCM token or does not exist.`);
        return;
      }
      const fcmToken = ownerUserDoc.data().fcmToken;

      const commenterName = commentData.userName || "Iemand";

      const message = {
        notification: {
          title: "Nieuwe reactie",
          body: `${commenterName} heeft gereageerd op je foto.`,
        },
        token: fcmToken,
        data: {
          type: "comment",
          entryId: entryId,
          profileId: profileId,
        },
      };

      try {
        await admin.messaging().send(message);
        console.log("Successfully sent comment notification.");
      } catch (error) {
        console.error("Error sending comment notification:", error);
      }
    });

// Corrected Function: Notify photo owner on new like
exports.sendNotificationOnNewLike = functions.firestore
    .document("profiles/{profileId}/daily_entries/{entryId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      const beforeLikes = beforeData.likes || [];
      const afterLikes = afterData.likes || [];

      // Check if a like was added (not removed)
      if (afterLikes.length <= beforeLikes.length) {
        console.log("A like was removed or count is unchanged. No notification needed.");
        return;
      }

      // Find the new liker
      const newLikerId = afterLikes.find((liker) => !beforeLikes.includes(liker));

      if (!newLikerId) {
        console.log("Could not determine the new liker. No notification sent.");
        return;
      }

      const profileId = context.params.profileId;
      const entryId = context.params.entryId;
      console.log(`New like from ${newLikerId} on post ${entryId} for profile ${profileId}`);

      const profileDoc = await admin.firestore().collection("profiles").doc(profileId).get();
      if (!profileDoc.exists) {
        console.error(`Profile document ${profileId} not found.`);
        return;
      }
      const ownerId = profileDoc.data().ownerId;

      if (ownerId === newLikerId) {
        console.log("User liked their own post. No notification needed.");
        return;
      }

      const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
      if (!ownerUserDoc.exists || !ownerUserDoc.data().fcmToken) {
        console.log(`Photo owner ${ownerId} has no FCM token or does not exist.`);
        return;
      }
      const fcmToken = ownerUserDoc.data().fcmToken;

      const likerUserDoc = await admin.firestore().collection("users").doc(newLikerId).get();
      const likerName = likerUserDoc.exists ? (likerUserDoc.data().displayName || "Iemand") : "Iemand";

      const message = {
        notification: {
          title: "Nieuwe like!",
          body: `${likerName} vindt je foto leuk.`,
        },
        token: fcmToken,
        data: {
          type: "like",
          entryId: entryId,
          profileId: profileId,
        },
      };

      try {
        await admin.messaging().send(message);
        console.log("Successfully sent like notification.");
      } catch (error) {
        console.error("Error sending like notification:", error);
      }
    });
