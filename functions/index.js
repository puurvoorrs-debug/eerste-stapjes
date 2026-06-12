const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Helper om een notificatie document in Firestore op te slaan
async function createNotification(userId, notificationId, data) {
  try {
    const defaultData = {
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc(notificationId)
        .set({
          ...defaultData,
          ...data,
        }, { merge: true });
  } catch (e) {
    console.error(`Error creating notification for user ${userId}:`, e);
  }
}

// Helper to get user's preferred language ('nl' or 'en')
async function getUserLanguage(userId) {
  try {
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (userDoc.exists) {
      return userDoc.data().language || "nl";
    }
  } catch (e) {
    console.error(`Error fetching language for user ${userId}:`, e);
  }
  return "nl";
}

// Centraal vertaal-systeem voor notificaties
function getTranslation(key, language, params = {}) {
  const translations = {
    daily_reminder_title: {
      nl: "Tijd voor een kiekje!",
      en: "Time for a snapshot!",
    },
    daily_reminder_body: {
      nl: "Je hebt vandaag nog geen foto van je kleintje geplaatst. Tijd voor de dagelijkse update!",
      en: "You haven't posted a photo of your little one today. Time for the daily update!",
    },
    new_photo_title: {
      nl: "Nieuwe foto!",
      en: "New photo!",
    },
    new_photo_body: {
      nl: `${params.posterName} heeft een nieuwe foto geplaatst voor ${params.profileName}.`,
      en: `${params.posterName} posted a new photo for ${params.profileName}.`,
    },
    new_comment_title: {
      nl: "Nieuwe reactie",
      en: "New comment",
    },
    new_comment_body: {
      nl: `${params.commenterName} heeft gereageerd op je foto.`,
      en: `${params.commenterName} commented on your photo.`,
    },
    reply_title: {
      nl: "Iemand reageerde op jouw reactie",
      en: "Someone replied to your comment",
    },
    reply_body: {
      nl: `${params.commenterName} heeft gereageerd op jouw reactie.`,
      en: `${params.commenterName} replied to your comment.`,
    },
    new_like_title: {
      nl: "Nieuwe like!",
      en: "New like!",
    },
    new_like_body: {
      nl: `${params.likerName} vindt je foto leuk.`,
      en: `${params.likerName} liked your photo.`,
    },
    download_request_title: {
      nl: "Download Aanvraag",
      en: "Download Request",
    },
    download_request_body: {
      nl: `${params.name} wil graag je foto van ${params.profileName} downloaden.`,
      en: `${params.name} would like to download your photo of ${params.profileName}.`,
    },
    download_approved_title: {
      nl: "Download Goedgekeurd!",
      en: "Download Approved!",
    },
    download_approved_body: {
      nl: `Je downloadverzoek voor de foto van ${params.profileName} is goedgekeurd. Je kunt de foto nu downloaden.`,
      en: `Your download request for the photo of ${params.profileName} has been approved. You can download the photo now.`,
    },
    follow_request_title: {
      nl: "Nieuw volgverzoek",
      en: "New follow request",
    },
    follow_request_body: {
      nl: `${params.name} wil het profiel van ${params.profileName} volgen.`,
      en: `${params.name} wants to follow the profile of ${params.profileName}.`,
    },
    follow_approved_title: {
      nl: "Volgverzoek geaccepteerd!",
      en: "Follow request accepted!",
    },
    follow_approved_body: {
      nl: `Je mag nu het profiel van ${params.profileName} bekijken.`,
      en: `You can now view the profile of ${params.profileName}.`,
    },
    comment_like_title: {
      nl: "Iemand vindt jouw reactie leuk!",
      en: "Someone liked your comment!",
    },
    comment_like_body: {
      nl: `${params.likerName} vindt jouw reactie leuk.`,
      en: `${params.likerName} liked your comment.`,
    },
    nudge_title: {
      nl: "Een por ontvangen!",
      en: "Received a nudge!",
    },
    nudge_body: {
      nl: `${params.senderName} heeft je een por gegeven om een foto van ${params.profileName} te plaatsen.`,
      en: `${params.senderName} nudged you to post a photo of ${params.profileName}.`,
    },
    nudge_available_title: {
      nl: "Nieuwe foto herinnering",
      en: "New photo reminder",
    },
    nudge_available_body: {
      nl: `Er is vandaag nog niets geüpload voor ${params.profileName}. Geef de beheerders een por!`,
      en: `Nothing has been uploaded for ${params.profileName} today. Give the admins a nudge!`,
    },
  };

  const entry = translations[key];
  if (!entry) return "";
  return entry[language] || entry["nl"];
}

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
          const language = userDoc.data().language || "nl";
          const message = {
            notification: {
              title: getTranslation("daily_reminder_title", language),
              body: getTranslation("daily_reminder_body", language),
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
      const entryId = context.params.entryId;
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
      const posterPhotoUrl = ownerDoc.exists ? ownerDoc.data().photoUrl : null;

      const messages = [];
      for (const followerId of followerIds) {
        // Don't send notification to the person who posted
        if (followerId === ownerId) continue;

        // Maak in-app notificatie document
        await createNotification(followerId, `new_post_${profileId}_${entryId}`, {
          type: "new_post",
          profileId: profileId,
          entryId: entryId,
          senderId: ownerId,
          senderName: posterName,
          senderPhotoUrl: posterPhotoUrl,
        });

        const followerDoc = await admin.firestore().collection("users").doc(followerId).get();
        if (followerDoc.exists && followerDoc.data().fcmToken) {
          const fcmToken = followerDoc.data().fcmToken;
          const language = followerDoc.data().language || "nl";
          messages.push({
            notification: {
              title: getTranslation("new_photo_title", language),
              body: getTranslation("new_photo_body", language, { posterName, profileName }),
            },
            token: fcmToken,
            data: {
              type: "new_post",
              entryId: entryId,
              profileId: profileId,
            },
          });
        }
      }

      if (messages.length === 0) {
        console.log("No followers with FCM tokens found.");
        return;
      }

      try {
        await admin.messaging().sendEach(messages);
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
      const commentId = context.params.commentId;
      const commentData = snap.data();
      const commenterId = commentData.userId;
      const commenterName = commentData.userName || "Iemand";
      const commenterPhotoUrl = commentData.userPhotoUrl || null;
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
        commentId: commentId,
      };

      // 1. Stuur notificatie naar de profiel-eigenaar (als zij niet zelf reageerden)
      if (ownerId !== commenterId) {
        await createNotification(ownerId, `comment_${profileId}_${entryId}_${commentId}`, {
          type: "comment",
          profileId: profileId,
          entryId: entryId,
          commentId: commentId,
          senderId: commenterId,
          senderName: commenterName,
          senderPhotoUrl: commenterPhotoUrl,
        });

        const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (ownerUserDoc.exists && ownerUserDoc.data().fcmToken) {
          const language = ownerUserDoc.data().language || "nl";
          const ownerMessage = {
            notification: {
              title: getTranslation("new_comment_title", language),
              body: getTranslation("new_comment_body", language, { commenterName }),
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
            await createNotification(parentAuthorId, `reply_${profileId}_${entryId}_${commentId}`, {
              type: "reply",
              profileId: profileId,
              entryId: entryId,
              commentId: commentId,
              senderId: commenterId,
              senderName: commenterName,
              senderPhotoUrl: commenterPhotoUrl,
            });

            const parentAuthorDoc = await admin.firestore().collection("users").doc(parentAuthorId).get();
            if (parentAuthorDoc.exists && parentAuthorDoc.data().fcmToken) {
              const language = parentAuthorDoc.data().language || "nl";
              const replyMessage = {
                notification: {
                  title: getTranslation("reply_title", language),
                  body: getTranslation("reply_body", language, { commenterName }),
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
        return;
      }

      // Find the new liker
      const newLikerId = afterLikes.find((liker) => !beforeLikes.includes(liker));

      if (!newLikerId) {
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
        return;
      }

      const likerUserDoc = await admin.firestore().collection("users").doc(newLikerId).get();
      const likerName = likerUserDoc.exists ? (likerUserDoc.data().displayName || "Iemand") : "Iemand";
      const likerPhotoUrl = likerUserDoc.exists ? likerUserDoc.data().photoUrl : null;

      await createNotification(ownerId, `like_${profileId}_${entryId}_${newLikerId}`, {
        type: "like",
        profileId: profileId,
        entryId: entryId,
        senderId: newLikerId,
        senderName: likerName,
        senderPhotoUrl: likerPhotoUrl,
      });

      const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
      if (!ownerUserDoc.exists || !ownerUserDoc.data().fcmToken) {
        return;
      }
      const fcmToken = ownerUserDoc.data().fcmToken;
      const language = ownerUserDoc.data().language || "nl";

      const message = {
        notification: {
          title: getTranslation("new_like_title", language),
          body: getTranslation("new_like_body", language, { likerName }),
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
      const ownerName = "Eigenaar"; // Can be improved

      // Detect new pending requests OR approved requests
      for (const [userId, requestData] of Object.entries(afterRequests)) {
        const beforeRequestData = beforeRequests[userId];
        const status = requestData.status;
        const name = requestData.name || "Iemand";
        const photoUrl = requestData.photoUrl || null;

        if ((!beforeRequestData || beforeRequestData.status !== "pending") && status === "pending") {
          // New request -> Notify Owner
          await createNotification(ownerId, `dl_req_${profileId}_${entryId}_${userId}`, {
            type: "download_request",
            profileId: profileId,
            entryId: entryId,
            senderId: userId,
            senderName: name,
            senderPhotoUrl: photoUrl,
            status: "pending",
          });

          const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
          if (ownerUserDoc.exists && ownerUserDoc.data().fcmToken) {
            const language = ownerUserDoc.data().language || "nl";
            const message = {
              notification: {
                title: getTranslation("download_request_title", language),
                body: getTranslation("download_request_body", language, { name, profileName }),
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
            } catch (e) {
              console.error(e);
            }
          }
        } else if (beforeRequestData && beforeRequestData.status === "pending" && status === "approved") {
          // Approved request -> Delete Owner's Notification
          await admin.firestore().collection("users").doc(ownerId).collection("notifications").doc(`dl_req_${profileId}_${entryId}_${userId}`).delete().catch(e => console.error(e));

          // Notify Requester
          await createNotification(userId, `dl_app_${profileId}_${entryId}_${ownerId}`, {
            type: "download_approved",
            profileId: profileId,
            entryId: entryId,
            senderId: ownerId,
            senderName: profileName,
            status: "approved",
          });

          const requesterUserDoc = await admin.firestore().collection("users").doc(userId).get();
          if (requesterUserDoc.exists && requesterUserDoc.data().fcmToken) {
             const language = requesterUserDoc.data().language || "nl";
             const message = {
              notification: {
                title: getTranslation("download_approved_title", language),
                body: getTranslation("download_approved_body", language, { profileName }),
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
            } catch (e) {
              console.error(e);
            }
          }
        } else if (beforeRequestData && beforeRequestData.status === "pending" && status === "rejected") {
           // Rejected request -> Delete Owner's Notification
           await admin.firestore().collection("users").doc(ownerId).collection("notifications").doc(`dl_req_${profileId}_${entryId}_${userId}`).delete().catch(e => console.error(e));
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

        // Nieuw volgverzoek (pending)
        if ((!beforeRequestData || beforeRequestData.status !== "pending") && status === "pending") {
          const name = requestData.name || "Iemand";
          const photoUrl = requestData.photoUrl || null;

          // 1. Notificeer eigenaar
          await createNotification(ownerId, `follow_req_${profileId}_${userId}`, {
            type: "follow_request",
            profileId: profileId,
            senderId: userId,
            senderName: name,
            senderPhotoUrl: photoUrl,
            status: "pending",
          });

          // 2. Notificeer verzoeker dat het verzoek is verstuurd
          await createNotification(userId, `follow_sent_${profileId}`, {
            type: "follow_request_sent",
            profileId: profileId,
            senderId: ownerId,
            senderName: profileName, // Laat de naam van het profiel zien
            status: "pending",
          });

          const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
          if (ownerDoc.exists && ownerDoc.data().fcmToken) {
            const language = ownerDoc.data().language || "nl";
            const message = {
              notification: {
                title: getTranslation("follow_request_title", language),
                body: getTranslation("follow_request_body", language, { name, profileName }),
              },
              token: ownerDoc.data().fcmToken,
              data: {
                type: "follow_request",
                profileId: profileId,
              },
            };
            try {
              await admin.messaging().send(message);
            } catch (e) {
              console.error("Error sending follow request notification:", e);
            }
          }
        } else if (beforeRequestData && beforeRequestData.status === "pending" && status === "rejected") {
          // Geweigerd -> Delete Owner's Notification
          await admin.firestore().collection("users").doc(ownerId).collection("notifications").doc(`follow_req_${profileId}_${userId}`).delete().catch(e => console.error(e));
          await createNotification(userId, `follow_sent_${profileId}`, {
            status: "rejected",
          });
        }
      }

      // Volgverzoek geaccepteerd -> Notificeer verzoeker
      // Dit detecteren we door te kijken of een uid nu in followers[] staat die er eerder niet in stond
      const beforeFollowers = beforeData.followers || [];
      const afterFollowers = afterData.followers || [];
      const newFollowerIds = afterFollowers.filter((uid) => !beforeFollowers.includes(uid));

      for (const newFollowerId of newFollowerIds) {
        // Delete Owner's Notification and clean up requester's pending notification
        await admin.firestore().collection("users").doc(ownerId).collection("notifications").doc(`follow_req_${profileId}_${newFollowerId}`).delete().catch(e => console.error(e));
        await admin.firestore().collection("users").doc(newFollowerId).collection("notifications").doc(`follow_sent_${profileId}`).delete().catch(e => console.error(e));

        // Add a new notification for the requester that they were approved
        await createNotification(newFollowerId, `follow_app_${profileId}_${ownerId}`, {
          type: "follow_approved",
          profileId: profileId,
          senderId: ownerId,
          senderName: profileName,
          status: "approved",
        });

        const requesterDoc = await admin.firestore().collection("users").doc(newFollowerId).get();
        if (requesterDoc.exists && requesterDoc.data().fcmToken) {
          const language = requesterDoc.data().language || "nl";
          const message = {
            notification: {
              title: getTranslation("follow_approved_title", language),
              body: getTranslation("follow_approved_body", language, { profileName }),
            },
            token: requesterDoc.data().fcmToken,
            data: {
              type: "follow_approved",
              profileId: profileId,
            },
          };
          try {
            await admin.messaging().send(message);
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

      if (afterLikes.length <= beforeLikes.length) {
        return;
      }

      const newLikerId = afterLikes.find((uid) => !beforeLikes.includes(uid));
      if (!newLikerId) return;

      const commentAuthorId = afterData.userId;
      if (newLikerId === commentAuthorId) {
        return;
      }

      const profileId = context.params.profileId;
      const entryId = context.params.entryId;
      const commentId = context.params.commentId;

      const likerDoc = await admin.firestore().collection("users").doc(newLikerId).get();
      const likerName = likerDoc.exists ? (likerDoc.data().displayName || "Iemand") : "Iemand";
      const likerPhotoUrl = likerDoc.exists ? likerDoc.data().photoUrl : null;

      await createNotification(commentAuthorId, `comment_like_${profileId}_${commentId}_${newLikerId}`, {
        type: "comment_like",
        profileId: profileId,
        entryId: entryId,
        commentId: commentId,
        senderId: newLikerId,
        senderName: likerName,
        senderPhotoUrl: likerPhotoUrl,
      });

      const authorDoc = await admin.firestore().collection("users").doc(commentAuthorId).get();
      if (!authorDoc.exists || !authorDoc.data().fcmToken) {
        return;
      }
      const language = authorDoc.data().language || "nl";

      const message = {
        notification: {
          title: getTranslation("comment_like_title", language),
          body: getTranslation("comment_like_body", language, { likerName }),
        },
        token: authorDoc.data().fcmToken,
        data: {
          type: "comment_like",
          entryId: entryId,
          profileId: profileId,
          commentId: commentId,
        },
      };

      try {
        await admin.messaging().send(message);
      } catch (e) {
        console.error("Error sending comment like notification:", e);
      }
    });

// Nieuwe functie: Notificeer eigenaar bij een por (nudge)
exports.sendNotificationOnNudge = functions.firestore
    .document("profiles/{profileId}/nudges/{dateString}")
    .onWrite(async (change, context) => {
      const profileId = context.params.profileId;
      const dateString = context.params.dateString;

      const beforeData = change.before.exists ? change.before.data() : {};
      const afterData = change.after.exists ? change.after.data() : {};

      const beforeSenders = beforeData.nudgeSenders || [];
      const afterSenders = afterData.nudgeSenders || [];

      // Zoek de nieuwe nudger
      const newNudgerId = afterSenders.find((uid) => !beforeSenders.includes(uid));
      if (!newNudgerId) return;

      console.log(`New nudge from ${newNudgerId} for profile ${profileId} on date ${dateString}`);

      const profileDoc = await admin.firestore().collection("profiles").doc(profileId).get();
      if (!profileDoc.exists) {
        console.error(`Profile document ${profileId} not found.`);
        return;
      }

      const profileData = profileDoc.data();
      const ownerId = profileData.ownerId;
      const profileName = profileData.name || "een profiel";

      // Als de eigenaar zichzelf nudget (zou niet moeten kunnen), doe niets
      if (ownerId === newNudgerId) return;

      const nudgerDoc = await admin.firestore().collection("users").doc(newNudgerId).get();
      const senderName = nudgerDoc.exists ? (nudgerDoc.data().displayName || "Iemand") : "Iemand";
      const senderPhotoUrl = nudgerDoc.exists ? nudgerDoc.data().photoUrl : null;

      // Maak in-app notificatie document voor de eigenaar
      const notificationId = `nudge_${profileId}_${dateString}_${newNudgerId}`;
      await createNotification(ownerId, notificationId, {
        type: "nudge",
        profileId: profileId,
        senderId: newNudgerId,
        senderName: senderName,
        senderPhotoUrl: senderPhotoUrl,
        entryId: dateString,
      });

      // Stuur push-notificatie via FCM
      const ownerUserDoc = await admin.firestore().collection("users").doc(ownerId).get();
      if (ownerUserDoc.exists && ownerUserDoc.data().fcmToken) {
        const language = ownerUserDoc.data().language || "nl";
        const message = {
          notification: {
            title: getTranslation("nudge_title", language),
            body: getTranslation("nudge_body", language, { senderName, profileName }),
          },
          token: ownerUserDoc.data().fcmToken,
          data: {
            type: "nudge",
            profileId: profileId,
            entryId: dateString,
          },
        };
        try {
          await admin.messaging().send(message);
          console.log(`Nudge push notification successfully sent to owner: ${ownerId}`);
        } catch (error) {
          console.error("Error sending nudge push notification:", error);
        }
      }
    });

// Nieuwe functie: send daily nudge reminders to followers at 07:30
exports.sendDailyNudgeRemindersToFollowers = functions.pubsub
    .schedule("every day 07:30")
    .onRun(async (context) => {
      console.log("Running daily nudge reminder for followers function.");

      const db = admin.firestore();
      const profilesSnapshot = await db.collection("profiles").get();

      const today = new Date();
      const dateString = today.toISOString().split("T")[0];

      for (const profileDoc of profilesSnapshot.docs) {
        const profileId = profileDoc.id;
        const profileData = profileDoc.data();
        const profileName = profileData.name || "een baby";
        const followerIds = profileData.followers || [];

        if (followerIds.length === 0) {
          continue;
        }

        const entryRef = db.collection("profiles").doc(profileId).collection("daily_entries").doc(dateString);
        const entryDoc = await entryRef.get();

        if (!entryDoc.exists) {
          // No post for this profile today yet, notify followers they can send a nudge.
          console.log(`Profile ${profileName} (${profileId}) has no post today. Notifying followers.`);
          
          const messages = [];
          for (const followerId of followerIds) {
            // Maak in-app notificatie document voor de volger
            const notificationId = `nudge_avail_${profileId}_${dateString}`;
            await createNotification(followerId, notificationId, {
              type: "nudge_available",
              profileId: profileId,
              entryId: dateString,
              senderId: profileData.ownerId,
              senderName: profileName,
            });

            const followerDoc = await db.collection("users").doc(followerId).get();
            if (followerDoc.exists && followerDoc.data().fcmToken) {
              const fcmToken = followerDoc.data().fcmToken;
              const language = followerDoc.data().language || "nl";
              messages.push({
                notification: {
                  title: getTranslation("nudge_available_title", language, { profileName }),
                  body: getTranslation("nudge_available_body", language, { profileName }),
                },
                token: fcmToken,
                data: {
                  type: "nudge_available",
                  profileId: profileId,
                  entryId: dateString,
                },
              });
            }
          }

          if (messages.length > 0) {
            try {
              await admin.messaging().sendEach(messages);
              console.log(`Successfully sent nudge availability notifications to followers of ${profileName}.`);
            } catch (error) {
              console.error(`Error sending nudge availability notification to followers of ${profileName}:`, error);
            }
          }
        }
      }

      return null;
    });
