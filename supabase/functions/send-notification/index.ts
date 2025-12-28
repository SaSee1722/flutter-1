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

    const { data: senderProfile } = await supabase.from('profiles').select('username').eq('id', senderId).single()
    const senderName = senderProfile?.username ?? 'Gossip'

    let receiverIds: string[] = []
    const { data: members } = await supabase.from('group_members').select('user_id').eq('room_id', roomId)

    if (members && members.length > 0) {
        receiverIds = members.map((m: any) => m.user_id).filter((id: string) => id !== senderId)
    } else {
        const { data: friendRoom } = await supabase.from('friend_requests').select('sender_id, receiver_id').eq('id', roomId).single()
        if (friendRoom) {
            receiverIds = [friendRoom.sender_id === senderId ? friendRoom.receiver_id : friendRoom.sender_id]
        }
    }

    return await sendToUsers(supabase, receiverIds, {
        type: 'chat',
        chatId: roomId,
        senderName: senderName,
    }, 'normal', accessToken, projectId)
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

async function sendToUsers(supabase: any, userIds: string[], data: any, priority: string, accessToken: string, projectId: string) {
    if (userIds.length === 0) return new Response('No receivers')

    const { data: profiles } = await supabase.from('profiles').select('fcm_token').in('id', userIds).not('fcm_token', 'is', null)
    if (!profiles || profiles.length === 0) return new Response('No tokens')

    const fetchPromises = profiles.map(async (p: any) => {
        const fcmPayload = {
            message: {
                token: p.fcm_token,
                data: data,
                android: {
                    priority: priority,
                },
                apns: {
                    payload: {
                        aps: {
                            'content-available': 1,
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
