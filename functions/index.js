/* eslint-disable comma-dangle */
/* eslint-disable object-curly-spacing */
/* eslint-disable indent */
/* eslint-disable max-len */
// /**
//  * Import function triggers from their respective submodules:
//  *
//  * const {onCall} = require("firebase-functions/v2/https");
//  * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
//  *
//  * See a full list of supported triggers at https://firebase.google.com/docs/functions
//  */

// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");

// // Create and deploy your first functions
// // https://firebase.google.com/docs/functions/get-started

// // exports.helloWorld = onRequest((request, response) => {
// //   logger.info("Hello logs!", {structuredData: true});
// //   response.send("Hello from Firebase!");
// // });
// const functions = require("firebase-functions");
// const admin = require("firebase-admin");

// admin.initializeApp();

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteUser = functions
  .region("asia-south1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const { uid } = data;
    const callerUid = context.auth.uid;

    try {
      const callerSnap = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();
      const isAdmin = callerSnap.exists && callerSnap.data().role === "Admin";

      if (callerUid !== uid && !isAdmin) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You do not have permission to delete this user."
        );
      }

      // Delete user from Firestore first
      await admin.firestore().collection("users").doc(uid).delete();
      console.log(`User document deleted from Firestore: ${uid}`);

      // Then attempt to delete from Firebase Auth
      try {
        await admin.auth().deleteUser(uid);
        console.log(`User deleted from Firebase Auth: ${uid}`);
      } catch (authError) {
        if (authError.code === "auth/user-not-found") {
          console.log(
            `User not found in Firebase Auth, but deleted from Firestore: ${uid}`
          );
          return {
            success: true,
            message:
              "User deleted from Firestore. Not found in Authentication.",
          };
        } else {
          throw authError; // Re-throw if it's a different error
        }
      }

      return {
        success: true,
        message:
          "User deleted successfully from both Firestore and Authentication",
      };
    } catch (error) {
      console.error("Error in deleteUser function:", error);
      if (error.code === "not-found") {
        return {
          success: true,
          message:
            "User not found in Firestore, may have been already deleted.",
        };
      }
      throw new functions.https.HttpsError(
        "internal",
        "An error occurred while deleting the user.",
        error.message
      );
    }
  });
// exports.deleteUser = functions
//   .region("asia-south1")
//   .https.onCall(async (data, context) => {
//     if (!context.auth) {
//       throw new functions.https.HttpsError(
//         "unauthenticated",
//         "The function must be called while authenticated."
//       );
//     }

//     const { uid } = data;
//     const callerUid = context.auth.uid;

//     try {
//       const callerSnap = await admin
//         .firestore()
//         .collection("users")
//         .doc(callerUid)
//         .get();
//       const isAdmin = callerSnap.exists && callerSnap.data().role === "Admin";

//       if (callerUid !== uid && !isAdmin) {
//         throw new functions.https.HttpsError(
//           "permission-denied",
//           "You do not have permission to delete this user."
//         );
//       }

//       await admin.auth().deleteUser(uid);
//       await admin.firestore().collection("users").doc(uid).delete();

//       return { success: true, message: "User deleted successfully" };
//     } catch (error) {
//       console.error("Error deleting user:", error);
//       throw new functions.https.HttpsError(
//         "internal",
//         "An error occurred while deleting the user."
//       );
//     }
//   });

exports.sendFCMNotification = functions
  .region("asia-south1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const { userId, title, body, userRole, requestId } = data;

    try {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();

      if (!userDoc.exists) {
        console.log(`User document not found for userId: ${userId}`);
        throw new functions.https.HttpsError(
          "not-found",
          "User document not found"
        );
      }

      const fcmToken = userDoc.get("fcmToken");

      if (!fcmToken) {
        console.log(`FCM token not found for userId: ${userId}`);
        throw new functions.https.HttpsError(
          "failed-precondition",
          "User FCM token not found"
        );
      }

      const message = {
        token: fcmToken,
        notification: { title, body },
        data: { userRole, requestId: requestId || "" },
      };

      console.log(`Sending FCM message to token: ${fcmToken}`);
      const response = await admin.messaging().send(message);
      console.log("Successfully sent message:", response);
      return { success: true, response };
    } catch (error) {
      console.error("Error in sendFCMNotification:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Error sending FCM message",
        error.message
      );
    }
  });

exports.testFunction = functions
  .region("asia-south1")
  .https.onCall((data, context) => {
    console.log("Test function called with data:", data);
    return { message: "Test function executed successfully" };
  });

exports.cancelDeletionRequest = functions.https.onCall(
  async (data, context) => {
    const requestId = data.requestId;

    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    try {
      await admin
        .firestore()
        .collection("deletion_requests")
        .doc(requestId)
        .delete();
      return {
        message: "Account deletion request canceled and removed from database.",
      };
    } catch (error) {
      console.error("Error canceling deletion request:", error);
      throw new functions.https.HttpsError(
        "unknown",
        "Failed to cancel deletion request"
      );
    }
  }
);
