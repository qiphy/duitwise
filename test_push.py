import firebase_admin
from firebase_admin import credentials, messaging

# Ensure initialization happens safely
if not firebase_admin._apps:
    cred = credentials.Certificate("service-account.json")
    firebase_admin.initialize_app(cred)

# 🛠️ PASTE YOUR ACTIVE DEVICE TOKEN HERE
registration_token = 'drxvja4LRaO6-WcCu_DBiu:APA91bE66-HMqoc-5zyoJpLNJm8fGAUuvW5prKXkGYrAH_bq-LuCXjozpwZCTzwLcUZHQvqlvg34R8f20El3aPIGRx25aKReM1XA0ulu65NPvHVG12x0V9k'

message = messaging.Message(
    token=registration_token,
    # 1. Standard fallback notification descriptors
    notification=messaging.Notification(
        title='Mission Available! ⚡',
        body='Tap to solve the puzzle and claim your coins!',
    ),
    # 2. 🚀 THE CRITICAL NATIVE ANDROID OVERRIDE FOR VISUAL BANNERS
    android=messaging.AndroidConfig(
        priority='high',
        notification=messaging.AndroidNotification(
            channel_id='duitwise_high_importance_channel', # Matches your Dart service channel
            priority='max',                                # Forces heads-up dropdown banner
            default_sound=True,
        )
    ),
    # 3. Deep-linking target payloads parsed by _handleNotificationPayloadRouting
    data={
        'click_action': 'launch_quest',
        'status': 'active'
    }
)

# Send the payload down the wire
response = messaging.send(message)
print('Successfully sent message ID:', response)