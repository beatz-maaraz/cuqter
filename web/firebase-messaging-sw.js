importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "AIzaSyBOvtzNFHyoCeq8pZZ_JdaG0dmd4a1DPHs",
  authDomain: "cuqter-2fa01.firebaseapp.com",
  databaseURL: "https://cuqter-2fa01-default-rtdb.firebaseio.com",
  projectId: "cuqter-2fa01",
  storageBucket: "cuqter-2fa01.firebasestorage.app",
  messagingSenderId: "921725231252",
  appId: "1:921725231252:web:a2dbfa0c97694cbf299481",
  measurementId: "G-5TKLZ0RS2M"
};

// Initialize Firebase App in service worker context
firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Background Message Handler
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  
  // Customise notification here
  const notificationTitle = payload.data?.title || 'New Message';
  const notificationOptions = {
    body: payload.data?.body || '',
    icon: '/favicon.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
