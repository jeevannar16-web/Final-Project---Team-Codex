"""WebSocket consumer for real-time chat."""

import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone
from store.models import Conversation, Message


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group_name = f'chat_{self.conversation_id}'

        conv = await self.get_conversation()
        user = self.scope['user']
        if not user.is_authenticated:
            await self.close()
            return
        if not conv or (user != conv.customer and user != conv.seller and not user.is_staff):
            await self.close()
            return

        self.user = user
        self.conv = conv

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        msg_type = data.get('type', 'message')

        if msg_type == 'message':
            content = data.get('content', '').strip()
            if content:
                msg = await self.create_message(content)
                await self.channel_layer.group_send(self.room_group_name, {
                    'type': 'chat_message',
                    'id': msg.id,
                    'sender': self.user.username,
                    'content': msg.content,
                    'created_at': msg.created_at.strftime('%H:%M'),
                    'is_mine': True,
                })

        elif msg_type == 'typing':
            await self.channel_layer.group_send(self.room_group_name, {
                'type': 'typing_indicator',
                'username': self.user.username,
                'is_typing': data.get('is_typing', False),
            })

        elif msg_type == 'mark_read':
            await self.mark_messages_read()

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'new_message',
            'id': event['id'],
            'sender': event['sender'],
            'content': event['content'],
            'created_at': event['created_at'],
            'is_mine': event['sender'] == self.user.username,
        }))

    async def typing_indicator(self, event):
        if event['username'] != self.user.username:
            await self.send(text_data=json.dumps({
                'type': 'typing',
                'username': event['username'],
                'is_typing': event['is_typing'],
            }))

    @database_sync_to_async
    def get_conversation(self):
        try:
            return Conversation.objects.get(id=self.conversation_id)
        except Conversation.DoesNotExist:
            return None

    @database_sync_to_async
    def create_message(self, content):
        msg = Message.objects.create(
            conversation=self.conv, sender=self.user, content=content
        )
        self.conv.updated_at = timezone.now()
        self.conv.save(update_fields=['updated_at'])
        return msg

    @database_sync_to_async
    def mark_messages_read(self):
        self.conv.messages.filter(is_read=False).exclude(sender=self.user).update(
            is_delivered=True, is_read=True
        )
