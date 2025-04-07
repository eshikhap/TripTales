/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
const functions = require("firebase-functions");
const nodemailer = require("nodemailer");
require("dotenv").config();

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL,
    pass: process.env.PASSWORD,
  },
});

exports.sendFriendRequestEmail = functions.https
    .onCall(async (data, context) => {
      const {senderName, recipientEmail} = data;

      const mailOptions = {
        from: process.env.EMAIL,
        to: recipientEmail,
        subject: "New Friend Request!",
        text: `Hey! You got a friend request from ${senderName}.`,
      };

      try {
        await transporter.sendMail(mailOptions);
        return {success: true};
      } catch (error) {
        return {success: false, error: error.toString()};
      }
    });
