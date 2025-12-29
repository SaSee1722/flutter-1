---
description: How reactions and stickers implementation works
---

# Reactions and Stickers Implementation

This workflow describes how the reactions and custom stickers features are implemented.

## 1. Reactions

### Data Model

- `Message` entity uses `Map<String, String>? reactions` to store `{userId: emoji}`.

### Backend

- `ChatRepository.updateMessageReaction(messageId, reaction)` updates the `reactions` column in Supabase `messages` table.
- Real-time updates are handled via Supabase subscription in `ChatBloc`.

### Frontend

- **Bloc**: `ChatBloc` handles `UpdateReactionRequest` event.
- **UI**:
  - `ChatDetailScreen` displays messages using `_MessageBubble`.
  - `_MessageBubble` uses `_buildReactionsDisplay` to show reaction counts.
  - Long-press on a message triggers `_showReactionMenu`.
  - `_showReactionMenu` has a predefined list and a "+" button.
  - "+" button opens `_openEmojiReactionPicker` (using `emoji_picker_flutter`).

## 2. Custom Stickers & GIFs

### Data Model

- Stickers are sent as standard `Message`s with `mediaType: 'image'` (or potentially 'sticker').
- Metadata like `mediaUrl` points to the Supabase Storage file.

### Backend

- Stickers are stored in Supabase Storage bucket `chat-media` under `stickers/{userId}/`.

### Frontend

- **UI**:
  - `ChatDetailScreen` has a "Sticker" button in the input area.
  - This opens `StickerPickerSheet` (bottom sheet).
  - **Tab 1: My Stickers**: Lists files from `chat-media/stickers/{userId}`. Allows uploading new stickers from gallery.
  - **Tab 2: GIFs**: Placeholder for GIF integration (allows uploading as well).
- **Sending**:
  - Selecting a sticker calls `SendMessageRequested` with the media URL.
