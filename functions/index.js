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
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.deleteUser = functions
    .region("asia-south1")
    .https.onCall(async (data, context) => {
    // Ensure the request is authenticated
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "The function must be called while authenticated.",
        );
      }

      const uid = data.uid;

      // Check if the user is trying to delete themselves or if they h
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
              "You do not have permission to delete this user.",
          );
        }

        // Delete user from Firebase Authentication
        await admin.auth().deleteUser(uid);

        // Delete user document from Firestore
        await admin.firestore().collection("users").doc(uid).delete();

        return {success: true, message: "User deleted successfully"};
      } catch (error) {
        console.error("Error deleting user:", error);
        throw new functions.https.HttpsError(
            "internal",
            "An error occurred while deleting the user.",
        );
      }
    });
