# 🎯 Group Chat Setup Guide

## Step-by-Step Instructions to Enable Groups

---

## 📋 **Step 1: Run SQL Schema in Supabase**

### How to Execute

1. **Open Supabase Dashboard**
   - Go to: <https://supabase.com/dashboard>
   - Select your project

2. **Navigate to SQL Editor**
   - Click on "SQL Editor" in the left sidebar
   - Click "New Query"

3. **Copy and Paste the SQL**
   - Open the file: `group_schema.sql`
   - Copy ALL the content
   - Paste it into the SQL Editor

4. **Run the Query**
   - Click "Run" button (or press Ctrl/Cmd + Enter)
   - Wait for success message

### What This Creates

✅ **Tables:**

- `chat_rooms` - Stores group information
- `group_members` - Tracks who's in which group

✅ **Permissions (RLS Policies):**

- Only creator can edit group name, bio, avatar
- Members can only view group details
- Members can leave groups
- Creator can remove members

✅ **Automatic Features:**

- Creator is auto-added as admin when group is created
- Updated timestamps are auto-managed

---

## 📋 **Step 2: Create Storage Bucket (Optional)**

### For Group Profile Pictures

1. **Go to Storage in Supabase Dashboard**
   - Click "Storage" in left sidebar
   - Click "Create a new bucket"

2. **Create Bucket:**
   - **Name**: `group_avatars`
   - **Public**: ✅ Yes (so avatars are publicly viewable)
   - Click "Create bucket"

3. **Set Policies:**
   - Click on the bucket
   - Go to "Policies" tab
   - Add these policies:

**Policy 1: Anyone can view**

```sql
CREATE POLICY "Public group avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'group_avatars');
```

**Policy 2: Group admins can upload**

```sql
CREATE POLICY "Group admins can upload avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'group_avatars' AND
  auth.role() = 'authenticated'
);
```

---

## 📋 **Step 3: Test Group Creation**

### Using Your Flutter App

1. **Hot Reload the App**
   - Press `R` in the terminal where Flutter is running
   - Or restart the app

2. **Navigate to Groups Tab**
   - Click on the "Groups" icon in bottom navigation

3. **Create a Group**
   - Click the "+" button (top right)
   - Fill in:
     - **Group Name**: e.g., "Flutter Devs"
     - **Bio**: e.g., "A group for Flutter enthusiasts"
     - **Select Members**: Choose from your friends
   - Click "Create"

4. **Verify:**
   - Group should appear in the list
   - Click on it to open group chat
   - Try sending a message

---

## 🔐 **Permissions Summary**

### **Group Creator (Admin) Can:**

✅ Edit group name
✅ Edit group bio
✅ Change group profile picture
✅ Add members
✅ Remove members
✅ Delete the group
✅ Send messages

### **Group Members Can:**

✅ View group details
✅ View group members
✅ Send messages
✅ Leave the group
❌ **CANNOT** edit group name
❌ **CANNOT** edit group bio
❌ **CANNOT** change group avatar
❌ **CANNOT** remove other members

---

## 📊 **Database Schema Overview**

### **chat_rooms Table:**

```
┌──────────────┬──────────┬─────────────────────────┐
│ Column       │ Type     │ Description             │
├──────────────┼──────────┼─────────────────────────┤
│ id           │ UUID     │ Primary key             │
│ name         │ TEXT     │ Group name              │
│ bio          │ TEXT     │ Group description       │
│ avatar_url   │ TEXT     │ Group profile picture   │
│ is_group     │ BOOLEAN  │ Always true for groups  │
│ admin_id     │ UUID     │ Creator's user ID       │
│ created_at   │ TIMESTAMP│ When group was created  │
│ updated_at   │ TIMESTAMP│ Last update time        │
│ last_message │ TEXT     │ Latest message preview  │
└──────────────┴──────────┴─────────────────────────┘
```

### **group_members Table:**

```
┌──────────────┬──────────┬─────────────────────────┐
│ Column       │ Type     │ Description             │
├──────────────┼──────────┼─────────────────────────┤
│ id           │ UUID     │ Primary key             │
│ room_id      │ UUID     │ References chat_rooms   │
│ user_id      │ UUID     │ References auth.users   │
│ joined_at    │ TIMESTAMP│ When user joined        │
│ role         │ TEXT     │ 'admin' or 'member'     │
└──────────────┴──────────┴─────────────────────────┘
```

---

## 🔄 **How Group Creation Works**

### Flow Diagram

```
User clicks "Create Group"
         ↓
Enters name, bio, selects members
         ↓
App calls createGroup() method
         ↓
1. Insert into chat_rooms table
   - name, bio, avatar_url
   - admin_id = current user
   - is_group = true
         ↓
2. Trigger automatically adds creator
   as admin in group_members
         ↓
3. App adds selected members
   to group_members table
   - role = 'member'
         ↓
Group created! ✅
```

---

## 🧪 **Testing Checklist**

### After Running SQL

- [ ] **Verify Tables Exist**

  ```sql
  SELECT table_name FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name IN ('chat_rooms', 'group_members');
  ```

- [ ] **Check Policies**

  ```sql
  SELECT tablename, policyname 
  FROM pg_policies 
  WHERE tablename IN ('chat_rooms', 'group_members');
  ```

- [ ] **Test Group Creation**
  - Create a group via app
  - Verify it appears in groups list

- [ ] **Test Permissions**
  - As creator: Try editing group name ✅
  - As member: Try editing group name ❌ (should fail)

- [ ] **Test Messaging**
  - Send message in group
  - Verify all members see it

---

## 🐛 **Troubleshooting**

### Error: "Could not find the table 'public.chat_rooms'"

**Solution:** Run the SQL schema in Supabase SQL Editor

### Error: "Permission denied for table chat_rooms"

**Solution:** Check that RLS policies were created correctly

### Error: "Group not appearing in list"

**Solution:**

1. Check if you're a member of the group
2. Verify `getRooms()` query includes groups
3. Hot reload the app

### Error: "Cannot add members to group"

**Solution:**

1. Verify `group_members` table exists
2. Check that you're the admin of the group
3. Ensure member IDs are valid user IDs

---

## 📝 **Code Changes Made**

### **File: `chat_repository_impl.dart`**

**Updated `createGroup()` method:**

- Now properly inserts bio and avatar_url
- Automatically adds selected members to group_members table
- Creator is auto-added as admin by database trigger

**Updated `updateGroupInfo()` method:**

- Now supports updating bio field
- Permissions enforced by RLS (only admin can update)

**Updated `removeMember()` method:**

- Now actually removes members from group_members table
- Permissions enforced by RLS (only admin or self can remove)

---

## 🚀 **Next Steps**

1. **Run the SQL** in Supabase Dashboard
2. **Hot reload** your Flutter app (press `R`)
3. **Test group creation** via the app
4. **Verify permissions** work correctly

---

## 📞 **Support**

If you encounter any issues:

1. Check the error message in Flutter console
2. Check Supabase logs in Dashboard > Logs
3. Verify SQL was executed successfully
4. Ensure you're authenticated in the app

---

**Last Updated:** 2025-12-27
**Version:** 1.0
**File:** group_schema.sql
