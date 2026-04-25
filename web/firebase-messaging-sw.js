importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDZP1p0cAWrxb4qRF_uQugqkPIm2KrKCG4",
  authDomain: "alert-systems-db.firebaseapp.com",
  projectId: "alert-systems-db",
  storageBucket: "alert-systems-db.firebasestorage.app",
  messagingSenderId: "567541837784",
  appId: "1:567541837784:web:51dc9e4f0f40871ff94cad",
  measurementId: "G-Q3CVP4ESH8"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/favicon.png",
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
