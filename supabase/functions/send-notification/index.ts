// Setup for Supabase Edge Function to send FCM Notifications (V1 API)
// Deploy with: supabase functions deploy send-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { JWT } from "https://esm.sh/google-auth-library@8.7.0"

serve(async (req) => {
    try {
        const payload = await req.json()
        const { record, table, type } = payload

        if (type !== 'INSERT') {
            return new Response('Not an insert', { status: 200 })
        }

        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // Load Firebase Key from environment variable
        const firebaseKey = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')

        // Get Access Token for FCM V1
        const client = new JWT({
            email: firebaseKey.client_email,
            key: firebaseKey.private_key,
            scopes: ['https://www.googleapis.com/auth/cloud-platform'],
        })
        const { token: accessToken } = await client.getAccessToken()

        if (table === 'messages') {
            return await handleChatMessage(supabase, record, accessToken, firebaseKey.project_id)
        } else if (table === 'calls') {
            return await handleIncomingCall(supabase, record, accessToken, firebaseKey.project_id)
        } else if (table === 'friend_requests') {
            return await handleFriendRequest(supabase, record, accessToken, firebaseKey.project_id)
        }

        return new Response('Table not supported', { status: 200 })
    } catch (error) {
        console.error('Function error:', error)
        return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }
})

async function handleChatMessage(supabase: any, record: any, accessToken: string, projectId: string) {
    const senderId = record.user_id
    const roomId = record.room_id

    const { data: senderProfile } = await supabase.from('profiles').select('username, avatar_url').eq('id', senderId).single()
    const senderName = senderProfile?.username ?? 'Gossip'
    const senderAvatar = senderProfile?.avatar_url

    let receiverIds: string[] = []

    // First check if it's a group chat
    const { data: members } = await supabase.from('group_members').select('user_id').eq('room_id', roomId)

    if (members && members.length > 0) {
        // Group chat - send to all members except sender
        receiverIds = members.map((m: any) => m.user_id).filter((id: string) => id !== senderId)
    } else {
        // 1-to-1 chat - find the other user from room_members
        const { data: roomMembers } = await supabase
            .from('room_members')
            .select('user_id')
            .eq('room_id', roomId)

        if (roomMembers && roomMembers.length > 0) {
            receiverIds = roomMembers
                .map((m: any) => m.user_id)
                .filter((id: string) => id !== senderId)
        }
    }

    if (receiverIds.length === 0) {
        return new Response('No receivers found', { status: 200 })
    }

    return await sendToUsers(supabase, receiverIds, {
        type: 'chat',
        chatId: roomId,
        senderName: senderName,
        senderAvatar: senderAvatar || '',
        messagePreview: 'New message',
    }, 'high', accessToken, projectId)
}

async function handleIncomingCall(supabase: any, record: any, accessToken: string, projectId: string) {
    const senderId = record.caller_id
    const roomId = record.room_id
    const receiverId = record.receiver_id
    const isVideo = record.is_video

    const { data: senderProfile } = await supabase.from('profiles').select('username, avatar_url').eq('id', senderId).single()
    const senderName = senderProfile?.username ?? record.caller_name ?? 'Gossip'
    const senderAvatar = senderProfile?.avatar_url ?? record.caller_avatar

    let receiverIds: string[] = []
    if (receiverId) {
        receiverIds = [receiverId]
    } else if (roomId) {
        const { data: members } = await supabase.from('group_members').select('user_id').eq('room_id', roomId)
        receiverIds = members?.map((m: any) => m.user_id).filter((id: string) => id !== senderId) ?? []
    }

    return await sendToUsers(supabase, receiverIds, {
        type: 'call',
        callId: record.id,
        callerName: senderName,
        callerAvatar: senderAvatar,
        callType: isVideo ? 'video' : 'audio',
    }, 'high', accessToken, projectId)
}

async function handleFriendRequest(supabase: any, record: any, accessToken: string, projectId: string) {
    const senderId = record.sender_id
    const receiverId = record.receiver_id

    // Fetch sender details
    const { data: senderProfile } = await supabase.from('profiles').select('username, avatar_url').eq('id', senderId).single()
    const senderName = senderProfile?.username ?? 'Someone'
    const senderAvatar = senderProfile?.avatar_url

    // Send to receiver
    return await sendToUsers(supabase, [receiverId], {
        type: 'friend_request',
        requestId: record.id,
        senderName: senderName,
        senderAvatar: senderAvatar,
    }, 'normal', accessToken, projectId)
}

async function sendToUsers(supabase: any, userIds: string[], data: any, priority: string, accessToken: string, projectId: string) {
    if (userIds.length === 0) return new Response('No receivers')

    const { data: profiles } = await supabase.from('profiles').select('fcm_token').in('id', userIds).not('fcm_token', 'is', null)
    if (!profiles || profiles.length === 0) return new Response('No tokens')

    const fetchPromises = profiles.map(async (p: any) => {
        // Prepare notification content based on data type
        let title = 'Gossip'
        let body = 'New update'

        if (data.type === 'chat') {
            title = data.senderName
            body = 'Sent you a message'
        } else if (data.type === 'call') {
            title = 'Incoming Call'
            body = `${data.callerName} is calling you`
        } else if (data.type === 'friend_request') {
            title = 'Friend Request'
            body = `${data.senderName} wants to be your friend`
        }

        const fcmPayload = {
            message: {
                token: p.fcm_token,
                notification: {
                    title: title,
                    body: body,
                },
                data: data,
                android: {
                    priority: priority,
                    notification: {
                        channel_id: data.type === 'call' ? 'incoming_calls' : 'chat_messages',
                        sound: 'default',
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            'content-available': 1,
                            sound: 'default',
                        },
                    },
                },
            },
        }

        return fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmPayload),
        })
    })

    await Promise.all(fetchPromises)
    return new Response('Processed')
}
