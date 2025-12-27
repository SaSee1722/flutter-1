# Chat Application Flow Documentation

## 📱 How the Chat System Works

### 1. **Message Status Flow** (WhatsApp-like)

Our app implements a 4-stage message status system:

#### Status Progression

```
SENDING → SENT → DELIVERED → READ
   ⏰       ✓         ✓✓        ✓✓
 (Clock) (Single) (Double)  (Double)
         (Tick)   (Tick)    (Tick)
```

#### Detailed Flow

**Stage 1: SENDING** ⏰

- **When**: Message is being sent to the server
- **Icon**: Clock icon
- **Color**: Black
- **What happens**: Message is in the local queue, uploading to Supabase

**Stage 2: SENT** ✓

- **When**: Message successfully saved to Supabase database
- **Icon**: Single checkmark
- **Color**: Black
- **What happens**: Message is in the database but recipient hasn't received it yet

**Stage 3: DELIVERED** ✓✓

- **When**: Recipient's app has fetched the message
- **Icon**: Double checkmark
- **Color**: Black
- **What happens**: Message appears in recipient's chat list (they see it in the list but haven't opened the chat)

**Stage 4: READ** ✓✓

- **When**: Recipient opens the chat and views the message
- **Icon**: Double checkmark
- **Color**: Black (same as delivered)
- **What happens**: Sender sees double tick, recipient's unread count decreases to 0

---

### 2. **Unread Count System**

#### How Unread Counts Work

**Counting Logic:**

```dart
// Count messages that are:
// 1. In this room
// 2. NOT sent by me
// 3. Status is either 'sent' OR 'delivered' (NOT 'read')
unreadCount = messages.where(
  room_id == currentRoom &&
  user_id != myId &&
  (status == 'sent' || status == 'delivered')
).length
```

**When Unread Count Updates:**

1. **Increases** when:
   - You receive a new message from someone
   - Message status is 'sent' or 'delivered'

2. **Decreases to 0** when:
   - You open the chat (triggers `markAsRead()`)
   - All messages in that room are marked as 'read'

3. **Stays at 0** when:
   - You're actively in the chat
   - All messages are already read

#### Badge Display

- **Shows**: When `unreadCount > 0`
- **Hides**: When `unreadCount == 0`
- **Location**: Right side of chat list item
- **Style**: Gradient background with white text

---

### 3. **Mark as Read Flow**

#### When Messages are Marked as Read

**Trigger Points:**

1. **On Chat Open** (`initState`):

   ```dart
   sl<ChatRepository>().markAsRead(widget.roomId);
   ```

2. **On New Messages Loaded**:

   ```dart
   context.read<ChatBloc>().stream.listen((state) {
     if (!state.isLoadingMessages && state.messages.isNotEmpty) {
       sl<ChatRepository>().markAsRead(widget.roomId);
     }
   });
   ```

3. **On App Resume** (if chat is open):
   - When you return to the app with chat open

#### What `markAsRead()` Does

```dart
// Updates ALL messages in the room that:
// 1. Were sent by someone else (not me)
// 2. Are not already marked as 'read'
await supabase
  .from('messages')
  .update({'status': 'read'})
  .eq('room_id', roomId)
  .neq('user_id', myUserId)
  .neq('status', 'read');
```

---

### 4. **Real-time Updates**

#### How the UI Stays in Sync

**Chat List Screen:**

- Listens to `friend_requests` table changes
- Listens to `messages` table changes
- Automatically refreshes room list when:
  - New message arrives
  - Message status changes
  - Friend request accepted

**Chat Detail Screen:**

- Streams messages in real-time
- Updates message status icons automatically
- Shows typing indicators live

**Typing Indicators:**

- Uses Supabase Realtime Presence
- Shows "Someone is typing..." when other user types
- Hides when user stops typing or sends message

---

### 5. **Settings Options Explained**

#### Current Settings (in Settings Screen)

**1. Last Seen** 👁️

- **Purpose**: Show when you were last active
- **Current Status**: UI placeholder (not functional yet)
- **Future**: Will show "Last seen at HH:MM" to other users

