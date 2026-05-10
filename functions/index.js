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

// Notify photo owner on new comment, AND notify parent comment author on reply
exports.sendNotificationOnNewComment = functions.firestore
    .document("profiles/{profileId}/daily_entries/{entryId}/comments/{commentId}")
    .onCreate(async (snap, context) => {
      const profileId = context.params.profileId;
      const entryId = context.params.entryId;
      const commentData = snap.data();
      const commenterId = commentData.userId;
      const commenterName = commentData.userName || "Iemand";
      const parentId = commentData.parentId || null;

      console.log(`New comment by ${commenterId} on post ${entryId} for profile ${profileId}. ParentId: ${parentId}`);

      const profileDoc = await admin.firestore().collection("profiles").doc(profileId).get();
      if (!profileDoc.exists) {
        console.error(`Profile document ${profileId} not found.`);
        return;
      }
      const ownerId = profileDoc.data().ownerId;

      const notificationData = {
        type: "comment",
        entryId: entryId,
        profileId: profileId,
      };

      // 1. Stuur notificatie naar de profiel-eigenaar (als zij niet zelf reageerden)
      if (ownerId !== commenterId) {
        const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (ownerUserDoc.exists && ownerUserDoc.data().fcmToken) {
          const ownerMessage = {
            notification: {
              title: "Nieuwe reactie",
              body: `${commenterName} heeft gereageerd op je foto.`,
            },
            token: ownerUserDoc.data().fcmToken,
            data: notificationData,
          };
          try {
            await admin.messaging().send(ownerMessage);
            console.log(`Comment notification sent to owner ${ownerId}.`);
          } catch (error) {
            console.error("Error sending comment notification to owner:", error);
          }
        }
      }

      // 2. Als dit een antwoord is op een comment, notificeer de auteur van die comment
      if (parentId) {
        const parentCommentDoc = await admin.firestore()
            .collection("profiles").doc(profileId)
            .collection("daily_entries").doc(entryId)
            .collection("comments").doc(parentId)
            .get();

        if (parentCommentDoc.exists) {
          const parentAuthorId = parentCommentDoc.data().userId;

          // Niet notificeren als het dezelfde persoon is als de reageerder of eigenaar (die al een melding kreeg)
          if (parentAuthorId !== commenterId && parentAuthorId !== ownerId) {
            const parentAuthorDoc = await admin.firestore().collection("users").doc(parentAuthorId).get();
            if (parentAuthorDoc.exists && parentAuthorDoc.data().fcmToken) {
              const replyMessage = {
                notification: {
                  title: "Iemand reageerde op jouw reactie",
                  body: `${commenterName} heeft gereageerd op jouw reactie.`,
                },
                token: parentAuthorDoc.data().fcmToken,
                data: notificationData,
              };
              try {
                await admin.messaging().send(replyMessage);
                console.log(`Reply notification sent to parent comment author ${parentAuthorId}.`);
              } catch (error) {
                console.error("Error sending reply notification:", error);
              }
            }
          }
        }
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

// New Function: Notify owner on new download request and requester on approval
exports.sendNotificationOnDownloadRequestUpdate = functions.firestore
    .document("profiles/{profileId}/daily_entries/{entryId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      const beforeRequests = beforeData.downloadRequests || {};
      const afterRequests = afterData.downloadRequests || {};

      const profileId = context.params.profileId;
      const entryId = context.params.entryId;

      const profileDoc = await admin.firestore().collection("profiles").doc(profileId).get();
      if (!profileDoc.exists) return;
      const ownerId = profileDoc.data().ownerId;
      const profileName = profileDoc.data().name || "een profiel";

      // Detect new pending requests OR approved requests
      for (const [userId, requestData] of Object.entries(afterRequests)) {
        const beforeRequestData = beforeRequests[userId];
        const status = requestData.status;
        const name = requestData.name || "Iemand";

        if ((!beforeRequestData || beforeRequestData.status !== "pending") && status === "pending") {
          // New request -> Notify Owner
          const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
          if (ownerUserDoc.exists && ownerUserDoc.data().fcmToken) {
            const message = {
              notification: {
                title: "Download Aanvraag",
                body: `${name} wil graag je foto van ${profileName} downloaden.`,
              },
              token: ownerUserDoc.data().fcmToken,
              data: {
                type: "download_request",
                entryId: entryId,
                profileId: profileId,
              },
            };
            try {
              await admin.messaging().send(message);
              console.log(`Successfully sent download request notification to owner ${ownerId}.`);
            } catch (e) {
              console.error(e);
            }
          }
        } else if (beforeRequestData && beforeRequestData.status === "pending" && status === "approved") {
          // Approved request -> Notify Requester
          const requesterUserDoc = await admin.firestore().collection("users").doc(userId).get();
          if (requesterUserDoc.exists && requesterUserDoc.data().fcmToken) {
             const message = {
              notification: {
                title: "Download Goedgekeurd!",
                body: `Je downloadverzoek voor de foto van ${profileName} is goedgekeurd. Je kunt de foto nu downloaden.`,
              },
              token: requesterUserDoc.data().fcmToken,
              data: {
                type: "download_approved",
                entryId: entryId,
                profileId: profileId,
              },
            };
            try {
              await admin.messaging().send(message);
              console.log(`Successfully sent download approval notification to user ${userId}.`);
            } catch (e) {
              console.error(e);
            }
          }
        }
      }
    });

// Nieuwe functie: Notificeer eigenaar bij nieuw volgverzoek + verzoeker bij acceptatie
exports.sendNotificationOnFollowRequestUpdate = functions.firestore
    .document("profiles/{profileId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      const beforeRequests = beforeData.followRequests || {};
      const afterRequests = afterData.followRequests || {};

      const profileId = context.params.profileId;
      const ownerId = afterData.ownerId;
      const profileName = afterData.name || "een profiel";

      for (const [userId, requestData] of Object.entries(afterRequests)) {
        const beforeRequestData = beforeRequests[userId];
        const status = requestData.status;

        // Nieuw volgverzoek (pending) -> Notificeer eigenaar
        if ((!beforeRequestData || beforeRequestData.status !== "pending") && status === "pending") {
          const name = requestData.name || "Iemand";
          const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
          if (ownerDoc.exists && ownerDoc.data().fcmToken) {
            const message = {
              notification: {
                title: "Nieuw volgverzoek",
                body: `${name} wil het profiel van ${profileName} volgen.`,
              },
              token: ownerDoc.data().fcmToken,
              data: {
                type: "follow_request",
                profileId: profileId,
              },
            };
            try {
              await admin.messaging().send(message);
              console.log(`Follow request notification sent to owner ${ownerId}.`);
            } catch (e) {
              console.error("Error sending follow request notification:", e);
            }
          }
        }
      }

      // Volgverzoek geaccepteerd -> Notificeer verzoeker
      // Dit detecteren we door te kijken of een uid nu in followers[] staat die er eerder niet in stond
      const beforeFollowers = beforeData.followers || [];
      const afterFollowers = afterData.followers || [];
      const newFollowerIds = afterFollowers.filter((uid) => !beforeFollowers.includes(uid));

      for (const newFollowerId of newFollowerIds) {
        const requesterDoc = await admin.firestore().collection("users").doc(newFollowerId).get();
        if (requesterDoc.exists && requesterDoc.data().fcmToken) {
          const message = {
            notification: {
              title: "Volgverzoek geaccepteerd!",
              body: `Je mag nu het profiel van ${profileName} bekijken.`,
            },
            token: requesterDoc.data().fcmToken,
            data: {
              type: "follow_approved",
              profileId: profileId,
            },
          };
          try {
            await admin.messaging().send(message);
            console.log(`Follow approval notification sent to user ${newFollowerId}.`);
          } catch (e) {
            console.error("Error sending follow approval notification:", e);
          }
        }
      }
    });

// Nieuwe functie: Notificeer de auteur van een comment wanneer iemand die liket
exports.sendNotificationOnCommentLike = functions.firestore
    .document("profiles/{profileId}/daily_entries/{entryId}/comments/{commentId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      const beforeLikes = beforeData.likes || [];
      const afterLikes = afterData.likes || [];

      // Alleen doorgaan als er een like bij is gekomen
      if (afterLikes.length <= beforeLikes.length) {
        return;
      }

      // Vind de nieuwe liker
      const newLikerId = afterLikes.find((uid) => !beforeLikes.includes(uid));
      if (!newLikerId) return;

      const commentAuthorId = afterData.userId;

      // Stuur geen notificatie als je je eigen comment liket
      if (newLikerId === commentAuthorId) {
        console.log("User liked their own comment. No notification needed.");
        return;
      }

      const profileId = context.params.profileId;
      const entryId = context.params.entryId;

      // Haal de naam van de liker op
      const likerDoc = await admin.firestore().collection("users").doc(newLikerId).get();
      const likerName = likerDoc.exists ? (likerDoc.data().displayName || "Iemand") : "Iemand";

      // Haal het FCM-token van de comment-auteur op
      const authorDoc = await admin.firestore().collection("users").doc(commentAuthorId).get();
      if (!authorDoc.exists || !authorDoc.data().fcmToken) {
        console.log(`Comment author ${commentAuthorId} has no FCM token.`);
        return;
      }

      const message = {
        notification: {
          title: "Iemand vindt jouw reactie leuk!",
          body: `${likerName} vindt jouw reactie leuk.`,
        },
        token: authorDoc.data().fcmToken,
        data: {
          type: "comment_like",
          entryId: entryId,
          profileId: profileId,
          commentId: context.params.commentId,
        },
      };

      try {
        await admin.messaging().send(message);
        console.log(`Comment like notification sent to ${commentAuthorId}.`);
      } catch (e) {
        console.error("Error sending comment like notification:", e);
      }
    });
