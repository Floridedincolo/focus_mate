# Testing Friends & Meeting Suggestions Feature (Single Emulator)

## Overview

This guide explains how to test the Friends and Meeting Suggestions features using **a single Android emulator** by creating and switching between test accounts.

## Prerequisites

1. **Flutter app running on emulator**
2. **Firebase project configured** (with Authentication enabled)
3. **At least 2 test user accounts** created in Firebase

---

## Step 1: Create Test Accounts in Firebase

### Option A: Create accounts via Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (focus_mate)
3. Navigate to **Authentication** → **Users**
4. Click **Add User** (or use the testing account feature)
5. Create at least 2 test accounts:
   - **Account 1:**
     - Email: `alice@test.com`
     - Password: `Test12345`
     - Display Name: `Alice` (set in-app after first login)
   - **Account 2:**
     - Email: `bob@test.com`
     - Password: `Test12345`
     - Display Name: `Bob` (set in-app after first login)

### Option B: Create accounts via Flutter app

1. Launch the app and tap **Sign In with Google** (or email sign-up)
2. Create Account 1 with email `alice@test.com`
3. Complete the profile setup (you'll be asked to set displayName, photoUrl, etc.)
4. Sign out
5. Repeat for Account 2 with `bob@test.com`

---

## Step 2: Set Up User Profiles in Firestore

After each account creation, ensure the following Firestore collection is populated:

### Collection: `users/{uid}`

Each user document should contain:

```json
{
  "displayName": "Alice",  // OR "Bob"
  "email": "alice@test.com",  // Optional but recommended for discovery
  "photoUrl": null  // Can be added via profile UI later
}
```

**Verify in Firebase Console:**
1. Go to **Firestore Database**
2. Check the `users` collection
3. You should see documents for `alice_uid` and `bob_uid` with the above fields

---

## Step 3: Testing Workflow (Single Emulator)

### Scenario: Alice sends Bob a friend request

#### Part 1: Alice's Perspective

1. **Start the app** (or restart it if already running)
2. **Sign in as Alice** (`alice@test.com` / `Test12345`)
3. Wait for the app to load
4. **Navigate to Profile page** (bottom navigation → Profile icon)
5. Tap **"Friends"** button
6. You should see the **Friends page** with 3 tabs:
   - **Search** (active by default)
   - **Requests** (badge showing 0)
   - **Friends** (empty list)

7. In the **Search tab**, type **"Bob"** and press Enter
8. You should see a card with:
   - Bob's avatar / initial
   - "Bob" as the name
   - An **"Add Friend"** button (or "Pending" if you've already sent a request)
9. Tap **"Add Friend"**
   - A Firestore document is created in `friendships/{friendshipId}`:
     ```json
     {
       "requesterId": "alice_uid",
       "receiverId": "bob_uid",
       "status": "pending",
       "createdAt": Timestamp,
       "updatedAt": Timestamp
     }
     ```

10. **Verify in Firebase:**
    - Go to Firestore → `friendships` collection
    - You should see the new document with status `"pending"`

#### Part 2: Bob's Perspective (Same Emulator)

1. **Go back to Profile** (bottom navigation → Profile)
2. Tap **Sign Out**
3. You're now on the login screen
4. **Sign in as Bob** (`bob@test.com` / `Test12345`)
5. **Navigate to Profile** → **Friends**
6. Tap the **"Requests"** tab
   - You should see a **badge with "1"** on the Requests tab
   - Below, you'll see a card:
     - "Alice sent you a friend request"
     - **"Accept"** and **"Decline"** buttons

7. Tap **"Accept"**
   - The Firestore document is updated:
     ```json
     {
       "status": "accepted",  // Changed from "pending"
       "updatedAt": Timestamp  // Updated timestamp
     }
     ```

#### Part 3: Verify Friendship

1. Still as **Bob**, go to the **"Friends"** tab
   - Alice should now appear in the friends list
2. **Sign out** and **sign in as Alice**
3. Go to Friends → **"Friends"** tab
   - Bob should appear in Alice's friends list

---

## Step 4: Testing Meeting Suggestions

### Prerequisites

Before testing meeting suggestions, ensure:
1. Alice and Bob are **friends** (status: `"accepted"`)
2. Both have created a few tasks with start/end times on the same day
   - Example: Alice has a task "Meeting" from 10:00-11:00
   - Example: Bob has a task "Lunch" from 12:00-13:00

### Scenario: Alice wants to schedule a meeting with Bob

#### Part 1: Create Tasks (as Alice)

1. Sign in as **Alice**
2. Go to **Home** page
3. Tap **"+ Add Task"** button (FAB)
4. Create a few tasks with times:
   - Task 1: "Mathematics Class" from **09:00 to 10:30**
   - Task 2: "Lunch" from **12:00 to 13:00**
   - Make sure to set the **start time** and **end time**

#### Part 2: Create Tasks (as Bob)

1. Sign out (Profile → Sign Out)
2. Sign in as **Bob**
3. Repeat the process, creating:
   - Task 1: "Physics Class" from **10:00 to 11:30**
   - Task 2: "Coffee Break" from **14:00 to 14:30**

#### Part 3: Suggest Meeting (as Alice)

1. Sign out and sign in as **Alice**
2. Go to **Profile → Plan a Meeting**
3. You should see the **Plan Meeting Wizard**:

   **Step 1: Select Friends**
   - Check the box next to **Bob**
   - Tap **"Continue (1 selected)"**

   **Step 2: Configure Meeting**
   - **Participants:** You + Bob
   - **Date:** Select today or tomorrow (must have tasks on that date)
   - **Duration:** Select **30 minutes** or **60 minutes**
   - **Method:** Choose between:
     - **Algorithmic** (pure free-time intersection)
     - **AI Suggestion** (context-aware via Gemini API)
   - Tap **"Find Slots"**

   **Step 3: Loading**
   - The app will compute or query Gemini for available slots

   **Step 4: Results**
   - You should see **3 proposals** like:
     ```
     Proposal 1:
     11:30 – 12:30
     Location: (TBD or AI-suggested like "Coffee Shop")
     
     Proposal 2:
     13:00 – 14:00
     Location: ...
     ```

4. **Tap on a proposal** to see more details
5. (Optional) You could select one and save it to Firestore or send to Bob

---

## Step 5: Debug & Troubleshooting

### Debug Panel (visible in debug builds)

If you see issues, you can use the **Debug Friends Panel**:

1. Go to **Profile page**
2. Scroll down to **"🛠 Debug: Friends Testing"** (only visible in debug mode)
3. Tap it to access:
   - List all users
   - List all friendships
   - List all proposals
   - Manually create/delete test data

### Common Issues

| Issue | Solution |
|-------|----------|
| "No friends found" when searching | Ensure both users have `displayName` in Firestore `users/{uid}` doc |
| Friend request button shows "Unknown" | Check Firestore rules allow reading user profiles |
| Incoming requests badge doesn't update | Close and reopen the Friends page to refresh the stream |
| Meeting suggestions show "Error" | Check that tasks have both `startTime` and `endTime` set |
| AI suggestions fail with timeout | Ensure Gemini API is enabled in Firebase Console |

### Firestore Collections to Verify

```
focus_mate (project)
├── users/
│   ├── alice_uid/
│   │   └── displayName: "Alice"
│   │       email: "alice@test.com"
│   │       photoUrl: null
│   └── bob_uid/
│       └── displayName: "Bob"
│           email: "bob@test.com"
│           photoUrl: null
├── friendships/
│   └── auto_id_1/
│       ├── requesterId: "alice_uid"
│       ├── receiverId: "bob_uid"
│       ├── status: "accepted"
│       ├── createdAt: Timestamp
│       └── updatedAt: Timestamp
├── meetingProposals/ (optional, for saved proposals)
│   └── auto_id_2/
│       ├── groupMemberUids: ["alice_uid", "bob_uid"]
│       ├── startTime: Timestamp
│       ├── endTime: Timestamp
│       ├── location: { name: "...", latitude: null, longitude: null }
│       ├── source: "algorithmic" | "ai"
│       └── createdAt: Timestamp
└── tasks/
    ├── alice_uid/
    │   └── (Alice's tasks with startTime/endTime)
    └── bob_uid/
        └── (Bob's tasks with startTime/endTime)
```

---

## Step 6: Testing with Different Dates

If you want to test with a **different date** (e.g., tomorrow), modify in the code:

**In `suggest_meeting_algorithmic_use_case.dart`:**
```dart
// The algorithm respects the `targetDate` parameter
final proposals = useCase(
  memberSchedules: [aliceTasks, bobTasks],
  meetingDurationMinutes: 60,
  targetDate: DateTime.now().add(Duration(days: 1)),  // Tomorrow
);
```

---

## Step 7: Switching Between Accounts (Quick Reference)

1. Go to **Profile page** (bottom nav)
2. Tap **"Sign Out"** button (red button at bottom)
3. You'll be redirected to **Login page**
4. Sign in with the other account's email

**No need to uninstall or restart the app!**

---

## Full Feature Checklist

- [ ] Alice can search for Bob by name
- [ ] Alice can send Bob a friend request
- [ ] Bob sees the friend request in the "Requests" tab (with badge count)
- [ ] Bob can accept or decline the request
- [ ] Alice and Bob appear in each other's "Friends" list after acceptance
- [ ] Alice can select Bob and plan a meeting
- [ ] **Algorithmic method** shows free time slots correctly
- [ ] **AI method** returns suggestions with location types (if Gemini is configured)
- [ ] Meeting proposals display with correct time ranges

---

## Next Steps (After Manual Testing)

Once manual testing is complete:

1. **Write automated tests** for:
   - `FriendRepositoryImpl`
   - `SuggestMeetingAlgorithmicUseCase`
   - `SuggestMeetingAiUseCase`

2. **Set up CI/CD** to run tests on every push

3. **Consider A/B testing** between Algorithmic vs AI suggestions

4. **Collect user feedback** on which method is more useful

---

**Enjoy testing the Friends feature!** 🎉