**2. Read Receipts** ✓✓

- **Purpose**: Control if others see when you read their messages
- **Current Status**: UI placeholder (always ON)
- **Future**: Toggle to disable sending read receipts

**3. Notifications** 🔔

- **Purpose**: Enable/disable push notifications
- **Current Status**: UI placeholder (not functional yet)
- **Future**: Will control push notification permissions

**4. Language** 🌐

- **Purpose**: Change app language
- **Current Status**: **FUNCTIONAL** ✅
- **Options**: English, Hindi (हिन्दी), Tamil (தமிழ்)

**5. Blocked Users** 🚫

- **Purpose**: Manage blocked contacts
- **Current Status**: UI placeholder (not functional yet)
- **Future**: List and unblock users

---

### 6. **Database Schema**

#### Messages Table

```sql
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL,
  user_id UUID NOT NULL,
  content TEXT NOT NULL,
  status TEXT NOT NULL, -- 'sending', 'sent', 'delivered', 'read'
  created_at TIMESTAMP DEFAULT NOW(),
  attachment_url TEXT,
  attachment_type TEXT, -- 'image', 'video', 'audio'
  reactions JSONB
);
```

#### Friend Requests Table

```sql
CREATE TABLE friend_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID NOT NULL,
  receiver_id UUID NOT NULL,
  status TEXT NOT NULL, -- 'pending', 'accepted', 'rejected'
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

### 7. **Key Differences from WhatsApp**

| Feature | WhatsApp | Our App |
|---------|----------|---------|
| Message Status | ✓ (sent), ✓✓ (delivered), Blue ✓✓ (read) | ✓ (sent), ✓✓ (delivered/read) |
| Unread Badge | Shows count | Shows count ✅ |
| Last Seen | Functional | Placeholder |
| Read Receipts Toggle | Functional | Placeholder |
| Group Chats | Full support | Basic support |
| Media Sharing | Full support | Partial support |
| Voice/Video Calls | WebRTC | WebRTC (basic) |

---

### 8. **Common Issues & Fixes**

#### Issue 1: Unread count not updating after reading

**Cause**: Query was using `.neq('status', 'read')` which included 'sending' status
**Fix**: Changed to `.or('status.eq.sent,status.eq.delivered')`

#### Issue 2: Message status not updating to double tick

**Cause**: Status icon logic was correct, but database updates weren't triggering
**Fix**: Ensured `markAsRead()` is called on chat open and message load

#### Issue 3: Badge shows even after reading

**Cause**: Unread count query was too broad
**Fix**: Only count 'sent' and 'delivered' messages, not 'sending'

---

### 9. **Testing Checklist**

To verify everything works:

- [ ] Send a message → Should show ⏰ then ✓
- [ ] Recipient opens chat list → Should show ✓✓ (delivered)
- [ ] Recipient opens chat → Should show ✓✓ (read)
- [ ] Unread badge appears when message received
- [ ] Unread badge disappears when chat opened
- [ ] Typing indicator shows when other user types
- [ ] Real-time message updates work
- [ ] Message status updates in real-time

---

## 🔧 Technical Implementation

### Repository Pattern

- **Interface**: `ChatRepository` (abstract class)
- **Implementation**: `SupabaseChatRepository`
- **Dependency Injection**: Using `get_it` package

### State Management

- **BLoC Pattern**: `ChatBloc` for chat state
- **Events**: `LoadMessages`, `SendMessage`, etc.
- **States**: `ChatLoaded`, `ChatLoading`, `ChatError`

### Real-time Features

- **Supabase Realtime**: For message streaming
- **Supabase Presence**: For typing indicators
- **Stream Controllers**: For custom real-time logic

---

## 📝 Future Enhancements

1. **Implement Last Seen functionality**
2. **Add Read Receipts toggle**
3. **Enable push notifications**
4. **Add message search**
5. **Implement message forwarding**
6. **Add voice messages**
7. **Implement video notes**
8. **Add message deletion**
9. **Implement message editing**
10. **Add end-to-end encryption**

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Author**: Gossip Chat Team
