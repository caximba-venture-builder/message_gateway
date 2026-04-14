## Message Gateway

This application is a simple message broker that receives and sends text and audio messages on WhatsApp using RabbitMQ queues. The main use case is:
- The consumer receives a message from the Evolution API (WhatsApp) and saves the phone number for further processing
- Concatenate text messages received from the same phone number within a configurable period of time
- Transcribe audio messages received from a phone number and record how many tokens were used
- After concatenation or transcription, enqueue the resulting message to another RabbitMQ queue.

# Deployment

I plan to deploy two Docker containers on my VPS: one for the RabbitMQ consumers and another for background jobs. Therefore, I need a lean, production-ready Docker configuration.

# Tech stack

- Ruby on Rails 8 (using proper Rails conventions, prefer built-in features such as activestorage, activejob, solid_cache, solid_queue, no external database, use sqlite3 in wal mode if necessary)
- prefer the most popular ruby/rails gems, that are well supported, and always check to bundle the most up to date versions
- every important feature must have a unit test associated, I need good coverage.
- make this work properly in development mode, and only consider the real domain in production mode.
- ci script before every git commit, run simplecov, rubocop, brakeman and bundle-audit
- security locks must be less restrict in development so I can test (make that configurable and document in readme)
- it would be good to add security focused tests such as if rate limits in important endpoints, band, ttls are correctly working (could be integration tests)
- always update readme with important configuration aspects

# Use Cases

For all incoming messages of type 'conversation', group together (concatenate) the message bodies from the same sender, joining them using a newline character (`\n`). The time window for concatenation is defined by the environment variable `MESSAGE_CONVERSATION_CONCAT_WINDOW` (in seconds). Each time a new 'conversation' message arrives from a given sender, reset the timer for that sender. If no new 'conversation' messages are received from that sender before the current timer expires, enqueue the concatenated message to the queue defined by the `PROCESSED_MESSAGES_QUEUE` environment variable. This logic should ensure that messages are only concatenated and enqueued once the sender has been inactive for the duration specified.

When a phone number interacts with the bot for the first time, add a new record to the Sender table with the following information:
- The `id` should be a UUID.
- Extract the phone number from the `sender` field in the incoming message JSON and store it.
- Extract the sender's name from the `pushName` field in the incoming message JSON and store it.
- Parse the operating system (OS) from the `source` field in the incoming message JSON and store this value as well.
Ensure that this logic is triggered only for phone numbers not already present in the Sender table.

When an incoming message is of type `audioMessage`, the system must trigger a background job to transcribe the audio content. Once the transcription is complete, enqueue the resulting text into the `PROCESSED_MESSAGES_QUEUE`. Additionally, record the number of tokens used for the transcription in a dedicated database table, associating this count with the correct sender. This workflow ensures each audio message is transcribed asynchronously, the transcription result is delivered for further processing, and token usage is tracked per sender for auditing and cost management purposes.

The payload for messages enqueued in the `PROCESSED_MESSAGES_QUEUE` must adhere to the following structure. Implement the code so that every processed message sent to this queue has this exact format:
```
{
    id: sender UUID,
    phone_number: sender phone number,
    text: <transcribed or concatenated message>,
    name: sender name
}
```

For each incoming message, create a new record in the `messages` table for audit purposes. This table must have the following fields, these proccess should be executed in background:
- `id`: a new UUID for each message
- `whatsapp_messageid`: the `key[:id]` value from the incoming message payload
- `message_type`: either `audioMessage` or `conversation`, depending on the message
- `sender_id`: the UUID reference for the sender
- `messageTimestamp`: the value from the `messageTimestamp` field in the incoming message payload
- `sender_os`: the value from the `source` field in the incoming  message payload

# Queue definitions

Incoming message queues follow the naming pattern <evolution-api-instance-name>.<event>.<event-type>. For example: materny-bot-ai.messages.upsert.

The queues are already defined by another service, so there is no need to create them—just subscribe and consume the incoming messages.

The queues are of the quorum type and do not have the x-dead-letter-exchange and x-dead-letter-routing-key parameters set. Therefore, dead letter strategies should be handled by RabbitMQ policies or implemented by the consumer itself.

# Patterns/Best practices

Use service models to decouple business rules from Active Record models.

Send payloads that have been processed by RabbitMQ consumers and have failed 3 times to a dead letter queue, which follows the naming pattern <evolution-api-instance-name>.<event>.<event-type>.dlq

Use a parser to map incoming payloads to a service object or value object, whichever makes more sense.

Use the strategy pattern to decide which algorithm should be executed based on the incoming message type (either audioMessage or conversation).

# Input Payloads

<commom-paylod>
```
{
    "event": "messages.upsert",
    "instance": "<instanceName>",
    "data": { /* messageRaw — varia por tipo, documentado abaixo */ },                                             
    "server_url": "https://your-evolution-api.com",
    "date_time": "2026-04-14T15:30:00.000Z",                   
    "sender": "5511999999999@s.whatsapp.net",
    "apikey": "your-api-key-or-null"
} 
```

<text-message-data>
```
{
    "key":{
        "remoteJid":"5511999999999@s.whatsapp.net",
        "fromMe":false,
        "id":"3EB0A0C1D2E3F4A5B6C7D8",
        "participant":null,
        "remoteJidAlt":"5511999999999@lid",
        "participantAlt":null,
        "addressingMode":"pn",
        "server_id":0
    },
    "pushName":"João Silva",
    "status":"DELIVERY_ACK",
    "message":{
        "conversation":"Olá, tudo bem?"
    },
    "contextInfo":{},
    "messageType":"conversation",
    "messageTimestamp":1713105000,
    "instanceId":"a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "source":"android"
}
```
</text-message-data>

<audio-message-data>
```                
{
    "key":{
        "remoteJid":"5511999999999@s.whatsapp.net",
        "fromMe":false,
        "id":"3EB0B1C2D3E4F5A6B7C8D9",
        "participant":null,
        "remoteJidAlt":"5511999999999@lid",
        "participantAlt":null,
        "addressingMode":"pn",
        "server_id":0
    },
    "pushName":"Maria Souza",
    "status":"DELIVERY_ACK",
    "message":{
        "audioMessage":{
            "url":"https://mmg.whatsapp.net/v/t62.7114-24/...",
            "mimetype":"audio/ogg; codecs=opus",
            "fileSha256":"base64-encoded-sha256",
            "fileLength":15230,
            "seconds":7,
            "ptt":true,
            "mediaKey":"base64-encoded-media-key",
            "fileEncSha256":"base64-encoded-enc-sha256",
            "directPath":"/v/t62.7114-24/...",
            "mediaKeyTimestamp":1713105200,
            "waveform":"base64-encoded-waveform-data"
        }
    },
    "contextInfo":{},
    "messageType":"audioMessage",
    "messageTimestamp":1713105200,
    "instanceId":"a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "source":"android"
}
```
</audio-message-data>

# new ideas

Design a plan around all these requirements and suggest important features you think could be important in a service like this.